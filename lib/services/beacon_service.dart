import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/models.dart';

class BeaconService extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────
  bool _scanning = false;
  bool get scanning => _scanning;

  String? _currentZoneId;
  String? get currentZoneId => _currentZoneId;

  final Map<String, Beacon> _beacons = {};
  List<Beacon> get beacons => _beacons.values.toList();

  // Known beacons registry (uuid → Beacon)
  final Map<String, Beacon> _registry = {};

  StreamSubscription<List<ScanResult>>? _scanSub;
  Timer? _zoneTimer;

  // RSSI smoothing: keep last N readings per UUID
  static const int _smoothingWindow = 5;
  final Map<String, List<int>> _rssiHistory = {};

  // ── Init ───────────────────────────────────────────────────────────────

  void registerBeacons(List<Beacon> beacons) {
    for (final b in beacons) {
      _registry[b.uuid.toLowerCase()] = b;
      _beacons[b.uuid] = b;
    }
    notifyListeners();
  }

  // ── Scanning ───────────────────────────────────────────────────────────

  Future<void> startScanning() async {
    if (_scanning) return;
    _scanning = true;
    notifyListeners();

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 0), // continuous
      androidUsesFineLocation: true,
    );

    _scanSub = FlutterBluePlus.onScanResults.listen(_onScanResults);

    // Re-evaluate zone every 2 seconds
    _zoneTimer = Timer.periodic(const Duration(seconds: 2), (_) => _evaluateZone());
  }

  Future<void> stopScanning() async {
    _scanning = false;
    await _scanSub?.cancel();
    _zoneTimer?.cancel();
    await FlutterBluePlus.stopScan();
    notifyListeners();
  }

  // ── Result processing ──────────────────────────────────────────────────

  void _onScanResults(List<ScanResult> results) {
    for (final r in results) {
      final mac = r.device.remoteId.str.toLowerCase();

      // Match by MAC or by advertised name prefix
      Beacon? matched;
      for (final entry in _registry.entries) {
        if (mac == entry.key.toLowerCase() ||
            r.device.platformName.toLowerCase().contains(entry.value.name.toLowerCase())) {
          matched = entry.value;
          break;
        }
      }

      // Try matching by advertised UUIDs
      if (matched == null) {
        final advUuids = r.advertisementData.serviceUuids
            .map((u) => u.toString().toLowerCase())
            .toList();
        for (final entry in _registry.entries) {
          if (advUuids.any((u) => u.contains(entry.key.toLowerCase().replaceAll('-', '')))) {
            matched = entry.value;
            break;
          }
        }
      }

      if (matched == null) continue;

      // Smooth RSSI
      _rssiHistory.putIfAbsent(matched.uuid, () => []);
      _rssiHistory[matched.uuid]!.add(r.rssi);
      if (_rssiHistory[matched.uuid]!.length > _smoothingWindow) {
        _rssiHistory[matched.uuid]!.removeAt(0);
      }
      final smoothedRssi = (_rssiHistory[matched.uuid]!.reduce((a, b) => a + b) /
              _rssiHistory[matched.uuid]!.length)
          .round();

      final distance = _estimateDistance(matched, smoothedRssi);
      _beacons[matched.uuid] = matched.copyWith(
        rssi: smoothedRssi,
        distance: distance,
        lastSeen: DateTime.now(),
      );
    }
    notifyListeners();
  }

  void _evaluateZone() {
    final nearby = _beacons.values
        .where((b) => b.isNearby)
        .toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    final newZone = nearby.isNotEmpty ? nearby.first.zoneId : null;
    if (newZone != _currentZoneId) {
      _currentZoneId = newZone;
      notifyListeners();
    }

    // Expire stale beacons
    for (final b in _beacons.values) {
      if (DateTime.now().difference(b.lastSeen).inSeconds > 15) {
        _rssiHistory.remove(b.uuid);
      }
    }
  }

  // ── Distance estimation ────────────────────────────────────────────────
  // Uses log-distance path loss model

  double _estimateDistance(Beacon beacon, int rssi) {
    if (rssi == 0) return -1.0;
    // txPower: typical iBeacon measured power at 1m = -59 dBm
    const txPower = -59;
    final ratio = rssi / txPower;
    if (ratio < 1.0) return pow(ratio, 10).toDouble();
    return 0.89976 * pow(ratio, 7.7095) + 0.111;
  }

  // ── Manual zone override (for testing without beacons) ─────────────────

  void setZoneManually(String? zoneId) {
    _currentZoneId = zoneId;
    notifyListeners();
  }

  // ── Mock data (demo mode) ──────────────────────────────────────────────

  void injectMockReading(String beaconUuid, int rssi) {
    final b = _beacons[beaconUuid];
    if (b == null) return;
    _rssiHistory.putIfAbsent(beaconUuid, () => []);
    _rssiHistory[beaconUuid]!.add(rssi);
    if (_rssiHistory[beaconUuid]!.length > _smoothingWindow) {
      _rssiHistory[beaconUuid]!.removeAt(0);
    }
    final smoothed = (_rssiHistory[beaconUuid]!.reduce((a, b) => a + b) /
            _rssiHistory[beaconUuid]!.length)
        .round();
    _beacons[beaconUuid] = b.copyWith(
      rssi: smoothed,
      distance: _estimateDistance(b, smoothed),
      lastSeen: DateTime.now(),
    );
    _evaluateZone();
  }

  @override
  void dispose() {
    stopScanning();
    super.dispose();
  }
}
