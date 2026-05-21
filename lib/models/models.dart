import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum ZoneStatus { free, occupied, unknown }

enum LogEventType {
  userRegister, userLogin, userLogout,
  zoneEntry, zoneExit, beaconDetected,
  manualCommand, automationTrigger,
  connectionLost, connectionRestored, alert,
}

enum LogCategory { auth, zones, commands, system }

// ── LightMode — GLOBAL por zona ───────────────────────────────────────────────
enum LightMode {
  auto,    // LDR ajusta intensidade, cor das preferências blended
  manual,  // controlo manual, LDR pausa
}

// ── LightSettings — resultado final enviado ao ESP32 ─────────────────────────
class LightSettings {
  final bool on;
  final double intensity;
  final int r, g, b;

  const LightSettings({
    required this.on, required this.intensity,
    required this.r, required this.g, required this.b,
  });

  const LightSettings.off()
      : on = false, intensity = 0.0, r = 255, g = 255, b = 255;

  @override
  bool operator ==(Object other) =>
      other is LightSettings &&
          on == other.on && intensity == other.intensity &&
          r == other.r && g == other.g && b == other.b;

  @override
  int get hashCode => Object.hash(on, intensity, r, g, b);
}

// ── ZonePoll — votação para qualquer ação ─────────────────────────────────────
// Guardado em: smartspace/zones/{zoneId}/activePoll/
class ZonePoll {
  final String requestedBy;
  final String requestedByName;
  final String action;
  final DateTime expiresAt;
  final Map<String, bool> votes;

  final double? intensity;
  final int? r, g, b;
  final bool? lightState;

  final Map<String, double> counterProposals;
  final Map<String, List<int>> colorCounterProposals;

  const ZonePoll({
    required this.requestedBy,
    required this.requestedByName,
    required this.action,
    required this.expiresAt,
    required this.votes,
    this.intensity,
    this.r, this.g, this.b,
    this.lightState,
    Map<String, double>? counterProposals,
    Map<String, List<int>>? colorCounterProposals,
  })  : counterProposals = counterProposals ?? const {},
        colorCounterProposals = colorCounterProposals ?? const {};

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  int get yesVotes => votes.values.where((v) => v).length;
  int get noVotes  => votes.values.where((v) => !v).length;
  int get total    => votes.length;

  ZonePoll copyWith({
    Map<String, bool>? votes,
    Map<String, double>? counterProposals,
    Map<String, List<int>>? colorCounterProposals,
  }) => ZonePoll(
    requestedBy: requestedBy,
    requestedByName: requestedByName,
    action: action,
    expiresAt: expiresAt,
    votes: votes ?? this.votes,
    intensity: intensity,
    r: r, g: g, b: b,
    lightState: lightState,
    counterProposals: counterProposals ?? this.counterProposals,
    colorCounterProposals: colorCounterProposals ?? this.colorCounterProposals,
  );

  Map<String, dynamic> toJson() => {
    'requestedBy': requestedBy,
    'requestedByName': requestedByName,
    'action': action,
    'expiresAt': expiresAt.millisecondsSinceEpoch,
    'votes': votes,
    if (intensity != null) 'intensity': intensity,
    if (r != null) 'r': r,
    if (g != null) 'g': g,
    if (b != null) 'b': b,
    if (lightState != null) 'lightState': lightState,
    if (counterProposals.isNotEmpty) 'counterProposals': counterProposals,
    if (colorCounterProposals.isNotEmpty)
      'colorCounterProposals': colorCounterProposals.map((k, v) => MapEntry(k, v)),
  };

