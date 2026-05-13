import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import 'database_service.dart';
import 'auth_service.dart';

class SmartSpaceProvider extends ChangeNotifier {
  List<Zone> _zones = DefaultData.zones();
  List<Zone> get zones => _zones;

  final List<LogEvent> _logs = [];
  List<LogEvent> get logs => List.unmodifiable(_logs.reversed.toList());

  String? _currentZoneId;
  String? get currentZoneId => _currentZoneId;

  Zone? get currentZone => _currentZoneId != null
      ? _zones.firstWhere((z) => z.id == _currentZoneId,
      orElse: () => _zones.first)
      : null;

  bool _isConnected = true;
  bool get isConnected => _isConnected;
  bool get isAutonomous => !_isConnected;

  final Map<String, UserPreferences> _preferences = {};
  final List<Function()> _pendingCommands = [];
  Timer? _prefsLogTimer;

  DatabaseService? _db;
  String? _uid;
  AppUser? _appUser;
  StreamSubscription? _zonesSub;

  void attachDatabase(DatabaseService db, String uid, AppUser? appUser) {
    _db = db;
    _uid = uid;
    _appUser = appUser;
    _currentZoneId = null;
    _listenZones();
    _listenConnection();
    _loadPreferences();
  }

  void _listenZones() {
    _zonesSub?.cancel();
    _zonesSub = _db!.zonesStream().listen((updates) {
      for (final update in updates) {
        _applyZoneUpdate(update);
      }
      notifyListeners();
    }, onError: (e) {
      debugPrint('[SS] Erro ao ouvir zonas: $e');
    });
  }

  void _listenConnection() {
    _db!.addListener(() {
      setConnected(_db!.connected);
    });
  }

  Future<void> _loadPreferences() async {
    if (_db == null || _uid == null) return;
    try {
      final prefs = await _db!.loadPreferences(_uid!);
      _preferences.addAll(prefs);
      notifyListeners();
    } catch (e) {
      debugPrint('[SS] Erro ao carregar preferências: $e');
    }
  }

  void _applyZoneUpdate(ZoneUpdate update) {
    final d = update.data;
    final safeCount = ((d['occupantCount'] as int?) ?? 0).clamp(0, 999);

    _zones = _zones.map((z) {
      if (z.id != update.zoneId) return z;
      return z.copyWith(
        status: _parseStatus(d['status'] as String? ?? 'unknown'),
        occupantCount: safeCount,
        lightOn: d['lightOn'] as bool? ?? false,
        lightIntensity: (d['lightIntensity'] as num?)?.toDouble() ?? 1.0,
        lightR: (d['lightR'] as int?) ?? 255,
        lightG: (d['lightG'] as int?) ?? 255,
        lightB: (d['lightB'] as int?) ?? 255,
        buzzerOn: d['buzzerOn'] as bool? ?? false,
        luminosity: (d['luminosity'] as num?)?.toDouble(),
        temperature: (d['temperature'] as num?)?.toDouble(),
        humidity: (d['humidity'] as num?)?.toDouble(),
        motionDetected: d['motionDetected'] as bool?,
        presentUsers: d['presentUsers'] != null
            ? List<String>.from(
            (d['presentUsers'] as Map).keys.map((k) => k.toString()))
            : [],
        esp32Online: d['esp32Online'] as bool? ?? false,
      );
    }).toList();
  }

