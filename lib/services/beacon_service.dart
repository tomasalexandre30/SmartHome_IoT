import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/models.dart';

class BeaconService {
  static final BeaconService _instance = BeaconService._internal();
  factory BeaconService() => _instance;
  BeaconService._internal();

  // UUID dos teus beacons (todos iguais)
  static const String targetUUID = 'fda50693-a4e2-4fb1-afcf-c6eb07647825';

  final _roomController    = StreamController<Room>.broadcast();
  final _beaconsController = StreamController<List<BeaconReading>>.broadcast();

  Stream<Room>                get roomStream    => _roomController.stream;
  Stream<List<BeaconReading>> get beaconsStream => _beaconsController.stream;

  Room _currentRoom = Room.unknown;
  Room get currentRoom => _currentRoom;

  bool _scanning = false;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<bool>?             _stateSub;

  Future<void> startScanning() async {
    if (_scanning) return;
    _scanning = true;
    await FlutterBluePlus.stopScan();
    _doScan();
    _stateSub = FlutterBluePlus.isScanning.listen((isScanning) {
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
        // Identifica pelo MAC address
        final mac = result.device.remoteId.str.toUpperCase();
        final room = Room.fromMac(mac);
        if (room == Room.unknown) continue;

        // Tenta fazer parse iBeacon para obter txPower
        int txPower = -59; // valor default
        final msd = result.advertisementData.manufacturerData;
        for (final entry in msd.entries) {
          final data = entry.value;
          if (data.length >= 23 && data[0] == 0x02 && data[1] == 0x15) {
            txPower = data[22].toSigned(8);
          }
        }

        final distance = _estimateDistance(txPower, result.rssi);
        beacons.add(BeaconReading(
          mac:      mac,
          rssi:     result.rssi,
          distance: distance,
          room:     room,
        ));
      }

      // Ordena por RSSI (mais forte = mais próximo)
      beacons.sort((a, b) => b.rssi.compareTo(a.rssi));
      _beaconsController.add(beacons);

      final newRoom = beacons.isNotEmpty ? beacons.first.room : Room.unknown;
      if (newRoom != _currentRoom) {
        _currentRoom = newRoom;
        _roomController.add(_currentRoom);
      }
    });
  }

  void stopScanning() {
    _scanning = false;
    _scanSub?.cancel();
    _stateSub?.cancel();
    FlutterBluePlus.stopScan();
  }

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

class BeaconReading {
  final String mac;
  final int rssi;
  final double distance;
  final Room room;

  const BeaconReading({
    required this.mac,
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

  // Major/Minor não usados (todos iguais), mas mantemos por compatibilidade
  int get major => 1;
  int get minor => 2;
}