  factory ZonePoll.fromJson(Map<String, dynamic> j) {
    Map<String, double> cp = {};
    if (j['counterProposals'] != null) {
      cp = Map<String, double>.from(
          (j['counterProposals'] as Map).map((k, v) =>
              MapEntry(k.toString(), (v as num).toDouble())));
    }
    Map<String, List<int>> ccp = {};
    if (j['colorCounterProposals'] != null) {
      ccp = Map<String, List<int>>.from(
          (j['colorCounterProposals'] as Map).map((k, v) =>
              MapEntry(k.toString(), List<int>.from(v as List))));
    }
    return ZonePoll(
      requestedBy: j['requestedBy'] as String,
      requestedByName: j['requestedByName'] as String? ?? '',
      action: j['action'] as String,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(j['expiresAt'] as int),
      votes: j['votes'] != null
          ? Map<String, bool>.from(
          (j['votes'] as Map).map((k, v) => MapEntry(k.toString(), v as bool)))
          : {},
      intensity: (j['intensity'] as num?)?.toDouble(),
      r: j['r'] as int?,
      g: j['g'] as int?,
      b: j['b'] as int?,
      lightState: j['lightState'] as bool?,
      counterProposals: cp,
      colorCounterProposals: ccp,
    );
  }
}

extension LogEventTypeExtension on LogEventType {
  LogCategory get category {
    switch (this) {
      case LogEventType.userRegister:
      case LogEventType.userLogin:
      case LogEventType.userLogout:
        return LogCategory.auth;
      case LogEventType.zoneEntry:
      case LogEventType.zoneExit:
      case LogEventType.beaconDetected:
        return LogCategory.zones;
      case LogEventType.manualCommand:
      case LogEventType.automationTrigger:
        return LogCategory.commands;
      case LogEventType.connectionLost:
      case LogEventType.connectionRestored:
      case LogEventType.alert:
        return LogCategory.system;
    }
  }

  String get categoryLabel {
    switch (category) {
      case LogCategory.auth:     return 'Autenticação';
      case LogCategory.zones:    return 'Zonas';
      case LogCategory.commands: return 'Comandos';
      case LogCategory.system:   return 'Sistema';
    }
  }

  Color get categoryColor {
    switch (category) {
      case LogCategory.auth:     return const Color(0xFF8B5CF6);
      case LogCategory.zones:    return AppTheme.success;
      case LogCategory.commands: return AppTheme.accent;
      case LogCategory.system:   return AppTheme.warning;
    }
  }
}

class Beacon {
  final String uuid, mac, name, zoneId;
  int rssi;
  double distance;
  DateTime lastSeen;

