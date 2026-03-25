// ───────────────────────────────────────────
// MODELOS DE DADOS
// ───────────────────────────────────────────

enum Room {
  unknown,
  sala,
  quarto,
  escritorio;

  String get displayName {
    switch (this) {
      case Room.sala:       return 'Sala';
      case Room.quarto:     return 'Quarto';
      case Room.escritorio: return 'Escritório';
      case Room.unknown:    return 'Sem sinal';
    }
  }

  String get emoji {
    switch (this) {
      case Room.sala:       return '🛋';
      case Room.quarto:     return '🛏';
      case Room.escritorio: return '💻';
      case Room.unknown:    return '—';
    }
  }

  // Major do beacon → Room (ajusta conforme a tua configuração)
  static Room fromMajor(int major) {
    switch (major) {
      case 1: return Room.sala;
      case 2: return Room.quarto;
      case 3: return Room.escritorio;
      default: return Room.unknown;
    }
  }
}

// ───────────────────────────────────────────
// DADOS DOS SENSORES (vindos do ESP32 via MQTT)
// Por enquanto estáticos — serão substituídos
// por valores reais quando tiveres o ESP32
// ───────────────────────────────────────────
class SensorData {
  final double temperature; // ºC
  final double humidity;    // %
  final int luminosity;     // 0-1023 (raw ADC do LDR)
  final DateTime timestamp;

  const SensorData({
    required this.temperature,
    required this.humidity,
    required this.luminosity,
    required this.timestamp,
  });

  // Converte luminosity raw para percentagem legível
  double get luminosityPercent => (luminosity / 1023 * 100).clamp(0, 100);

  // Dados estáticos de placeholder (substitui por MQTT mais tarde)
  static SensorData get placeholder => SensorData(
    temperature: 22.4,
    humidity: 58.0,
    luminosity: 312,
    timestamp: DateTime.now(),
  );

  // Parse do JSON que virá do ESP32 via MQTT
  // {"temp": 22.4, "hum": 58.0, "lux": 312}
  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      temperature: (json['temp'] as num).toDouble(),
      humidity: (json['hum'] as num).toDouble(),
      luminosity: (json['lux'] as num).toInt(),
      timestamp: DateTime.now(),
    );
  }
}

// ───────────────────────────────────────────
// ESTADO DOS ATUADORES
// ───────────────────────────────────────────
class ActuatorState {
  final bool ledOn;
  final double ledBrightness; // 0.0 - 1.0
  final LedColor ledColor;
  final bool buzzerOn;

  const ActuatorState({
    this.ledOn = false,
    this.ledBrightness = 1.0,
    this.ledColor = LedColor.white,
    this.buzzerOn = false,
  });

  ActuatorState copyWith({
    bool? ledOn,
    double? ledBrightness,
    LedColor? ledColor,
    bool? buzzerOn,
  }) {
    return ActuatorState(
      ledOn: ledOn ?? this.ledOn,
      ledBrightness: ledBrightness ?? this.ledBrightness,
      ledColor: ledColor ?? this.ledColor,
      buzzerOn: buzzerOn ?? this.buzzerOn,
    );
  }

  // JSON para enviar ao ESP32 via MQTT
  // topic: home/sala/control
  Map<String, dynamic> toJson() => {
    'led': ledOn,
    'brightness': (ledBrightness * 255).round(),
    'color': ledColor.name,
    'buzzer': buzzerOn,
  };
}

enum LedColor {
  white, warm, cyan, orange;

  String get displayName {
    switch (this) {
      case LedColor.white:  return 'Branco';
      case LedColor.warm:   return 'Quente';
      case LedColor.cyan:   return 'Ciano';
      case LedColor.orange: return 'Laranja';
    }
  }
}

// ───────────────────────────────────────────
// THRESHOLDS (guardados em SharedPreferences)
// ───────────────────────────────────────────
class Thresholds {
  final double tempMax;
  final double tempMin;
  final double humidityMax;
  final int luminosityAutoOn; // lux abaixo do qual o LED liga automaticamente

  const Thresholds({
    this.tempMax = 28.0,
    this.tempMin = 16.0,
    this.humidityMax = 70.0,
    this.luminosityAutoOn = 300,
  });

  Thresholds copyWith({
    double? tempMax,
    double? tempMin,
    double? humidityMax,
    int? luminosityAutoOn,
  }) {
    return Thresholds(
      tempMax: tempMax ?? this.tempMax,
      tempMin: tempMin ?? this.tempMin,
      humidityMax: humidityMax ?? this.humidityMax,
      luminosityAutoOn: luminosityAutoOn ?? this.luminosityAutoOn,
    );
  }
}

// ───────────────────────────────────────────
// PONTO DO HISTÓRICO (para os gráficos)
// ───────────────────────────────────────────
class HistoryPoint {
  final DateTime time;
  final double temperature;
  final double humidity;
  final double luminosityPercent;

  const HistoryPoint({
    required this.time,
    required this.temperature,
    required this.humidity,
    required this.luminosityPercent,
  });

  // Dados estáticos de exemplo para o histórico
  // Serão substituídos por dados reais do MQTT
  static List<HistoryPoint> get sampleData {
    final now = DateTime.now();
    return [
      HistoryPoint(time: now.subtract(const Duration(hours: 6)),  temperature: 20.1, humidity: 55, luminosityPercent: 80),
      HistoryPoint(time: now.subtract(const Duration(hours: 5)),  temperature: 21.3, humidity: 57, luminosityPercent: 75),
      HistoryPoint(time: now.subtract(const Duration(hours: 4)),  temperature: 22.8, humidity: 60, luminosityPercent: 65),
      HistoryPoint(time: now.subtract(const Duration(hours: 3)),  temperature: 23.4, humidity: 62, luminosityPercent: 50),
      HistoryPoint(time: now.subtract(const Duration(hours: 2)),  temperature: 24.1, humidity: 61, luminosityPercent: 40),
      HistoryPoint(time: now.subtract(const Duration(hours: 1)),  temperature: 23.6, humidity: 59, luminosityPercent: 35),
      HistoryPoint(time: now,                                       temperature: 22.4, humidity: 58, luminosityPercent: 30),
    ];
  }
}