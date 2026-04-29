import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum ZoneStatus { free, occupied, unknown }

enum LogEventType {
  zoneEntry,
  zoneExit,
  manualCommand,
  automationTrigger,
  connectionLost,
  connectionRestored,
  alert,
}

class Beacon {
  final String uuid;
  final String mac;
  final String name;
  final String zoneId;
  int rssi;
  double distance;
  DateTime lastSeen;

  Beacon({
    required this.uuid,
    required this.mac,
    required this.name,
    required this.zoneId,
    this.rssi = -100,
    this.distance = 99.0,
    DateTime? lastSeen,
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
    uuid: uuid,
    mac: mac,
    name: name,
    zoneId: zoneId,
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

  UserPreferences({
    required this.zoneId,
    this.lightIntensity = 0.8,
    this.lightColor = const Color(0xFFFFFFFF),
    this.temperatureTarget = 22.0,
    this.doNotDisturb = false,
  });

  UserPreferences copyWith({
    double? lightIntensity,
    Color? lightColor,
    double? temperatureTarget,
    bool? doNotDisturb,
  }) => UserPreferences(
    zoneId: zoneId,
    lightIntensity: lightIntensity ?? this.lightIntensity,
    lightColor: lightColor ?? this.lightColor,
    temperatureTarget: temperatureTarget ?? this.temperatureTarget,
    doNotDisturb: doNotDisturb ?? this.doNotDisturb,
  );

  Map<String, dynamic> toJson() => {
    'zoneId': zoneId,
    'lightIntensity': lightIntensity,
    'lightColorValue': lightColor.value,
    'temperatureTarget': temperatureTarget,
    'doNotDisturb': doNotDisturb,
  };

  factory UserPreferences.fromJson(Map<String, dynamic> j) => UserPreferences(
    zoneId: j['zoneId'] as String,
    lightIntensity: (j['lightIntensity'] as num).toDouble(),
    lightColor: Color(j['lightColorValue'] as int),
    temperatureTarget: (j['temperatureTarget'] as num).toDouble(),
    doNotDisturb: j['doNotDisturb'] as bool,
  );
}

class AutomationRule {
  final String id;
  final String zoneId;
  final String label;
  final String sensorKey;
  final String operator;
  final double threshold;
  final String action;
  bool enabled;

  AutomationRule({
    required this.id,
    required this.zoneId,
    required this.label,
    required this.sensorKey,
    required this.operator,
    required this.threshold,
    required this.action,
    this.enabled = true,
  });
}

class Zone {
  final String id;
  final String name;
  final String beaconUuid;
  final Color color;
  final IconData icon;

  ZoneStatus status;
  int occupantCount;
  List<String> presentUsers;

  double? luminosity;
  double? temperature;
  double? humidity;
  bool? motionDetected;

  bool lightOn;
  double lightIntensity;
  bool buzzerOn;

  List<AutomationRule> rules;
  double energyUsageWh;
  DateTime lastUpdated;

  Zone({
    required this.id,
    required this.name,
    required this.beaconUuid,
    required this.color,
    required this.icon,
    this.status = ZoneStatus.unknown,
    this.occupantCount = 0,
    List<String>? presentUsers,
    this.luminosity,
    this.temperature,
    this.humidity,
    this.motionDetected,
    this.lightOn = false,
    this.lightIntensity = 1.0,
    this.buzzerOn = false,
    List<AutomationRule>? rules,
    this.energyUsageWh = 0,
    DateTime? lastUpdated,
  })  : presentUsers = presentUsers ?? [],
        rules = rules ?? [],
        lastUpdated = lastUpdated ?? DateTime.now();

  bool get isOccupied => status == ZoneStatus.occupied;

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

  Zone copyWith({
    ZoneStatus? status,
    int? occupantCount,
    List<String>? presentUsers,
    double? luminosity,
    double? temperature,
    double? humidity,
    bool? motionDetected,
    bool? lightOn,
    double? lightIntensity,
    bool? buzzerOn,
    double? energyUsageWh,
  }) => Zone(
    id: id,
    name: name,
    beaconUuid: beaconUuid,
    color: color,
    icon: icon,
    status: status ?? this.status,
    occupantCount: occupantCount ?? this.occupantCount,
    presentUsers: presentUsers ?? this.presentUsers,
    luminosity: luminosity ?? this.luminosity,
    temperature: temperature ?? this.temperature,
    humidity: humidity ?? this.humidity,
    motionDetected: motionDetected ?? this.motionDetected,
    lightOn: lightOn ?? this.lightOn,
    lightIntensity: lightIntensity ?? this.lightIntensity,
    buzzerOn: buzzerOn ?? this.buzzerOn,
    rules: rules,
    energyUsageWh: energyUsageWh ?? this.energyUsageWh,
    lastUpdated: DateTime.now(),
  );
}

class LogEvent {
  final String id;
  final LogEventType type;
  final String zoneId;
  final String message;
  final DateTime timestamp;

  LogEvent({
    required this.id,
    required this.type,
    required this.zoneId,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  IconData get icon {
    switch (type) {
      case LogEventType.zoneEntry:          return Icons.login_rounded;
      case LogEventType.zoneExit:           return Icons.logout_rounded;
      case LogEventType.manualCommand:      return Icons.touch_app_rounded;
      case LogEventType.automationTrigger:  return Icons.auto_fix_high_rounded;
      case LogEventType.connectionLost:     return Icons.wifi_off_rounded;
      case LogEventType.connectionRestored: return Icons.wifi_rounded;
      case LogEventType.alert:              return Icons.warning_amber_rounded;
    }
  }

  Color get color {
    switch (type) {
      case LogEventType.zoneEntry:          return AppTheme.success;
      case LogEventType.zoneExit:           return AppTheme.textSecondary;
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
    Zone(
      id: 'zone_a',
      name: 'Sala',
      beaconUuid: 'FDA50693-A4E2-4FB1-AFCF-C6EB07647825',
      color: AppTheme.zoneColors[0],
      icon: Icons.weekend_rounded,
    ),
    Zone(
      id: 'zone_b',
      name: 'Quarto',
      beaconUuid: 'FDA50693-A4E2-4FB1-AFCF-C6EB07647825',
      color: AppTheme.zoneColors[1],
      icon: Icons.bed_rounded,
    ),
    Zone(
      id: 'zone_c',
      name: 'Escritório',
      beaconUuid: 'FDA50693-A4E2-4FB1-AFCF-C6EB07647825',
      color: AppTheme.zoneColors[2],
      icon: Icons.computer_rounded,
    ),
  ];

  static List<Beacon> beacons() => [
    Beacon(
      uuid: 'FDA50693-A4E2-4FB1-AFCF-C6EB07647825',
      mac: '51:00:24:12:01:CA',
      name: 'R24120458',
      zoneId: 'zone_a',
    ),
    Beacon(
      uuid: 'FDA50693-A4E2-4FB1-AFCF-C6EB07647825',
      mac: '51:00:24:12:01:E3',
      name: 'R24120483',
      zoneId: 'zone_b',
    ),
    Beacon(
      uuid: 'FDA50693-A4E2-4FB1-AFCF-C6EB07647825',
      mac: '51:00:24:12:01:B2',
      name: 'R241204XX',
      zoneId: 'zone_c',
    ),
  ];
}