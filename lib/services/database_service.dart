import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

class DatabaseService extends ChangeNotifier {
  final rtdb.FirebaseDatabase _db = rtdb.FirebaseDatabase.instanceFor(
    app: rtdb.FirebaseDatabase.instance.app,
    databaseURL:
    'https://smartspaceiot-default-rtdb.europe-west1.firebasedatabase.app',
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _connected = false;
  bool get connected => _connected;

  final Map<String, int> lastUpdatedCache = {};
  final Map<String, String> _displayNameCache = {};
  Map<String, String> get displayNameCache => Map.unmodifiable(_displayNameCache);

  rtdb.DatabaseReference _zonesRef() => _db.ref('smartspace/zones');
  rtdb.DatabaseReference _zoneRef(String id) => _db.ref('smartspace/zones/$id');
  rtdb.DatabaseReference _userRef(String uid) => _db.ref('smartspace/users/$uid');
  CollectionReference _logsRef() => _firestore.collection('logs');

  String _safeUidLabel(String uid) =>
      uid.length >= 6 ? uid.substring(0, 6) : uid;

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
    'lastUpdated': rtdb.ServerValue.timestamp,
    'esp32Online': false,
    'esp32LastSeen': 0,
  };

  Stream<List<ZoneUpdate>> zonesStream() {
    return _zonesRef().onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final now = DateTime.now().millisecondsSinceEpoch;

      return data.entries.map((e) {
        final zoneId = e.key as String;
        final zoneData = Map<String, dynamic>.from(e.value as Map);

        final esp32LastSeen = zoneData['esp32LastSeen'];
        final lastMs = esp32LastSeen is int ? esp32LastSeen : 0;
        lastUpdatedCache[zoneId] = lastMs;

        final esp32OnlineFlag = zoneData['esp32Online'] as bool? ?? false;
        final isAlive = esp32OnlineFlag && (now - lastMs) < 30000;
        zoneData['esp32Online'] = isAlive;

        return ZoneUpdate(zoneId: zoneId, data: zoneData);
      }).toList();
    });
  }

  Future<void> updateZoneLight(String zoneId, bool on, double intensity) async {
    try {
      await _zoneRef(zoneId).update({
        'lightOn': on,
        'lightIntensity': intensity,
        'lastUpdated': rtdb.ServerValue.timestamp,
      });
      await _db.ref('smartspace/commands/$zoneId').update({
        'lightOn': on,
        'lightIntensity': intensity,
      });
    } catch (e) {
      debugPrint('[DB] Erro ao atualizar luz: $e');
    }
  }

  Future<void> updateZoneBuzzer(String zoneId, bool on) async {
    try {
      await _zoneRef(zoneId).update({
        'buzzerOn': on,
        'lastUpdated': rtdb.ServerValue.timestamp,
      });
      await _db.ref('smartspace/commands/$zoneId').update({'buzzerOn': on});
    } catch (e) {
      debugPrint('[DB] Erro ao atualizar buzzer: $e');
    }
  }

  // ── OPERAÇÕES ATÓMICAS COM TRANSACTION ─────────────────────────────────────

  /// Adiciona um utilizador à zona usando Transaction atómica.
  ///
  /// NOTA CRÍTICA: quando presentUsers está vazio no RTDB, o Firebase
  /// guarda-o como `null` (não como `{}`). O runTransaction recebe
  /// currentData == null nesse caso. NÃO devemos fazer abort — devemos
  /// tratar null como mapa vazio e adicionar o uid.
  Future<void> addUserToZoneAtomic(String uid, String zoneId) async {
    try {
      final presentUsersRef = _zoneRef(zoneId).child('presentUsers');

      final result = await presentUsersRef.runTransaction((currentData) {
        // ✅ null significa nó vazio (Firebase remove nós com valor {})
        // Nunca fazer abort em null — criar o mapa com o uid
        final users = currentData != null
            ? Map<String, dynamic>.from(currentData as Map)
            : <String, dynamic>{};

        if (users.containsKey(uid)) {
          debugPrint('[DB] addTransaction: $uid já estava em $zoneId — abort');
          return rtdb.Transaction.abort();
        }

        users[uid] = true;
        debugPrint('[DB] addTransaction: adicionando $uid a $zoneId');
        return rtdb.Transaction.success(users);
      });

      if (!result.committed) {
        debugPrint('[DB] addUserAtomic: transaction não committed para $uid em $zoneId');
        return;
      }

      // Transaction comprometida — atualiza count e status
      final snap = await _zoneRef(zoneId).child('presentUsers').get();
      final newCount = snap.exists && snap.value is Map
          ? (snap.value as Map).length
          : 1;

      await _zoneRef(zoneId).update({
        'occupantCount': newCount,
        'status': 'occupied',
        'lastUpdated': rtdb.ServerValue.timestamp,
      });

      debugPrint('[DB] addUserAtomic: $uid entrou em $zoneId → $newCount presentes');
    } catch (e) {
      debugPrint('[DB] Erro ao adicionar utilizador (transaction): $e');
    }
  }

  /// Remove um utilizador da zona usando Transaction atómica.
  Future<void> removeUserFromZoneAtomic(String uid, String zoneId) async {
    try {
      final presentUsersRef = _zoneRef(zoneId).child('presentUsers');

      final result = await presentUsersRef.runTransaction((currentData) {
        // null = zona já vazia, nada a remover
        if (currentData == null) {
          debugPrint('[DB] removeTransaction: presentUsers null em $zoneId — abort');
          return rtdb.Transaction.abort();
        }

        final users = Map<String, dynamic>.from(currentData as Map);
        if (!users.containsKey(uid)) {
          debugPrint('[DB] removeTransaction: $uid não estava em $zoneId — abort');
          return rtdb.Transaction.abort();
        }

        users.remove(uid);
        // ✅ Se o mapa ficou vazio, retorna null explicitamente
        // para o Firebase remover o nó (em vez de guardar {})
        return rtdb.Transaction.success(users.isEmpty ? null : users);
      });

      if (!result.committed) {
        return;
      }

      // Transaction comprometida — atualiza count e status
      final snap = await _zoneRef(zoneId).child('presentUsers').get();
      final remaining = snap.exists && snap.value is Map
          ? (snap.value as Map).length
          : 0;

      await _zoneRef(zoneId).update({
        'occupantCount': remaining,
        'status': remaining == 0 ? 'free' : 'occupied',
        'lastUpdated': rtdb.ServerValue.timestamp,
      });

      debugPrint('[DB] removeUserAtomic: $uid saiu de $zoneId → $remaining restantes');
    } catch (e) {
      debugPrint('[DB] Erro ao remover utilizador (transaction): $e');
    }
  }

  /// Remove o uid de TODAS as zonas onde apareça.
  Future<void> removeUserFromAllZones(String uid) async {
    try {
      final zonesSnap = await _zonesRef().get();
      if (!zonesSnap.exists) return;

      final zones = Map<String, dynamic>.from(zonesSnap.value as Map);
      for (final entry in zones.entries) {
        final zoneId = entry.key as String;
        final zoneData = Map<String, dynamic>.from(entry.value as Map);
        final presentUsers = zoneData['presentUsers'];

        if (presentUsers is Map && presentUsers.containsKey(uid)) {
          await removeUserFromZoneAtomic(uid, zoneId);
        }
      }
    } catch (e) {
      debugPrint('[DB] Erro ao remover utilizador de todas as zonas: $e');
    }
  }

  Future<void> updateZoneOccupancy(
      String zoneId, String status, int count, List<String> uids) async {
    try {
      await _zoneRef(zoneId).update({
        'status': status,
        'occupantCount': count,
        'presentUsers': {for (final uid in uids) uid: true},
        'lastUpdated': rtdb.ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('[DB] Erro ao atualizar ocupação: $e');
    }
  }

  Future<void> updateZoneSensors(
      String zoneId, {
        double? luminosity,
        double? temperature,
        double? humidity,
        bool? motionDetected,
      }) async {
    try {
      final updates = <String, dynamic>{
        'lastUpdated': rtdb.ServerValue.timestamp,
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

  Future<void> _updateUserOnline(String uid) async {
    try {
      await removeUserFromAllZones(uid);

      await _userRef(uid).update({
        'online': true,
        'lastSeen': rtdb.ServerValue.timestamp,
        'currentZoneId': null,
      });

      await _userRef(uid).onDisconnect().update({
        'online': false,
        'lastSeen': rtdb.ServerValue.timestamp,
        'currentZoneId': null,
      });
    } catch (e) {
      debugPrint('[DB] Erro ao atualizar utilizador online: $e');
    }
  }

  Future<void> removeUserFromZone(String uid, String zoneId) async {
    await removeUserFromZoneAtomic(uid, zoneId);
  }

  Future<void> updateUserZone(String uid, String? zoneId) async {
    try {
      for (final zone in DefaultData.zones()) {
        await _zoneRef(zone.id).child('presentUsers/$uid').onDisconnect().cancel();
        await _zoneRef(zone.id).onDisconnect().cancel();
      }

      await _userRef(uid).update({
        'currentZoneId': zoneId,
        'lastSeen': rtdb.ServerValue.timestamp,
      });

      if (zoneId != null) {
        await _zoneRef(zoneId).child('presentUsers/$uid').onDisconnect().remove();

        final snap = await _zoneRef(zoneId).child('presentUsers').get();
        final presentUsers = snap.exists && snap.value is Map
            ? Map.from(snap.value as Map)
            : <dynamic, dynamic>{};
        final newCount = (presentUsers.length - 1).clamp(0, 999);

        await _zoneRef(zoneId).onDisconnect().update({
          'occupantCount': newCount,
          'status': newCount == 0 ? 'free' : 'occupied',
          'lastUpdated': rtdb.ServerValue.timestamp,
        });
      }

      await _userRef(uid).onDisconnect().update({
        'online': false,
        'lastSeen': rtdb.ServerValue.timestamp,
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
          final name =
              doc.data()?['displayName'] as String? ?? _safeUidLabel(uid);
          final role = doc.data()?['role'] as String? ?? 'user';
          _displayNameCache[uid] = name;
          users.add(OnlineUser(
            uid: uid,
            currentZoneId: userData['currentZoneId'] as String?,
            online: true,
            displayName: name,
            role: role,
          ));
        } catch (_) {
          final fallback = _safeUidLabel(uid);
          _displayNameCache[uid] = fallback;
          users.add(OnlineUser(
            uid: uid,
            currentZoneId: userData['currentZoneId'] as String?,
            online: true,
            displayName: fallback,
          ));
        }
      }
      return users;
    });
  }

  Future<String> resolveDisplayName(String uid) async {
    if (_displayNameCache.containsKey(uid)) return _displayNameCache[uid]!;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final name =
          doc.data()?['displayName'] as String? ?? _safeUidLabel(uid);
      _displayNameCache[uid] = name;
      return name;
    } catch (_) {
      return _safeUidLabel(uid);
    }
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
        'lastSeen': rtdb.ServerValue.timestamp,
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
        'lastSeen': rtdb.ServerValue.timestamp,
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