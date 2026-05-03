import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

class DatabaseService extends ChangeNotifier {
  final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: FirebaseDatabase.instance.app,
    databaseURL: 'https://smartspaceiot-default-rtdb.europe-west1.firebasedatabase.app',
  );

  bool _connected = false;
  bool get connected => _connected;

  // ── Referências ────────────────────────────────────────────────────────
  DatabaseReference _zonesRef() => _db.ref('smartspace/zones');
  DatabaseReference _zoneRef(String id) => _db.ref('smartspace/zones/$id');
  DatabaseReference _userRef(String uid) => _db.ref('smartspace/users/$uid');
  DatabaseReference _commandRef(String zoneId) =>
      _db.ref('smartspace/commands/$zoneId');

  // ── Inicialização ──────────────────────────────────────────────────────
  Future<void> initialize(String uid) async {
    await _initializeZones();
    await _updateUserOnline(uid);
    _listenConnection();
  }

  void _listenConnection() {
    _db.ref('.info/connected').onValue.listen((event) {
      _connected = event.snapshot.value as bool? ?? false;
      notifyListeners();
    });
  }

  // ── Zonas ──────────────────────────────────────────────────────────────

  Future<void> _initializeZones() async {
    final snapshot = await _zonesRef().get();
    if (!snapshot.exists) {
      // Cria as zonas com valores default se não existirem
      for (final zone in DefaultData.zones()) {
        await _zoneRef(zone.id).set(_zoneToMap(zone));
      }
    }
  }

  Map<String, dynamic> _zoneToMap(Zone zone) => {
    'status': zone.status.name,
    'occupantCount': zone.occupantCount,
    'lightOn': zone.lightOn,
    'lightIntensity': zone.lightIntensity,
    'buzzerOn': zone.buzzerOn,
    'presentUsers': {},
    'luminosity': zone.luminosity,
    'temperature': zone.temperature,
    'humidity': zone.humidity,
    'motionDetected': zone.motionDetected,
    'energyUsageWh': zone.energyUsageWh,
    'lastUpdated': ServerValue.timestamp,
  };

  // ── Stream de zonas em tempo real ──────────────────────────────────────
  Stream<List<ZoneUpdate>> zonesStream() {
    return _zonesRef().onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      return data.entries.map((e) {
        final zoneData = Map<String, dynamic>.from(e.value as Map);
        return ZoneUpdate(zoneId: e.key as String, data: zoneData);
      }).toList();
    });
  }

  // ── Atualizar estado da zona ───────────────────────────────────────────
  Future<void> updateZoneLight(String zoneId, bool on, double intensity) async {
    try {
      await _zoneRef(zoneId).update({
        'lightOn': on,
        'lightIntensity': intensity,
        'lastUpdated': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('[DB] Erro ao atualizar luz: $e');
    }
  }

  Future<void> updateZoneBuzzer(String zoneId, bool on) async {
    try {
      await _zoneRef(zoneId).update({
        'buzzerOn': on,
        'lastUpdated': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('[DB] Erro ao atualizar buzzer: $e');
    }
  }

  Future<void> updateZoneOccupancy(
      String zoneId, String status, int count, List<String> users) async {
    try {
      await _zoneRef(zoneId).update({
        'status': status,
        'occupantCount': count,
        'presentUsers': {for (final u in users) u: true},
        'lastUpdated': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('[DB] Erro ao atualizar ocupação: $e');
    }
  }

  Future<void> updateZoneSensors(String zoneId, {
    double? luminosity,
    double? temperature,
    double? humidity,
    bool? motionDetected,
  }) async {
    try {
      final updates = <String, dynamic>{
        'lastUpdated': ServerValue.timestamp,
      };
      if (luminosity != null) updates['luminosity'] = luminosity;
      if (temperature != null) updates['temperature'] = temperature;
      if (humidity != null) updates['humidity'] = humidity;
      if (motionDetected != null) updates['motionDetected'] = motionDetected;

      await _zoneRef(zoneId).update(updates);
    } catch (e) {
      debugPrint('[DB] Erro ao atualizar sensores: $e');
    }
  }

  // ── Utilizador online ──────────────────────────────────────────────────
  Future<void> _updateUserOnline(String uid) async {
    try {
      await _userRef(uid).update({
        'online': true,
        'lastSeen': ServerValue.timestamp,
      });

      // Quando desliga, marca como offline
      await _userRef(uid).onDisconnect().update({
        'online': false,
        'lastSeen': ServerValue.timestamp,
        'currentZoneId': null,
      });
    } catch (e) {
      debugPrint('[DB] Erro ao atualizar utilizador online: $e');
    }
  }

  Future<void> updateUserZone(String uid, String? zoneId) async {
    try {
      await _userRef(uid).update({
        'currentZoneId': zoneId,
        'lastSeen': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('[DB] Erro ao atualizar zona do utilizador: $e');
    }
  }

  // ── Stream de utilizadores online (admin) ──────────────────────────────
  Stream<List<OnlineUser>> onlineUsersStream() {
    return _db.ref('smartspace/users').onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      return data.entries
          .map((e) {
        final userData = Map<String, dynamic>.from(e.value as Map);
        return OnlineUser(
          uid: e.key as String,
          currentZoneId: userData['currentZoneId'] as String?,
          online: userData['online'] as bool? ?? false,
        );
      })
          .where((u) => u.online)
          .toList();
    });
  }

  // ── Comandos on-demand ─────────────────────────────────────────────────
  Future<void> sendCommand(String zoneId, Map<String, dynamic> command) async {
    try {
      await _commandRef(zoneId).update({
        ...command,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('[DB] Erro ao enviar comando: $e');
    }
  }

  // ── Cleanup ────────────────────────────────────────────────────────────
  Future<void> goOffline(String uid) async {
    try {
      await _userRef(uid).update({
        'online': false,
        'lastSeen': ServerValue.timestamp,
        'currentZoneId': null,
      });
    } catch (e) {
      debugPrint('[DB] Erro ao marcar offline: $e');
    }
  }
}

// ── Modelos auxiliares ─────────────────────────────────────────────────────────

class ZoneUpdate {
  final String zoneId;
  final Map<String, dynamic> data;
  ZoneUpdate({required this.zoneId, required this.data});
}

class OnlineUser {
  final String uid;
  final String? currentZoneId;
  final bool online;
  OnlineUser({required this.uid, this.currentZoneId, required this.online});
}