import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

// ───────────────────────────────────────────
// ECRÃ DE DEFINIÇÕES
// Guarda os thresholds em SharedPreferences
// O ESP32 receberá os thresholds via MQTT
// topic: home/config
// ───────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Thresholds _thresholds = const Thresholds();
  bool _autoLed = true;
  bool _autoBuzzer = true;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _thresholds = Thresholds(
        tempMax:          prefs.getDouble('tempMax')          ?? 28.0,
        tempMin:          prefs.getDouble('tempMin')          ?? 16.0,
        humidityMax:      prefs.getDouble('humMax')           ?? 70.0,
        luminosityAutoOn: prefs.getInt('luxAutoOn')           ?? 300,
      );
      _autoLed    = prefs.getBool('autoLed')    ?? true;
      _autoBuzzer = prefs.getBool('autoBuzzer') ?? true;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('tempMax',   _thresholds.tempMax);
    await prefs.setDouble('tempMin',   _thresholds.tempMin);
    await prefs.setDouble('humMax',    _thresholds.humidityMax);
    await prefs.setInt('luxAutoOn',    _thresholds.luminosityAutoOn);
    await prefs.setBool('autoLed',     _autoLed);
    await prefs.setBool('autoBuzzer',  _autoBuzzer);

    // TODO: publicar no MQTT quando tiveres o ESP32
    // mqttService.publish('home/config', jsonEncode({...}));

    setState(() => _saved = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _saved = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Definições'),
        actions: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _saved
                ? const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(Icons.check_rounded, color: AppColors.green, size: 20),
            )
                : TextButton(
              onPressed: _savePrefs,
              child: Text(
                'Guardar',
                style: GoogleFonts.dmSans(color: AppColors.green, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [

          // ─── AUTOMAÇÃO ─────────────────
          _SectionTitle(title: 'Automação', icon: Icons.auto_fix_high_rounded),
          const SizedBox(height: 10),
          _ToggleCard(
            title: 'LED automático',
            subtitle: 'Liga quando luminosidade baixa',
            icon: Icons.lightbulb_rounded,
            color: AppColors.green,
            value: _autoLed,
            onChanged: (v) => setState(() => _autoLed = v),
          ),
          const SizedBox(height: 10),
          _ToggleCard(
            title: 'Buzzer automático',
            subtitle: 'Alerta quando temperatura sobe',
            icon: Icons.volume_up_rounded,
            color: AppColors.orange,
            value: _autoBuzzer,
            onChanged: (v) => setState(() => _autoBuzzer = v),
          ),

          const SizedBox(height: 28),

          // ─── TEMPERATURA ───────────────
          _SectionTitle(title: 'Temperatura (°C)', icon: Icons.thermostat_rounded),
          const SizedBox(height: 10),
          _RangeCard(
            label: 'Máximo — buzzer ativa',
            value: _thresholds.tempMax,
            min: 20,
            max: 40,
            step: 0.5,
            unit: '°C',
            color: AppColors.red,
            onChanged: (v) => setState(() => _thresholds = _thresholds.copyWith(tempMax: v)),
          ),
          const SizedBox(height: 10),
          _RangeCard(
            label: 'Mínimo — alerta de frio',
            value: _thresholds.tempMin,
            min: 5,
            max: 22,
            step: 0.5,
            unit: '°C',
            color: AppColors.green,
            onChanged: (v) => setState(() => _thresholds = _thresholds.copyWith(tempMin: v)),
          ),

          const SizedBox(height: 28),

          // ─── HUMIDADE ──────────────────
          _SectionTitle(title: 'Humidade (%)', icon: Icons.water_drop_rounded),
          const SizedBox(height: 10),
          _RangeCard(
            label: 'Máximo — alerta de humidade',
            value: _thresholds.humidityMax,
            min: 40,
            max: 95,
            step: 1,
            unit: '%',
            color: AppColors.green,
            onChanged: (v) => setState(() => _thresholds = _thresholds.copyWith(humidityMax: v)),
          ),

          const SizedBox(height: 28),

          // ─── LUMINOSIDADE ──────────────
          _SectionTitle(title: 'Luminosidade', icon: Icons.light_mode_rounded),
          const SizedBox(height: 10),
          _RangeCard(
            label: 'Abaixo deste valor → LED liga',
            value: _thresholds.luminosityAutoOn.toDouble(),
            min: 50,
            max: 900,
            step: 10,
            unit: '',
            color: AppColors.orange,
            onChanged: (v) => setState(() => _thresholds = _thresholds.copyWith(luminosityAutoOn: v.round())),
          ),

          const SizedBox(height: 32),

          // ─── PAYLOAD MQTT PREVIEW ──────
          _MqttPreview(thresholds: _thresholds, autoLed: _autoLed, autoBuzzer: _autoBuzzer),
        ],
      ),
    );
  }
}

// ─── TOGGLE CARD ──────────────────────────────
class _ToggleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value ? color.withOpacity(0.25) : AppColors.border,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: value ? color : AppColors.textMuted, size: 20),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.title),
              Text(subtitle, style: AppText.body),
            ],
          ),
          const Spacer(),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ─── RANGE CARD COM SLIDER ────────────────────
class _RangeCard extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final String unit;
  final Color color;
  final ValueChanged<double> onChanged;

  const _RangeCard({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.unit,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppText.body),
              Text(
                '${value % 1 == 0 ? value.toInt() : value.toStringAsFixed(1)}$unit',
                style: GoogleFonts.jetBrainsMono(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              thumbColor: color,
              overlayColor: color.withOpacity(0.15),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: ((max - min) / step).round(),
              onChanged: onChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${min.toInt()}$unit', style: AppText.label),
              Text('${max.toInt()}$unit', style: AppText.label),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── PREVIEW MQTT ─────────────────────────────
class _MqttPreview extends StatelessWidget {
  final Thresholds thresholds;
  final bool autoLed;
  final bool autoBuzzer;

  const _MqttPreview({required this.thresholds, required this.autoLed, required this.autoBuzzer});

  @override
  Widget build(BuildContext context) {
    final lines = [
      '"tempMax": ${thresholds.tempMax}',
      '"tempMin": ${thresholds.tempMin}',
      '"humMax": ${thresholds.humidityMax}',
      '"luxAutoOn": ${thresholds.luminosityAutoOn}',
      '"autoLed": $autoLed',
      '"autoBuzzer": $autoBuzzer',
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.send_rounded, color: AppColors.textSecondary, size: 12),
              const SizedBox(width: 6),
              Text('MQTT → home/config', style: AppText.label),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            lines.join('\n'),
            style: GoogleFonts.jetBrainsMono(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── TÍTULO DE SECÇÃO ─────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(title.toUpperCase(), style: AppText.label),
      ],
    );
  }
}