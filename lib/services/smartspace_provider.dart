import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

class SmartSpaceProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────
  List<Zone> _zones = DefaultData.zones();
  List<Zone> get zones => _zones;

  final List<LogEvent> _logs = [];
  List<LogEvent> get logs => List.unmodifiable(_logs.reversed.toList());

  String? _currentZoneId;
  String? get currentZoneId => _currentZoneId;

  Zone? get currentZone =>
      _currentZoneId != null ? _zones.firstWhere((z) => z.id == _currentZoneId, orElse: () => _zones.first) : null;

  bool _isConnected = true;
  bool get isConnected => _isConnected;

  // Preferences per zone
  final Map<String, UserPreferences> _preferences = {};

  // ── Zone helpers ───────────────────────────────────────────────────────

  Zone? zoneById(String id) {
    try { return _zones.firstWhere((z) => z.id == id); } catch (_) { return null; }
  }

  void updateZoneFromBeacon(String? zoneId) {
    if (zoneId == _currentZoneId) return;

    final prev = _currentZoneId;
    _currentZoneId = zoneId;

    // Mark previous zone as free if we left
    if (prev != null) {
      _updateZone(prev, (z) => z.copyWith(
        status: ZoneStatus.free,
        occupantCount: (z.occupantCount - 1).clamp(0, 99),
        presentUsers: [...z.presentUsers]..remove('Eu'),
      ));
      _log(LogEvent(
        id: _uid(),
        type: LogEventType.zoneExit,
        zoneId: prev,
        message: 'Saiu da ${zoneById(prev)?.name ?? prev}',
      ));
    }

    // Mark new zone as occupied
    if (zoneId != null) {
      _updateZone(zoneId, (z) => z.copyWith(
        status: ZoneStatus.occupied,
        occupantCount: z.occupantCount + 1,
        presentUsers: [...z.presentUsers, 'Eu'],
      ));
      _log(LogEvent(
        id: _uid(),
        type: LogEventType.zoneEntry,
        zoneId: zoneId,
        message: 'Entrou na ${zoneById(zoneId)?.name ?? zoneId}',
      ));

      // Apply user preferences
      _applyPreferences(zoneId);
    }

    notifyListeners();
  }

  void _updateZone(String id, Zone Function(Zone) fn) {
    _zones = _zones.map((z) => z.id == id ? fn(z) : z).toList();
  }

  // ── Manual commands ────────────────────────────────────────────────────

  void toggleLight(String zoneId) {
    final z = zoneById(zoneId);
    if (z == null) return;
    _updateZone(zoneId, (z) => z.copyWith(lightOn: !z.lightOn));
    _log(LogEvent(
      id: _uid(),
      type: LogEventType.manualCommand,
      zoneId: zoneId,
      message: '${z.lightOn ? "Desligou" : "Ligou"} a luz na ${z.name}',
    ));
    notifyListeners();
  }

  void setLightIntensity(String zoneId, double value) {
    _updateZone(zoneId, (z) => z.copyWith(lightIntensity: value));
    notifyListeners();
  }

  void toggleBuzzer(String zoneId) {
    final z = zoneById(zoneId);
    if (z == null) return;
    _updateZone(zoneId, (z) => z.copyWith(buzzerOn: !z.buzzerOn));
    _log(LogEvent(
      id: _uid(),
      type: LogEventType.manualCommand,
      zoneId: zoneId,
      message: '${z.buzzerOn ? "Desligou" : "Ligou"} o buzzer na ${z.name}',
    ));
    notifyListeners();
  }

  // ── Mock sensor data (for demo without ESP32) ──────────────────────────

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
    _log(LogEvent(
      id: _uid(),
      type: LogEventType.automationTrigger,
      zoneId: zoneId,
      message: 'Automação: preferências aplicadas na ${zoneById(zoneId)?.name ?? zoneId}',
    ));
  }

  // ── Automation rules ───────────────────────────────────────────────────

  void checkAutomations(String zoneId) {
    final z = zoneById(zoneId);
    if (z == null) return;
    for (final rule in z.rules.where((r) => r.enabled)) {
      final sensorValue = _sensorValue(z, rule.sensorKey);
      if (sensorValue == null) continue;
      final triggered = _evaluate(sensorValue, rule.operator, rule.threshold);
      if (triggered) {
        _executeAction(zoneId, rule);
      }
    }
  }

  double? _sensorValue(Zone z, String key) {
    switch (key) {
      case 'luminosity':   return z.luminosity;
      case 'temperature':  return z.temperature;
      case 'humidity':     return z.humidity;
      case 'motion':       return z.motionDetected == true ? 1.0 : 0.0;
      default: return null;
    }
  }

  bool _evaluate(double value, String op, double threshold) {
    switch (op) {
      case '<':  return value < threshold;
      case '>':  return value > threshold;
      case '==': return (value - threshold).abs() < 0.01;
      default: return false;
    }
  }

  void _executeAction(String zoneId, AutomationRule rule) {
    switch (rule.action) {
      case 'light_on':
        _updateZone(zoneId, (z) => z.copyWith(lightOn: true));
        break;
      case 'light_off':
        _updateZone(zoneId, (z) => z.copyWith(lightOn: false));
        break;
      case 'buzzer':
        _updateZone(zoneId, (z) => z.copyWith(buzzerOn: true));
        break;
    }
    _log(LogEvent(
      id: _uid(),
      type: LogEventType.automationTrigger,
      zoneId: zoneId,
      message: 'Automação: ${rule.label}',
    ));
    notifyListeners();
  }

  // ── Connection ─────────────────────────────────────────────────────────

  void setConnected(bool v) {
    if (_isConnected == v) return;
    _isConnected = v;
    _log(LogEvent(
      id: _uid(),
      type: v ? LogEventType.connectionRestored : LogEventType.connectionLost,
      zoneId: '',
      message: v ? 'Ligação restabelecida' : 'Ligação ao servidor perdida — modo autónomo',
    ));
    notifyListeners();
  }

  // ── Log ────────────────────────────────────────────────────────────────

  void _log(LogEvent e) {
    _logs.add(e);
    if (_logs.length > 200) _logs.removeAt(0);
  }

  void addLog(LogEvent e) {
    _log(e);
    notifyListeners();
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  int _counter = 0;
  String _uid() => '${DateTime.now().millisecondsSinceEpoch}_${_counter++}';
}
