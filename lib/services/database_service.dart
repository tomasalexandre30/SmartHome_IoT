import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

class DatabaseService extends ChangeNotifier {
  final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: FirebaseDatabase.instance.app,
    databaseURL: 'https://smartspaceiot-default-rtdb.europe-west1.firebasedatabase.app',
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _connected = false;
  bool get connected => _connected;

  DatabaseReference _zonesRef() => _db.ref('smartspace/zones');
  DatabaseReference _zoneRef(String id) => _db.ref('smartspace/zones/$id');
  DatabaseReference _userRef(String uid) => _db.ref('smartspace/users/$uid');
  CollectionReference _logsRef() => _firestore.collection('logs');

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

  Future<void> _initializeZones() async {
    try {
      final snapshot = await _zonesRef().get();
      if (!snapshot.exists) {
        for (final zone in DefaultData.zones()) {
          await _zoneRef(zone.id).set(_zoneToMap(zone));
        }
      }
    } catch (e) {
      debugPrint('[DB] Erro ao inicializar zonas: $e');
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
      final updates = <String, dynamic>{'lastUpdated': ServerValue.timestamp};
      if (luminosity != null) updates['luminosity'] = luminosity;
      if (temperature != null) updates['temperature'] = temperature;
      if (humidity != null) updates['humidity'] = humidity;
      if (motionDetected != null) updates['motionDetected'] = motionDetected;
      await _zoneRef(zoneId).update(updates);
    } catch (e) {
      debugPrint('[DB] Erro ao atualizar sensores: $e');
    }
  }

  // ── FIX PRINCIPAL: limpa utilizador de TODAS as zonas no login ─────────
  Future<void> _updateUserOnline(String uid) async {
    try {
      // 1. Varrer todas as zonas e remover este uid onde ainda apareça
      final zonesSnap = await _zonesRef().get();
      if (zonesSnap.exists) {
        final zones = Map<String, dynamic>.from(zonesSnap.value as Map);
        for (final entry in zones.entries) {
          final zoneId = entry.key as String;
          final zoneData = Map<String, dynamic>.from(entry.value as Map);
          final presentUsers = zoneData['presentUsers'];

          if (presentUsers is Map && presentUsers.containsKey(uid)) {
            final currentCount = (zoneData['occupantCount'] as int? ?? 1);
            final newCount = (currentCount - 1).clamp(0, 999);
            // Path nested: remove só este uid, não apaga os outros
            await _zoneRef(zoneId).update({
              'presentUsers/$uid': null,
              'occupantCount': newCount,
              'status': newCount == 0 ? 'free' : 'occupied',
              'lastUpdated': ServerValue.timestamp,
            });
            debugPrint('[DB] Login cleanup: removido $uid de $zoneId ($currentCount→$newCount)');
          }
        }
      }

      // 2. Marcar online com zona limpa
      await _userRef(uid).update({
        'online': true,
        'lastSeen': ServerValue.timestamp,
        'currentZoneId': null,
      });

      // 3. onDisconnect estático para crash/perda de rede
      await _userRef(uid).onDisconnect().update({
        'online': false,
        'lastSeen': ServerValue.timestamp,
        'currentZoneId': null,
      });

      // No fim do _updateUserOnline, após o onDisconnect existente:
      await _userRef(uid).onDisconnect().update({
        'online': false,
        'lastSeen': ServerValue.timestamp,
        'currentZoneId': null,
      });

    } catch (e) {
      debugPrint('[DB] Erro ao atualizar utilizador online: $e');
    }
  }

  /// Remove um utilizador de uma zona específica.
  /// Usado pelo SmartSpaceProvider no clearZoneOnLogout.
  Future<void> removeUserFromZone(String uid, String zoneId) async {
    try {
      final snap = await _zoneRef(zoneId).get();
      if (!snap.exists) return;
      final zoneData = Map<String, dynamic>.from(snap.value as Map);
      final presentUsers = zoneData['presentUsers'];

      if (presentUsers is Map && presentUsers.containsKey(uid)) {
        final currentCount = (zoneData['occupantCount'] as int? ?? 1);
        final newCount = (currentCount - 1).clamp(0, 999);
        await _zoneRef(zoneId).update({
          'presentUsers/$uid': null,
          'occupantCount': newCount,
          'status': newCount == 0 ? 'free' : 'occupied',
          'lastUpdated': ServerValue.timestamp,
        });
        debugPrint('[DB] removeUserFromZone: $uid saiu de $zoneId ($currentCount→$newCount)');
      }
    } catch (e) {
      debugPrint('[DB] Erro ao remover utilizador da zona: $e');
    }
  }

  Future<void> updateUserZone(String uid, String? zoneId) async {
    try {
      // Cancelar onDisconnects anteriores de zonas
      for (final zone in DefaultData.zones()) {
        await _zoneRef(zone.id).child('presentUsers/$uid').onDisconnect().cancel();
        await _zoneRef(zone.id).child('occupantCount').onDisconnect().cancel();
      }

      await _userRef(uid).update({
        'currentZoneId': zoneId,
        'lastSeen': ServerValue.timestamp,
      });

      // Se entrou numa zona nova, registar onDisconnect nessa zona
      if (zoneId != null) {
        // Remove o utilizador do presentUsers ao desligar
        await _zoneRef(zoneId)
            .child('presentUsers/$uid')
            .onDisconnect()
            .remove();

        // Vai buscar o count atual e regista onDisconnect com valor correto
        final snap = await _zoneRef(zoneId).child('occupantCount').get();
        final currentCount = (snap.value as int? ?? 1);
        final newCount = (currentCount - 1).clamp(0, 999);

        await _zoneRef(zoneId).onDisconnect().update({
          'occupantCount': newCount,
          'status': newCount == 0 ? 'free' : 'occupied',
          'lastUpdated': ServerValue.timestamp,
        });
      }

      // onDisconnect do utilizador
      await _userRef(uid).onDisconnect().update({
        'online': false,
        'lastSeen': ServerValue.timestamp,
        'currentZoneId': null,
      });

    } catch (e) {
      debugPrint('[DB] Erro ao atualizar zona do utilizador: $e');
    }
  }

