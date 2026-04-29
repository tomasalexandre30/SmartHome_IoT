import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/models.dart';

class BeaconService extends ChangeNotifier {
  bool _scanning = false;
  bool get scanning => _scanning;

  bool _isScanningNow = false;
  bool get isScanningNow => _isScanningNow;

  String? _currentZoneId;
  String? get currentZoneId => _currentZoneId;

  final Map<String, Beacon> _beacons = {};
  List<Beacon> get beacons => _beacons.values.toList();

  final Map<String, Beacon> _registry = {};

  StreamSubscription<List<ScanResult>>? _scanSub;

  Timer? _zoneTimer;
  Timer? _staleTimer;
  Timer? _scanCycleTimer;

  static const int _smoothingWindow = 8;
  final Map<String, List<int>> _rssiHistory = {};

  final List<String> debugLog = [];

  String _norm(String value) => value.toUpperCase().trim();

  void registerBeacons(List<Beacon> beacons) {
    _registry.clear();
    _beacons.clear();
    _rssiHistory.clear();

    for (final b in beacons) {
      final macKey = _norm(b.mac);
      final uuidKey = _norm(b.uuid);
      final nameKey = _norm(b.name);

      _registry[macKey] = b;
      _registry[uuidKey] = b;
      _registry[nameKey] = b;

      // Chave interna por MAC para evitar sobrescrever beacons com o mesmo UUID
      _beacons[macKey] = b;
    }

    notifyListeners();
  }

  Future<bool> _requestPermissions() async {
    final permissions = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    return (permissions[Permission.bluetoothScan]?.isGranted ?? false) &&
        (permissions[Permission.bluetoothConnect]?.isGranted ?? false) &&
        (permissions[Permission.locationWhenInUse]?.isGranted ?? false);
  }

  Future<void> startScanning() async {
    if (_scanning) return;

    final granted = await _requestPermissions();

    if (!granted) {
      debugLog.add('ERRO: permissões BLE/localização não concedidas');
      debugPrint('[BLE ERROR] Permissões BLE/localização não concedidas');
      notifyListeners();
      return;
    }

    final adapterState = await FlutterBluePlus.adapterState.first;

    if (adapterState != BluetoothAdapterState.on) {
      debugLog.add('ERRO: Bluetooth desligado');
      debugPrint('[BLE ERROR] Bluetooth desligado');
      notifyListeners();
      return;
    }

    await _scanSub?.cancel();

    _scanSub = FlutterBluePlus.onScanResults.listen(
      _onScanResults,
      onError: (e) {
        debugLog.add('ERRO SCAN: $e');
        debugPrint('[BLE ERROR] $e');
        notifyListeners();
      },
    );

    _scanning = true;
    debugLog.clear();
    notifyListeners();

    _startScanCycle();

    _zoneTimer?.cancel();
    _zoneTimer = Timer.periodic(
      const Duration(seconds: 2),
          (_) => _evaluateZone(),
    );

    _staleTimer?.cancel();
    _staleTimer = Timer.periodic(
      const Duration(seconds: 1),
          (_) => _removeStaleBeacons(),
    );

    debugPrint('[BLE] Scan cíclico iniciado');
  }

  Future<void> _startScanCycle() async {
    _scanCycleTimer?.cancel();

    await _runOneScanCycle();

    _scanCycleTimer = Timer.periodic(
      const Duration(seconds: 5),
          (_) async {
        if (_scanning) {
          await _runOneScanCycle();
        }
      },
    );
  }

  Future<void> _runOneScanCycle() async {
    if (!_scanning) return;

    try {
      await FlutterBluePlus.stopScan();
      _isScanningNow = false;
      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 300));