  void reevaluateEsp32Status() {
    if (_db == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    bool changed = false;

    _zones = _zones.map((z) {
      final lastMs = _db!.lastUpdatedCache[z.id] ?? 0;
      final shouldBeOnline = lastMs > 0 && (now - lastMs) < 30000;

      if (z.esp32Online != shouldBeOnline) {
        changed = true;
        debugPrint('[SS] ${z.name} ESP32: ${z.esp32Online} → $shouldBeOnline');
        return z.copyWith(esp32Online: shouldBeOnline);
      }
      return z;
    }).toList();

    if (changed) notifyListeners();
  }

  ZoneStatus _parseStatus(String s) {
    switch (s) {
      case 'occupied': return ZoneStatus.occupied;
      case 'free':     return ZoneStatus.free;
      default:         return ZoneStatus.unknown;
    }
  }

  Zone? zoneById(String id) {
    try { return _zones.firstWhere((z) => z.id == id); }
    catch (_) { return null; }
  }

  void updateZoneFromBeacon(String? zoneId) {
    if (zoneId == _currentZoneId) return;
    if (_uid == null) return;

    final prev = _currentZoneId;
    _currentZoneId = zoneId;

    if (prev != null) {
      if (_isConnected) {
        _db?.removeUserFromZoneAtomic(_uid!, prev);
        _db?.updateUserZone(_uid!, zoneId);
      } else {
        _pendingCommands.add(() => _db?.removeUserFromZoneAtomic(_uid!, prev));
        _pendingCommands.add(() => _db?.updateUserZone(_uid!, zoneId));
      }

      _log(LogEvent(
        id: _uid_(),
        type: LogEventType.zoneExit,
        zoneId: prev,
        message: '$_displayName saiu da ${zoneById(prev)?.name ?? prev}'
            '${_isConnected ? "" : " (modo autónomo)"}',
        userName: _displayName,
        userRole: _appUser?.role.name ?? 'user',
        uid: _uid ?? '',
      ));
    }

    if (zoneId != null) {
      if (_isConnected) {
        _db?.addUserToZoneAtomic(_uid!, zoneId);
        if (prev == null) {
          _db?.updateUserZone(_uid!, zoneId);
        }
      } else {
        _pendingCommands.add(() => _db?.addUserToZoneAtomic(_uid!, zoneId));
        if (prev == null) {
          _pendingCommands.add(() => _db?.updateUserZone(_uid!, zoneId));
        }
      }

      _log(LogEvent(
        id: _uid_(),
        type: LogEventType.zoneEntry,
        zoneId: zoneId,
        message: '$_displayName entrou na ${zoneById(zoneId)?.name ?? zoneId}'
            '${_isConnected ? "" : " (modo autónomo)"}',
        userName: _displayName,
        userRole: _appUser?.role.name ?? 'user',
        uid: _uid ?? '',
      ));

      _applyPreferences(zoneId);
    }

    notifyListeners();
  }

  String get _displayName =>
      _appUser?.displayName ?? _uid?.substring(0, 6) ?? 'Utilizador';

  void _updateZone(String id, Zone Function(Zone) fn) {
    _zones = _zones.map((z) => z.id == id ? fn(z) : z).toList();
  }

  Future<void> clearZoneOnLogout() async {
    if (_uid == null) return;
    final prev = _currentZoneId;
    _currentZoneId = null;

    if (prev != null) {
      final prevZone = zoneById(prev);
      if (_isConnected && _db != null) {
        await _db!.removeUserFromZoneAtomic(_uid!, prev);
        await _db!.updateUserZone(_uid!, null);
      }
      _log(LogEvent(
        id: _uid_(),
        type: LogEventType.zoneExit,
        zoneId: prev,
        message: '$_displayName saiu da ${prevZone?.name ?? prev} (logout)',
        userName: _displayName,
        userRole: _appUser?.role.name ?? 'user',
        uid: _uid ?? '',
      ));
    }

    _zonesSub?.cancel();
    _zonesSub = null;
    _pendingCommands.clear();
    notifyListeners();
  }

  void toggleLight(String zoneId) {
    final z = zoneById(zoneId);
    if (z == null) return;
    final newState = !z.lightOn;
    _updateZone(zoneId, (z) => z.copyWith(lightOn: newState));
    if (_isConnected) {
      _db?.updateZoneLight(zoneId, newState, z.lightIntensity,
          r: z.lightR, g: z.lightG, b: z.lightB);
    } else {
      _pendingCommands.add(() => _db?.updateZoneLight(
          zoneId, newState, z.lightIntensity,
          r: z.lightR, g: z.lightG, b: z.lightB));
    }
    _log(LogEvent(
      id: _uid_(),
      type: LogEventType.manualCommand,
      zoneId: zoneId,
      message: '$_displayName ${newState ? "ligou" : "desligou"} a luz na ${z.name}'
          '${_isConnected ? "" : " (modo autónomo)"}',
      userName: _displayName,
      userRole: _appUser?.role.name ?? 'user',
      uid: _uid ?? '',
    ));
    notifyListeners();
  }

  void setLightIntensity(String zoneId, double value) {
    final z = zoneById(zoneId);
    if (z == null) return;
    _updateZone(zoneId, (z) => z.copyWith(lightIntensity: value));
    if (_isConnected) {
      _db?.updateZoneLight(zoneId, z.lightOn, value,
          r: z.lightR, g: z.lightG, b: z.lightB);
    } else {
      _pendingCommands.add(() => _db?.updateZoneLight(
          zoneId, z.lightOn, value,
          r: z.lightR, g: z.lightG, b: z.lightB));
    }
    notifyListeners();
  }

  void setLightColor(String zoneId, Color color) {
    final z = zoneById(zoneId);
    if (z == null) return;
    final r = color.red;
    final g = color.green;
    final b = color.blue;
    _updateZone(zoneId, (zone) => zone.copyWith(lightR: r, lightG: g, lightB: b));
    if (_isConnected) {
      _db?.updateZoneLight(zoneId, z.lightOn, z.lightIntensity, r: r, g: g, b: b);
    } else {
      _pendingCommands.add(() =>
          _db?.updateZoneLight(zoneId, z.lightOn, z.lightIntensity, r: r, g: g, b: b));
    }
    _log(LogEvent(
      id: _uid_(),
      type: LogEventType.manualCommand,
      zoneId: zoneId,
      message: '$_displayName alterou a cor do LED na ${z.name} '
          '(R:$r G:$g B:$b)'
          '${_isConnected ? "" : " (modo autónomo)"}',
      userName: _displayName,
      userRole: _appUser?.role.name ?? 'user',
      uid: _uid ?? '',
    ));
    notifyListeners();
  }

  void toggleBuzzer(String zoneId) {
    final z = zoneById(zoneId);
    if (z == null) return;
    final newState = !z.buzzerOn;
    _updateZone(zoneId, (z) => z.copyWith(buzzerOn: newState));
    if (_isConnected) {
      _db?.updateZoneBuzzer(zoneId, newState);
    } else {
      _pendingCommands.add(() => _db?.updateZoneBuzzer(zoneId, newState));
    }
    _log(LogEvent(
      id: _uid_(),
      type: LogEventType.manualCommand,
      zoneId: zoneId,
      message: '$_displayName ${newState ? "ligou" : "desligou"} o buzzer na ${z.name}'
          '${_isConnected ? "" : " (modo autónomo)"}',
      userName: _displayName,
      userRole: _appUser?.role.name ?? 'user',
      uid: _uid ?? '',
    ));
    notifyListeners();
  }

  void injectSensorData(String zoneId,
      {double? luminosity, double? temperature, double? humidity, bool? motion}) {
    _updateZone(zoneId, (z) => z.copyWith(
      luminosity: luminosity ?? z.luminosity,
      temperature: temperature ?? z.temperature,
      humidity: humidity ?? z.humidity,
      motionDetected: motion ?? z.motionDetected,
    ));
    if (_isConnected) {
      _db?.updateZoneSensors(zoneId,
          luminosity: luminosity,
          temperature: temperature,
          humidity: humidity,
          motionDetected: motion);
    } else {
      _pendingCommands.add(() => _db?.updateZoneSensors(zoneId,
          luminosity: luminosity,
          temperature: temperature,
          humidity: humidity,
          motionDetected: motion));
    }
    notifyListeners();
  }

  UserPreferences preferencesFor(String zoneId) =>
      _preferences[zoneId] ?? UserPreferences(zoneId: zoneId);

  void updatePreferences(UserPreferences prefs) {
    _preferences[prefs.zoneId] = prefs;
    if (_db != null && _uid != null) _db!.savePreferences(_uid!, prefs);
    _prefsLogTimer?.cancel();
    _prefsLogTimer = Timer(const Duration(seconds: 1), () {
      _log(LogEvent(
        id: _uid_(),
        type: LogEventType.manualCommand,
        zoneId: prefs.zoneId,
        message: '$_displayName atualizou preferências na '
            '${zoneById(prefs.zoneId)?.name ?? prefs.zoneId} '
            '(luz: ${(prefs.lightIntensity * 100).toInt()}%, '
            'temp: ${prefs.temperatureTarget.toStringAsFixed(0)}°C'
            '${prefs.doNotDisturb ? ", DND ativo" : ""})',
        userName: _displayName,
        userRole: _appUser?.role.name ?? 'user',
        uid: _uid ?? '',
      ));
      notifyListeners();
    });
    notifyListeners();
  }

  void _applyPreferences(String zoneId) {
    final prefs = _preferences[zoneId];
    if (prefs == null || !prefs.enabled) return; // ← verifica enabled
    final r = prefs.lightColor.red;
    final g = prefs.lightColor.green;
    final b = prefs.lightColor.blue;
    _updateZone(zoneId, (z) => z.copyWith(
        lightOn: true,
        lightIntensity: prefs.lightIntensity,
        lightR: r, lightG: g, lightB: b));
    if (_isConnected) {
      _db?.updateZoneLight(zoneId, true, prefs.lightIntensity, r: r, g: g, b: b);
    } else {
      _pendingCommands.add(() =>
          _db?.updateZoneLight(zoneId, true, prefs.lightIntensity, r: r, g: g, b: b));
    }
    _log(LogEvent(
      id: _uid_(),
      type: LogEventType.automationTrigger,
      zoneId: zoneId,
      message: 'Preferências de $_displayName aplicadas na ${zoneById(zoneId)?.name ?? zoneId}',
      userName: _displayName,
      userRole: _appUser?.role.name ?? 'user',
      uid: _uid ?? '',
    ));
  }

  void checkAutomations(String zoneId) {
    final z = zoneById(zoneId);
    if (z == null) return;
    for (final rule in z.rules.where((r) => r.enabled)) {
      final sensorValue = _sensorValue(z, rule.sensorKey);
      if (sensorValue == null) continue;
      if (_evaluate(sensorValue, rule.operator, rule.threshold)) {
        _executeAction(zoneId, rule);
      }
    }
  }

  double? _sensorValue(Zone z, String key) {
    switch (key) {
      case 'luminosity':  return z.luminosity;
      case 'temperature': return z.temperature;
      case 'humidity':    return z.humidity;
      case 'motion':      return z.motionDetected == true ? 1.0 : 0.0;
      default:            return null;
    }
  }

  bool _evaluate(double value, String op, double threshold) {
    switch (op) {
      case '<':  return value < threshold;
      case '>':  return value > threshold;
      case '==': return (value - threshold).abs() < 0.01;
      default:   return false;
    }
  }

  void _executeAction(String zoneId, AutomationRule rule) {
    switch (rule.action) {
      case 'light_on':
        _updateZone(zoneId, (z) => z.copyWith(lightOn: true));
        if (_isConnected) { _db?.updateZoneLight(zoneId, true, 1.0); }
        else { _pendingCommands.add(() => _db?.updateZoneLight(zoneId, true, 1.0)); }
        break;
      case 'light_off':
        _updateZone(zoneId, (z) => z.copyWith(lightOn: false));
        if (_isConnected) { _db?.updateZoneLight(zoneId, false, 0.0); }
        else { _pendingCommands.add(() => _db?.updateZoneLight(zoneId, false, 0.0)); }
        break;
      case 'buzzer':
        _updateZone(zoneId, (z) => z.copyWith(buzzerOn: true));
        if (_isConnected) { _db?.updateZoneBuzzer(zoneId, true); }
        else { _pendingCommands.add(() => _db?.updateZoneBuzzer(zoneId, true)); }
        break;
    }
    _log(LogEvent(
      id: _uid_(),
      type: LogEventType.automationTrigger,
      zoneId: zoneId,
      message: 'Automação: ${rule.label}',
      userName: 'Sistema',
      userRole: 'system',
      uid: _uid ?? '',
    ));
    notifyListeners();
  }

  void setConnected(bool v) {
    if (_isConnected == v) return;
    _isConnected = v;
    if (v && _pendingCommands.isNotEmpty) {
      debugPrint('[SS] Sincronizando ${_pendingCommands.length} comandos pendentes...');
      for (final cmd in _pendingCommands) cmd();
      _pendingCommands.clear();
    }
    _log(LogEvent(
      id: _uid_(),
      type: v ? LogEventType.connectionRestored : LogEventType.connectionLost,
      zoneId: '',
      message: v
          ? 'Ligação restabelecida — estado sincronizado'
          : 'Ligação perdida — modo autónomo ativo',
      userName: 'Sistema',
      userRole: 'system',
      uid: _uid ?? '',
    ));
    notifyListeners();
  }

  void _log(LogEvent e) {
    _logs.add(e);
    if (_logs.length > 200) _logs.removeAt(0);
    if (_db != null && _uid != null && _isConnected) {
      _db!.saveLog(e, _uid!, e.userRole);
    } else if (!_isConnected) {
      _pendingCommands.add(() => _db!.saveLog(e, _uid!, e.userRole));
    }
  }

  void addLog(LogEvent e) {
    _log(e);
    notifyListeners();
  }

  @override
  void dispose() {
    _prefsLogTimer?.cancel();
    _zonesSub?.cancel();
    super.dispose();
  }

  int _counter = 0;
  String _uid_() => '${DateTime.now().millisecondsSinceEpoch}_${_counter++}';
}