  Stream<List<OnlineUser>> onlineUsersStream() {
    return _db.ref('smartspace/users').onValue.asyncMap((event) async {
      if (!event.snapshot.exists) return [];
      final data = event.snapshot.value as Map<dynamic, dynamic>;

      final onlineUids = data.entries
          .where((e) {
        final userData = Map<String, dynamic>.from(e.value as Map);
        return userData['online'] as bool? ?? false;
      })
          .map((e) => e.key as String)
          .toList();

      if (onlineUids.isEmpty) return [];

      final List<OnlineUser> users = [];
      for (final uid in onlineUids) {
        final userData = Map<String, dynamic>.from(data[uid] as Map);
        try {
          final doc = await _firestore.collection('users').doc(uid).get();
          final name = doc.data()?['displayName'] as String? ?? uid.substring(0, 6);
          final role = doc.data()?['role'] as String? ?? 'user';
          users.add(OnlineUser(
            uid: uid,
            currentZoneId: userData['currentZoneId'] as String?,
            online: true,
            displayName: name,
            role: role,
          ));
        } catch (_) {
          users.add(OnlineUser(
            uid: uid,
            currentZoneId: userData['currentZoneId'] as String?,
            online: true,
            displayName: uid.substring(0, 6),
          ));
        }
      }
      return users;
    });
  }

  Future<void> saveLog(LogEvent event, String uid, String role) async {
    try {
      await _logsRef().add({
        'id': event.id,
        'type': event.type.name,
        'zoneId': event.zoneId,
        'message': event.message,
        'userName': event.userName,
        'userRole': role,
        'category': event.category.name,
        'timestamp': Timestamp.fromDate(event.timestamp),
        'uid': uid,
      });
    } catch (e) {
      debugPrint('[DB] Erro ao guardar log: $e');
    }
  }

  Stream<List<LogEvent>> userLogsStream(String uid) {
    return _logsRef()
        .where('uid', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return LogEvent(
        id: data['id'] as String? ?? doc.id,
        type: _parseLogType(data['type'] as String? ?? ''),
        zoneId: data['zoneId'] as String? ?? '',
        message: data['message'] as String? ?? '',
        userName: data['userName'] as String? ?? '',
        userRole: data['userRole'] as String? ?? 'user',
        uid: data['uid'] as String? ?? '',
        timestamp: (data['timestamp'] as Timestamp).toDate(),
      );
    }).toList());
  }

  Stream<List<LogEvent>> allLogsStream() {
    return _logsRef()
        .orderBy('timestamp', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return LogEvent(
        id: data['id'] as String? ?? doc.id,
        type: _parseLogType(data['type'] as String? ?? ''),
        zoneId: data['zoneId'] as String? ?? '',
        message: data['message'] as String? ?? '',
        userName: data['userName'] as String? ?? '',
        userRole: data['userRole'] as String? ?? 'user',
        uid: data['uid'] as String? ?? '',
        timestamp: (data['timestamp'] as Timestamp).toDate(),
      );
    }).toList());
  }

  LogEventType _parseLogType(String type) {
    switch (type) {
      case 'userRegister':       return LogEventType.userRegister;
      case 'userLogin':          return LogEventType.userLogin;
      case 'userLogout':         return LogEventType.userLogout;
      case 'zoneEntry':          return LogEventType.zoneEntry;
      case 'zoneExit':           return LogEventType.zoneExit;
      case 'beaconDetected':     return LogEventType.beaconDetected;
      case 'manualCommand':      return LogEventType.manualCommand;
      case 'automationTrigger':  return LogEventType.automationTrigger;
      case 'connectionLost':     return LogEventType.connectionLost;
      case 'connectionRestored': return LogEventType.connectionRestored;
      case 'alert':              return LogEventType.alert;
      default:                   return LogEventType.alert;
    }
  }

  Future<void> savePreferences(String uid, UserPreferences prefs) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('preferences')
          .doc(prefs.zoneId)
          .set(prefs.toJson());
    } catch (e) {
      debugPrint('[DB] Erro ao guardar preferências: $e');
    }
  }

  Future<Map<String, UserPreferences>> loadPreferences(String uid) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('preferences')
          .get();
      return {
        for (final doc in snap.docs)
          doc.id: UserPreferences.fromJson(doc.data())
      };
    } catch (e) {
      debugPrint('[DB] Erro ao carregar preferências: $e');
      return {};
    }
  }

  Future<void> updateUserPresence(String uid, bool online) async {
    try {
      await _userRef(uid).update({
        'online': online,
        'lastSeen': ServerValue.timestamp,
        if (!online) 'currentZoneId': null,
      });
    } catch (e) {
      debugPrint('[DB] Erro ao atualizar presença: $e');
    }
  }

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

class ZoneUpdate {
  final String zoneId;
  final Map<String, dynamic> data;
  ZoneUpdate({required this.zoneId, required this.data});
}

class OnlineUser {
  final String uid;
  final String? currentZoneId;
  final bool online;
  final String displayName;
  final String role;

  OnlineUser({
    required this.uid,
    this.currentZoneId,
    required this.online,
    this.displayName = '',
    this.role = 'user',
  });

  bool get isAdmin => role == 'admin';
}