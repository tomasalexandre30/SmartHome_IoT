import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'database_service.dart';
import 'auth_service.dart';

class SmartSpaceProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────
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

  final Map<String, UserPreferences> _preferences = {};

  // ── Database ───────────────────────────────────────────────────────────
  DatabaseService? _db;
  String? _uid;
  AppUser? _appUser;
  StreamSubscription? _zonesSub;

  void attachDatabase(DatabaseService db, String uid, AppUser? appUser) {
    _db = db;
    _uid = uid;
    _appUser = appUser;
    _listenZones();
    _listenConnection();
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

  void _applyZoneUpdate(ZoneUpdate update) {
    final d = update.data;
    _zones = _zones.map((z) {
      if (z.id != update.zoneId) return z;
      return z.copyWith(
        status: _parseStatus(d['status'] as String? ?? 'unknown'),
        occupantCount: d['occupantCount'] as int? ?? 0,
        lightOn: d['lightOn'] as bool? ?? false,
        lightIntensity: (d['lightIntensity'] as num?)?.toDouble() ?? 1.0,
        buzzerOn: d['buzzerOn'] as bool? ?? false,
        luminosity: (d['luminosity'] as num?)?.toDouble(),
        temperature: (d['temperature'] as num?)?.toDouble(),
        humidity: (d['humidity'] as num?)?.toDouble(),
        motionDetected: d['motionDetected'] as bool?,
        presentUsers: d['presentUsers'] != null
            ? List<String>.from(
            (d['presentUsers'] as Map).keys.map((k) => k.toString()))
            : [],
      );
    }).toList();
  }

  ZoneStatus _parseStatus(String s) {
    switch (s) {
      case 'occupied': return ZoneStatus.occupied;
      case 'free':     return ZoneStatus.free;
      default:         return ZoneStatus.unknown;
    }
  }

  // ── Zone helpers ───────────────────────────────────────────────────────
  Zone? zoneById(String id) {
    try { return _zones.firstWhere((z) => z.id == id); }
    catch (_) { return null; }
  }

  void updateZoneFromBeacon(String? zoneId) {
    if (zoneId == _currentZoneId) return;

    final prev = _currentZoneId;
    _currentZoneId = zoneId;

    if (prev != null) {
      final prevZone = zoneById(prev);
      final newCount = (prevZone?.occupantCount ?? 1) - 1;
      final newUsers = [...?prevZone?.presentUsers]..remove(_displayName);

      _updateZone(prev, (z) => z.copyWith(
        status: newCount <= 0 ? ZoneStatus.free : ZoneStatus.occupied,
        occupantCount: newCount.clamp(0, 99),
        presentUsers: newUsers,
      ));

      _db?.updateZoneOccupancy(
        prev,
        newCount <= 0 ? 'free' : 'occupied',
        newCount.clamp(0, 99),
        newUsers,
      );
      _db?.updateUserZone(_uid!, null);

      _log(LogEvent(
        id: _uid_(),
        type: LogEventType.zoneExit,
        zoneId: prev,
        message: '$_displayName saiu da ${zoneById(prev)?.name ?? prev}',
        userName: _displayName,
      ));
    }

    if (zoneId != null) {
      final newZone = zoneById(zoneId);
      final newCount = (newZone?.occupantCount ?? 0) + 1;
      final newUsers = [...?newZone?.presentUsers, _displayName];

      _updateZone(zoneId, (z) => z.copyWith(
        status: ZoneStatus.occupied,
        occupantCount: newCount,
        presentUsers: newUsers,
      ));

      _db?.updateZoneOccupancy(zoneId, 'occupied', newCount, newUsers);
      _db?.updateUserZone(_uid!, zoneId);

      _log(LogEvent(
        id: _uid_(),
        type: LogEventType.zoneEntry,
        zoneId: zoneId,
        message: '$_displayName entrou na ${zoneById(zoneId)?.name ?? zoneId}',
        userName: _displayName,
      ));

      _applyPreferences(zoneId);
    }

    notifyListeners();
  }

  String get _displayName => _appUser?.displayName ?? _uid?.substring(0, 6) ?? 'Utilizador';

  void _updateZone(String id, Zone Function(Zone) fn) {
    _zones = _zones.map((z) => z.id == id ? fn(z) : z).toList();
  }

  // ── Manual commands ────────────────────────────────────────────────────
  void toggleLight(String zoneId) {
    final z = zoneById(zoneId);
    if (z == null) return;
    final newState = !z.lightOn;
    _updateZone(zoneId, (z) => z.copyWith(lightOn: newState));
    _db?.updateZoneLight(zoneId, newState, z.lightIntensity);
    _log(LogEvent(
      id: _uid_(),
      type: LogEventType.manualCommand,
      zoneId: zoneId,
      message: '$_displayName ${newState ? "ligou" : "desligou"} a luz na ${z.name}',
      userName: _displayName,
    ));
    notifyListeners();
  }

  void setLightIntensity(String zoneId, double value) {
    final z = zoneById(zoneId);
    if (z == null) return;
    _updateZone(zoneId, (z) => z.copyWith(lightIntensity: value));
    _db?.updateZoneLight(zoneId, z.lightOn, value);
    notifyListeners();
  }

  void toggleBuzzer(String zoneId) {
    final z = zoneById(zoneId);
    if (z == null) return;
    final newState = !z.buzzerOn;
    _updateZone(zoneId, (z) => z.copyWith(buzzerOn: newState));
    _db?.updateZoneBuzzer(zoneId, newState);
    _log(LogEvent(
      id: _uid_(),
      type: LogEventType.manualCommand,
      zoneId: zoneId,
      message: '$_displayName ${newState ? "ligou" : "desligou"} o buzzer na ${z.name}',
      userName: _displayName,
    ));
    notifyListeners();
  }

  // ── Mock sensor data ───────────────────────────────────────────────────
  void injectSensorData(String zoneId, {
    double? luminosity,
    double? temperature,
    double? humidity,
    bool? motion,
  }) {
    _updateZone(zoneId, (z) => z.copyWith(
      luminosity: luminosity ?? z.luminosity,
      temperature: temperature ?? z.temperature,
      humidity: humidity ?? z.humidity,
      motionDetected: motion ?? z.motionDetected,
    ));
    _db?.updateZoneSensors(zoneId,
      luminosity: luminosity,
      temperature: temperature,
      humidity: humidity,
      motionDetected: motion,
    );
    notifyListeners();
  }

  // ── Preferences ────────────────────────────────────────────────────────
  UserPreferences preferencesFor(String zoneId) =>
      _preferences[zoneId] ?? UserPreferences(zoneId: zoneId);

  void updatePreferences(UserPreferences prefs) {
    _preferences[prefs.zoneId] = prefs;
    notifyListeners();
  }

  void _applyPreferences(String zoneId) {
    final prefs = _preferences[zoneId];
    if (prefs == null) return;
    _updateZone(zoneId, (z) => z.copyWith(
      lightOn: true,
      lightIntensity: prefs.lightIntensity,
    ));
    _db?.updateZoneLight(zoneId, true, prefs.lightIntensity);
    _log(LogEvent(
      id: _uid_(),
      type: LogEventType.automationTrigger,
      zoneId: zoneId,
      message: 'Preferências de $_displayName aplicadas na ${zoneById(zoneId)?.name ?? zoneId}',
      userName: _displayName,
    ));
  }

  // ── Automation rules ───────────────────────────────────────────────────
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
        _db?.updateZoneLight(zoneId, true, 1.0);
        break;
      case 'light_off':
        _updateZone(zoneId, (z) => z.copyWith(lightOn: false));
        _db?.updateZoneLight(zoneId, false, 0.0);
        break;
      case 'buzzer':
        _updateZone(zoneId, (z) => z.copyWith(buzzerOn: true));
        _db?.updateZoneBuzzer(zoneId, true);
        break;
    }
    _log(LogEvent(
      id: _uid_(),
      type: LogEventType.automationTrigger,
      zoneId: zoneId,
      message: 'Automação: ${rule.label}',
      userName: 'Sistema',
    ));
    notifyListeners();
  }

  // ── Connection ─────────────────────────────────────────────────────────
  void setConnected(bool v) {
    if (_isConnected == v) return;
    _isConnected = v;
    _log(LogEvent(
      id: _uid_(),
      type: v ? LogEventType.connectionRestored : LogEventType.connectionLost,
      zoneId: '',
      message: v ? 'Ligação restabelecida' : 'Ligação perdida — modo autónomo',
      userName: 'Sistema',
    ));
    notifyListeners();
  }

  // ── Log ────────────────────────────────────────────────────────────────
  void _log(LogEvent e) {
    _logs.add(e);
    if (_logs.length > 200) _logs.removeAt(0);
    if (_db != null && _uid != null) {
      _db!.saveLog(e, _uid!, _appUser?.role.name ?? 'user');
    }
  }

  void addLog(LogEvent e) {
    _log(e);
    notifyListeners();
  }

  // ── Cleanup ────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _zonesSub?.cancel();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  int _counter = 0;
  String _uid_() => '${DateTime.now().millisecondsSinceEpoch}_${_counter++}';
}