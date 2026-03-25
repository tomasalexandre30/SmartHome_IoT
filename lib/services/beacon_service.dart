import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/models.dart';

// ───────────────────────────────────────────
// SERVIÇO DE BEACONS
// Baseado no que já tens no AutonomaGPS.
// Adapta o TARGET_UUID ao UUID dos teus beacons.
// ───────────────────────────────────────────
class BeaconService {
  // Singleton
  static final BeaconService _instance = BeaconService._internal();
  factory BeaconService() => _instance;
  BeaconService._internal();

  // ─── CONFIGURAÇÃO ───────────────────────
  // Substitui pelo UUID dos teus beacons
  static const String targetUUID = 'FDA50693-A4E2-4FB1-AFCF-C6EB07647825';
  // Company ID do Apple iBeacon (little-endian: 0x4C, 0x00)
  static const int appleCompanyId = 0x004C;
  // ────────────────────────────────────────

  final _roomController    = StreamController<Room>.broadcast();
  final _beaconsController = StreamController<List<BeaconReading>>.broadcast();

  Stream<Room>               get roomStream    => _roomController.stream;
  Stream<List<BeaconReading>> get beaconsStream => _beaconsController.stream;

  Room _currentRoom = Room.unknown;
  Room get currentRoom => _currentRoom;

  bool _scanning = false;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<bool>?             _scanningStateSub;

  // ─── INICIAR ────────────────────────────
  Future<void> startScanning() async {
    if (_scanning) return;
    _scanning = true;

    await FlutterBluePlus.stopScan();
    _doScan();

    // Reinicia automaticamente quando o scan termina
    _scanningStateSub = FlutterBluePlus.isScanning.listen((isScanning) {
      if (!isScanning && _scanning) {
        Future.delayed(const Duration(seconds: 2), _doScan);
      }
    });
  }

  void _doScan() {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      final beacons = <BeaconReading>[];

      for (final result in results) {
        final msd = result.advertisementData.manufacturerData;
        for (final entry in msd.entries) {
          // Verifica company ID Apple
          if (entry.key != appleCompanyId) continue;
          final data = entry.value;
          // iBeacon: byte[0]=0x02, byte[1]=0x15, depois 16 bytes UUID, 2 major, 2 minor, 1 txPower
          if (data.length < 23) continue;
          if (data[0] != 0x02 || data[1] != 0x15) continue;

          final major    = (data[18] << 8) | data[19];
          final minor    = (data[20] << 8) | data[21];
          final txPower  = data[22].toSigned(8);
          final distance = _estimateDistance(txPower, result.rssi);

          beacons.add(BeaconReading(
            major:    major,
            minor:    minor,
            rssi:     result.rssi,
            distance: distance,
            room:     Room.fromMajor(major),
          ));
        }
      }

      // Ordena por RSSI (mais forte = mais próximo)
      beacons.sort((a, b) => b.rssi.compareTo(a.rssi));
      _beaconsController.add(beacons);

      // Sala atual = beacon mais forte
      final newRoom = beacons.isNotEmpty ? beacons.first.room : Room.unknown;
      if (newRoom != _currentRoom) {
        _currentRoom = newRoom;
        _roomController.add(_currentRoom);
      }
    });
  }

  // ─── PARAR ──────────────────────────────
  void stopScanning() {
    _scanning = false;
    _scanSub?.cancel();
    _scanningStateSub?.cancel();
    FlutterBluePlus.stopScan();
  }

  // ─── FÓRMULA DISTÂNCIA ──────────────────
  // Mesmo algoritmo que usas no AutonomaGPS
  double _estimateDistance(int txPower, int rssi) {
    if (rssi == 0) return -1.0;
    final ratio = rssi / txPower;
    if (ratio < 1.0) return ratio.abs();
    return 0.89976 * (ratio * ratio * ratio) + 7.7095 * ratio + 0.111;
  }

  void dispose() {
    stopScanning();
    _roomController.close();
    _beaconsController.close();
  }
}

// ───────────────────────────────────────────
// MODELO DE LEITURA DE BEACON
// ───────────────────────────────────────────
class BeaconReading {
  final int major;
  final int minor;
  final int rssi;
  final double distance;
  final Room room;

  const BeaconReading({
    required this.major,
    required this.minor,
    required this.rssi,
    required this.distance,
    required this.room,
  });

  String get signalBar {
    if (rssi > -60) return '▂▄▆█';
    if (rssi > -70) return '▂▄▆░';
    if (rssi > -80) return '▂▄░░';
    return '▂░░░';
  }
}