      if (!_scanning) return;

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 4),
        androidUsesFineLocation: true,
        continuousUpdates: true,
      );

      _isScanningNow = true;
      notifyListeners();

      debugPrint('[BLE] Ciclo de scan iniciado');
    } catch (e) {
      debugPrint('[BLE ERROR] Erro no ciclo de scan: $e');
      debugLog.add('ERRO CICLO SCAN: $e');
      notifyListeners();
    }
  }

  Future<void> stopScanning() async {
    _scanning = false;
    _isScanningNow = false;

    _scanCycleTimer?.cancel();
    _scanCycleTimer = null;

    _zoneTimer?.cancel();
    _zoneTimer = null;

    _staleTimer?.cancel();
    _staleTimer = null;

    await _scanSub?.cancel();
    _scanSub = null;

    await FlutterBluePlus.stopScan();

    notifyListeners();
  }

  void _onScanResults(List<ScanResult> results) {
    for (final r in results) {
      final name = _norm(r.device.platformName);
      final localName = _norm(r.advertisementData.advName);
      final mac = _norm(r.device.remoteId.str);

      final serviceUuids = r.advertisementData.serviceUuids
          .map((e) => _norm(e.str))
          .toList();

      final iBeaconUuid =
      _extractIBeaconUuid(r.advertisementData.manufacturerData);

      Beacon? matched;

      // 1. MAC primeiro
      matched = _registry[mac];

      // 2. UUID iBeacon
      if (matched == null && iBeaconUuid != null) {
        matched = _registry[_norm(iBeaconUuid)];
      }

      // 3. Service UUIDs
      for (final uuid in serviceUuids) {
        matched ??= _registry[uuid];
      }

      // 4. Nome como fallback
      matched ??= _registry[name];
      matched ??= _registry[localName];

      // Ignora tudo o que não seja teu
      if (matched == null) continue;

      final beaconKey = _norm(matched.mac);

      final logEntry =
          'BEACON=${matched.name} | MAC=$mac | UUID=${iBeaconUuid ?? matched.uuid} | RSSI=${r.rssi}';

      debugPrint('[BLE MATCH] $logEntry');

      if (debugLog.length < 100 && !debugLog.contains(logEntry)) {
        debugLog.add(logEntry);
      }

      _rssiHistory.putIfAbsent(beaconKey, () => []);
      _rssiHistory[beaconKey]!.add(r.rssi);

      if (_rssiHistory[beaconKey]!.length > _smoothingWindow) {
        _rssiHistory[beaconKey]!.removeAt(0);
      }

      final smoothed =
      (_rssiHistory[beaconKey]!.reduce((a, b) => a + b) /
          _rssiHistory[beaconKey]!.length)
          .round();

      _beacons[beaconKey] = matched.copyWith(
        rssi: smoothed,
        distance: _estimateDistance(smoothed),
        lastSeen: DateTime.now(),
      );
    }

    notifyListeners();
  }

  void _removeStaleBeacons() {
    bool changed = false;
    final now = DateTime.now();

    _beacons.updateAll((key, beacon) {
      final secondsSinceSeen = now.difference(beacon.lastSeen).inSeconds;

      if (secondsSinceSeen > 6 && beacon.rssi != -100) {
        changed = true;

        return beacon.copyWith(
          rssi: -100,
          distance: 99.0,
          lastSeen: beacon.lastSeen,
        );
      }

      return beacon;
    });

    if (changed) {
      _evaluateZone();
      notifyListeners();
    }
  }

  String? _extractIBeaconUuid(Map<int, List<int>> manufacturerData) {
    final appleData = manufacturerData[0x004C];

    if (appleData == null || appleData.length < 18) return null;

    if (appleData[0] != 0x02 || appleData[1] != 0x15) return null;

    final uuidBytes = appleData.sublist(2, 18);

    final hex = uuidBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }

  void _evaluateZone() {
    final nearby = _beacons.values.where((b) => b.isNearby).toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    if (nearby.isEmpty) {
      final currentBeaconStillRecent = _beacons.values.any(
            (b) =>
        b.zoneId == _currentZoneId &&
            DateTime.now().difference(b.lastSeen).inSeconds < 10,
      );

      if (!currentBeaconStillRecent) {
        _currentZoneId = null;
        debugPrint('[BLE ZONE] Zona atual: $_currentZoneId');
        notifyListeners();
      }

      return;
    }

    final strongest = nearby.first;
    final newZone = strongest.zoneId;

    if (_currentZoneId == null) {
      _currentZoneId = newZone;
      debugPrint('[BLE ZONE] Zona atual: $_currentZoneId');
      notifyListeners();
      return;
    }

    final currentBeacon =
        nearby.where((b) => b.zoneId == _currentZoneId).firstOrNull;

    if (currentBeacon == null) {
      _currentZoneId = newZone;
      debugPrint('[BLE ZONE] Zona atual: $_currentZoneId');
      notifyListeners();
      return;
    }

    const int switchMarginDb = 8;

    if (newZone != _currentZoneId &&
        strongest.rssi > currentBeacon.rssi + switchMarginDb) {
      _currentZoneId = newZone;
      debugPrint('[BLE ZONE] Zona atual: $_currentZoneId');
      notifyListeners();
    }
  }

  double _estimateDistance(int rssi) {
    if (rssi == 0 || rssi <= -100) return 99.0;

    const txPower = -59;
    final ratio = rssi / txPower;

    if (ratio < 1.0) {
      return pow(ratio, 10).toDouble();
    }

    return 0.89976 * pow(ratio, 7.7095) + 0.111;
  }

  void setZoneManually(String? zoneId) {
    _currentZoneId = zoneId;
    notifyListeners();
  }

  void injectMockReading(String beaconMac, int rssi) {
    final beaconKey = _norm(beaconMac);
    final b = _beacons[beaconKey];

    if (b == null) return;

    _rssiHistory.putIfAbsent(beaconKey, () => []);
    _rssiHistory[beaconKey]!.add(rssi);

    if (_rssiHistory[beaconKey]!.length > _smoothingWindow) {
      _rssiHistory[beaconKey]!.removeAt(0);
    }

    final smoothed =
    (_rssiHistory[beaconKey]!.reduce((a, b) => a + b) /
        _rssiHistory[beaconKey]!.length)
        .round();

    _beacons[beaconKey] = b.copyWith(
      rssi: smoothed,
      distance: _estimateDistance(smoothed),
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

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}