  Beacon({
    required this.uuid, required this.mac,
    required this.name, required this.zoneId,
    this.rssi = -100, this.distance = 99.0, DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  bool get isNearby =>
      rssi > -80 && DateTime.now().difference(lastSeen).inSeconds < 10;

  String get signalBar {
    if (rssi > -60) return '▂▄▆█';
    if (rssi > -70) return '▂▄▆░';
    if (rssi > -80) return '▂▄░░';
    return '▂░░░';
  }

  Color get signalColor {
    if (rssi > -60) return AppTheme.success;
    if (rssi > -70) return AppTheme.warning;
    if (rssi > -80) return Colors.orange;
    return AppTheme.error;
  }

  Beacon copyWith({int? rssi, double? distance, DateTime? lastSeen}) => Beacon(
    uuid: uuid, mac: mac, name: name, zoneId: zoneId,
    rssi: rssi ?? this.rssi,
    distance: distance ?? this.distance,
    lastSeen: lastSeen ?? this.lastSeen,
  );
}

class UserPreferences {
  final String zoneId;
  double lightIntensity;
  Color lightColor;
  double temperatureTarget;
  bool doNotDisturb;
  bool enabled;

  UserPreferences({
    required this.zoneId,
    this.lightIntensity = 0.8,
    this.lightColor = const Color(0xFFFFFFFF),
    this.temperatureTarget = 22.0,
    this.doNotDisturb = false,
    this.enabled = true,
  });

  UserPreferences copyWith({
    double? lightIntensity, Color? lightColor,
    double? temperatureTarget, bool? doNotDisturb, bool? enabled,
  }) => UserPreferences(
    zoneId: zoneId,
    lightIntensity: lightIntensity ?? this.lightIntensity,
    lightColor: lightColor ?? this.lightColor,
    temperatureTarget: temperatureTarget ?? this.temperatureTarget,
    doNotDisturb: doNotDisturb ?? this.doNotDisturb,
    enabled: enabled ?? this.enabled,
  );

  Map<String, dynamic> toJson() => {
    'zoneId': zoneId, 'lightIntensity': lightIntensity,
    'lightColorValue': lightColor.value, 'temperatureTarget': temperatureTarget,
    'doNotDisturb': doNotDisturb, 'enabled': enabled,
  };

  factory UserPreferences.fromJson(Map<String, dynamic> j) => UserPreferences(
    zoneId: j['zoneId'] as String,
    lightIntensity: (j['lightIntensity'] as num).toDouble(),
    lightColor: Color(j['lightColorValue'] as int),
    temperatureTarget: (j['temperatureTarget'] as num).toDouble(),
    doNotDisturb: j['doNotDisturb'] as bool,
    enabled: j['enabled'] as bool? ?? true,
  );
}

// ── ZoneAutomations ───────────────────────────────────────────────────────────
class ZoneAutomations {
  final double ldrThreshold, tempThreshold, humThreshold;
  final bool autoLightEnabled, autoTempEnabled, autoHumEnabled;

  const ZoneAutomations({
    this.ldrThreshold = 20.0, this.tempThreshold = 28.0, this.humThreshold = 90.0,
    this.autoLightEnabled = true, this.autoTempEnabled = true, this.autoHumEnabled = true,
  });

  ZoneAutomations copyWith({
    double? ldrThreshold, double? tempThreshold, double? humThreshold,
    bool? autoLightEnabled, bool? autoTempEnabled, bool? autoHumEnabled,
  }) => ZoneAutomations(
    ldrThreshold: ldrThreshold ?? this.ldrThreshold,
    tempThreshold: tempThreshold ?? this.tempThreshold,
    humThreshold: humThreshold ?? this.humThreshold,
    autoLightEnabled: autoLightEnabled ?? this.autoLightEnabled,
    autoTempEnabled: autoTempEnabled ?? this.autoTempEnabled,
    autoHumEnabled: autoHumEnabled ?? this.autoHumEnabled,
  );

  Map<String, dynamic> toJson() => {
    'ldrThreshold': ldrThreshold, 'tempThreshold': tempThreshold,
    'humThreshold': humThreshold, 'autoLightEnabled': autoLightEnabled,
    'autoTempEnabled': autoTempEnabled, 'autoHumEnabled': autoHumEnabled,
  };

  factory ZoneAutomations.fromJson(Map<String, dynamic> j) => ZoneAutomations(
    ldrThreshold:  (j['ldrThreshold']  as num?)?.toDouble() ?? 20.0,
    tempThreshold: (j['tempThreshold'] as num?)?.toDouble() ?? 28.0,
    humThreshold:  (j['humThreshold']  as num?)?.toDouble() ?? 90.0,
    autoLightEnabled: j['autoLightEnabled'] as bool? ?? true,
    autoTempEnabled:  j['autoTempEnabled']  as bool? ?? true,
    autoHumEnabled:   j['autoHumEnabled']   as bool? ?? true,
  );
}

class AutomationRule {
  final String id, zoneId, label, sensorKey, operator, action;
  final double threshold;
  bool enabled;

  AutomationRule({
    required this.id, required this.zoneId, required this.label,
    required this.sensorKey, required this.operator,
    required this.threshold, required this.action, this.enabled = true,
  });
}

// ── Zone ──────────────────────────────────────────────────────────────────────
class Zone {
  final String id, name, beaconUuid;
  final Color color;
  final IconData icon;

  ZoneStatus status;
  int occupantCount;
  List<String> presentUsers;

  double? luminosity, temperature, humidity;
  bool? motionDetected;

  bool lightOn;
  double lightIntensity;
  int lightR, lightG, lightB;
  bool buzzerOn;

  List<AutomationRule> rules;
  ZoneAutomations automations;
  double energyUsageWh;
  DateTime lastUpdated;
  bool esp32Online;

  LightMode lightMode;
  bool absoluteLocked;
  String? absoluteLockedBy;
  ZonePoll? activePoll;

  Zone({
    required this.id, required this.name, required this.beaconUuid,
    required this.color, required this.icon,
    this.status = ZoneStatus.unknown,
    this.occupantCount = 0,
    List<String>? presentUsers,
    this.luminosity, this.temperature, this.humidity, this.motionDetected,
    this.lightOn = false, this.lightIntensity = 1.0,
    this.lightR = 255, this.lightG = 255, this.lightB = 255,
    this.buzzerOn = false,
    List<AutomationRule>? rules,
    ZoneAutomations? automations,
    this.energyUsageWh = 0,
    DateTime? lastUpdated,
    this.esp32Online = false,
    this.lightMode = LightMode.auto,
    this.absoluteLocked = false,
    this.absoluteLockedBy,
    this.activePoll,
  })  : presentUsers = presentUsers ?? [],
        rules = rules ?? [],
        automations = automations ?? const ZoneAutomations(),
        lastUpdated = lastUpdated ?? DateTime.now();

  bool get isOccupied => status == ZoneStatus.occupied;
  bool get isAbsoluteLocked => absoluteLocked;
  Color get lightColor => Color.fromRGBO(lightR, lightG, lightB, 1.0);

  String get statusLabel {
    switch (status) {
      case ZoneStatus.free:     return 'Livre';
      case ZoneStatus.occupied: return 'Ocupada';
      case ZoneStatus.unknown:  return 'Desconhecida';
    }
  }

  Color get statusColor {
    switch (status) {
      case ZoneStatus.free:     return AppTheme.success;
      case ZoneStatus.occupied: return AppTheme.error;
      case ZoneStatus.unknown:  return AppTheme.textMuted;
    }
  }

  // ── BUG FIX: copyWith usa _Sentinel para distinguir null explícito de "não passado"
  // O padrão anterior (activePoll ?? this.activePoll) tornava impossível limpar
  // a poll passando null — usava sempre o valor antigo.
  // Agora: passar activePoll: null limpa explicitamente. clearPoll continua a funcionar.
  Zone copyWith({
    ZoneStatus? status, int? occupantCount, List<String>? presentUsers,
    double? luminosity, double? temperature, double? humidity, bool? motionDetected,
    bool? lightOn, double? lightIntensity,
    int? lightR, int? lightG, int? lightB,
    bool? buzzerOn, ZoneAutomations? automations,
    double? energyUsageWh, bool? esp32Online,
    LightMode? lightMode, bool? absoluteLocked,
    String? absoluteLockedBy,
    Object? activePoll = _sentinel,   // <-- usa sentinel, não ZonePoll?
    bool clearPoll = false,
    bool clearAbsolute = false,
  }) => Zone(
    id: id, name: name, beaconUuid: beaconUuid, color: color, icon: icon,
    status: status ?? this.status,
    occupantCount: occupantCount ?? this.occupantCount,
    presentUsers: presentUsers ?? this.presentUsers,
    luminosity: luminosity ?? this.luminosity,
    temperature: temperature ?? this.temperature,
    humidity: humidity ?? this.humidity,
    motionDetected: motionDetected ?? this.motionDetected,
    lightOn: lightOn ?? this.lightOn,
    lightIntensity: lightIntensity ?? this.lightIntensity,
    lightR: lightR ?? this.lightR,
    lightG: lightG ?? this.lightG,
    lightB: lightB ?? this.lightB,
    buzzerOn: buzzerOn ?? this.buzzerOn,
    rules: rules,
    automations: automations ?? this.automations,
    energyUsageWh: energyUsageWh ?? this.energyUsageWh,
    lastUpdated: DateTime.now(),
    esp32Online: esp32Online ?? this.esp32Online,
    lightMode: lightMode ?? this.lightMode,
    absoluteLocked: absoluteLocked ?? this.absoluteLocked,
    absoluteLockedBy: clearAbsolute ? null : (absoluteLockedBy ?? this.absoluteLockedBy),
    // clearPoll=true → null
    // activePoll passado explicitamente (incluindo null) → usa esse valor
    // nada passado (sentinel) → mantém o atual
    activePoll: clearPoll
        ? null
        : (activePoll == _sentinel
        ? this.activePoll
        : activePoll as ZonePoll?),
  );
}

// Sentinel para distinguir "não passou activePoll" de "passou null explicitamente"
const Object _sentinel = Object();

class LogEvent {
  final String id, zoneId, message, userName, userRole, uid;
  final LogEventType type;
  final DateTime timestamp;

  LogEvent({
    required this.id, required this.type, required this.zoneId,
    required this.message, this.userName = '', this.userRole = 'user',
    this.uid = '', DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isAdmin => userRole == 'admin';
  bool get isSystem => userRole == 'system';
  LogCategory get category => type.category;

  IconData get icon {
    switch (type) {
      case LogEventType.userRegister:       return Icons.person_add_rounded;
      case LogEventType.userLogin:          return Icons.login_rounded;
      case LogEventType.userLogout:         return Icons.logout_rounded;
      case LogEventType.zoneEntry:          return Icons.door_front_door_rounded;
      case LogEventType.zoneExit:           return Icons.door_back_door_rounded;
      case LogEventType.beaconDetected:     return Icons.bluetooth_searching_rounded;
      case LogEventType.manualCommand:      return Icons.touch_app_rounded;
      case LogEventType.automationTrigger:  return Icons.auto_fix_high_rounded;
      case LogEventType.connectionLost:     return Icons.wifi_off_rounded;
      case LogEventType.connectionRestored: return Icons.wifi_rounded;
      case LogEventType.alert:              return Icons.warning_amber_rounded;
    }
  }

  Color get color {
    switch (type) {
      case LogEventType.userRegister:       return const Color(0xFF8B5CF6);
      case LogEventType.userLogin:          return AppTheme.success;
      case LogEventType.userLogout:         return AppTheme.textSecondary;
      case LogEventType.zoneEntry:          return AppTheme.success;
      case LogEventType.zoneExit:           return AppTheme.textSecondary;
      case LogEventType.beaconDetected:     return AppTheme.accent;
      case LogEventType.manualCommand:      return AppTheme.accent;
      case LogEventType.automationTrigger:  return const Color(0xFF7C3AED);
      case LogEventType.connectionLost:     return AppTheme.error;
      case LogEventType.connectionRestored: return AppTheme.success;
      case LogEventType.alert:              return AppTheme.warning;
    }
  }
}

class DefaultData {
  static List<Zone> zones() => [
    Zone(id: 'zone_a', name: 'Sala',
        beaconUuid: 'FDA50693-A4E2-4FB1-AFCF-C6EB07647825',
        color: AppTheme.zoneColors[0], icon: Icons.weekend_rounded),
    Zone(id: 'zone_b', name: 'Quarto',
        beaconUuid: 'FDA50693-A4E2-4FB1-AFCF-C6EB07647826',
        color: AppTheme.zoneColors[1], icon: Icons.bed_rounded),
    Zone(id: 'zone_c', name: 'Escritório',
        beaconUuid: 'FDA50693-A4E2-4FB1-AFCF-C6EB07647827',
        color: AppTheme.zoneColors[2], icon: Icons.computer_rounded),
  ];

  static List<Beacon> beacons() => [
    Beacon(uuid: 'FDA50693-A4E2-4FB1-AFCF-C6EB07647825',
        mac: '51:00:24:12:01:CA', name: 'R24120458', zoneId: 'zone_a'),
    Beacon(uuid: 'FDA50693-A4E2-4FB1-AFCF-C6EB07647826',
        mac: '51:00:24:12:01:E3', name: 'R24120483', zoneId: 'zone_b'),
    Beacon(uuid: 'FDA50693-A4E2-4FB1-AFCF-C6EB07647827',
        mac: '51:00:24:12:01:B2', name: 'R24120434', zoneId: 'zone_c'),
  ];
}