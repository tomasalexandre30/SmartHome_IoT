import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Thresholds _t = const Thresholds();
  bool _autoLed = true, _autoBuzzer = true, _saved = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _t = Thresholds(
        tempMax: p.getDouble('tempMax') ?? 28.0,
        tempMin: p.getDouble('tempMin') ?? 16.0,
        humidityMax: p.getDouble('humMax') ?? 70.0,
        luminosityAutoOn: p.getInt('luxAutoOn') ?? 300,
      );
      _autoLed    = p.getBool('autoLed')    ?? true;
      _autoBuzzer = p.getBool('autoBuzzer') ?? true;
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('tempMax', _t.tempMax);
    await p.setDouble('tempMin', _t.tempMin);
    await p.setDouble('humMax',  _t.humidityMax);
    await p.setInt('luxAutoOn',  _t.luminosityAutoOn);
    await p.setBool('autoLed',   _autoLed);
    await p.setBool('autoBuzzer',_autoBuzzer);
    setState(() => _saved = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _saved = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Definições'),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.border)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _saved
                  ? Container(
                  key: const ValueKey('saved'),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.greenDim,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_rounded, color: AppColors.green, size: 14),
                    const SizedBox(width: 4),
                    Text('Guardado', style: GoogleFonts.inter(
                        color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]))
                  : TextButton(
                  key: const ValueKey('save'),
                  onPressed: _save,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.indigo,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text('Guardar', style: GoogleFonts.inter(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          _GroupLabel(text: 'Automação'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: [
              _ToggleRow(
                icon: Icons.lightbulb_rounded,
                iconColor: AppColors.indigo,
                title: 'LED automático',
                subtitle: 'Liga quando luminosidade baixa',
                value: _autoLed,
                onChanged: (v) => setState(() => _autoLed = v),
              ),
              const Divider(height: 1),
              _ToggleRow(
                icon: Icons.volume_up_rounded,
                iconColor: AppColors.amber,
                title: 'Buzzer automático',
                subtitle: 'Alerta quando temperatura sobe',
                value: _autoBuzzer,
                onChanged: (v) => setState(() => _autoBuzzer = v),
              ),
            ]),
          ),

          const SizedBox(height: 24),
          _GroupLabel(text: 'Temperatura (°C)'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: [
              _SliderRow(label: 'Máximo', value: _t.tempMax, min: 20, max: 40,
                  color: AppColors.rose, unit: '°C',
                  onChanged: (v) => setState(() => _t = _t.copyWith(tempMax: v))),
              const Divider(height: 1),
              _SliderRow(label: 'Mínimo', value: _t.tempMin, min: 5, max: 22,
                  color: AppColors.teal, unit: '°C',
                  onChanged: (v) => setState(() => _t = _t.copyWith(tempMin: v))),
            ]),
          ),

          const SizedBox(height: 24),
          _GroupLabel(text: 'Humidade (%)'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: _SliderRow(label: 'Máximo', value: _t.humidityMax, min: 40, max: 95,
                color: AppColors.teal, unit: '%',
                onChanged: (v) => setState(() => _t = _t.copyWith(humidityMax: v))),
          ),

          const SizedBox(height: 24),
          _GroupLabel(text: 'Luminosidade'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: _SliderRow(label: 'LED liga abaixo de', value: _t.luminosityAutoOn.toDouble(),
                min: 50, max: 900, color: AppColors.amber, unit: '',
                onChanged: (v) => setState(() => _t = _t.copyWith(luminosityAutoOn: v.round()))),
          ),

          const SizedBox(height: 28),
          _GroupLabel(text: 'Payload MQTT'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 6, height: 6,
                    decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('home/config', style: AppText.label),
              ]),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text([
                  '"tempMax": ${_t.tempMax}',
                  '"tempMin": ${_t.tempMin}',
                  '"humMax": ${_t.humidityMax}',
                  '"luxAutoOn": ${_t.luminosityAutoOn}',
                  '"autoLed": $_autoLed',
                  '"autoBuzzer": $_autoBuzzer',
                ].join('\n'),
                    style: GoogleFonts.jetBrainsMono(
                        color: AppColors.textSecondary, fontSize: 12, height: 1.8)),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel({required this.text});
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: AppText.label);
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.icon, required this.iconColor, required this.title,
    required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: AppText.title),
        Text(subtitle, style: AppText.body),
      ])),
      Switch(value: value, onChanged: onChanged),
    ]),
  );
}

class _SliderRow extends StatelessWidget {
  final String label, unit;
  final double value, min, max;
  final Color color;
  final ValueChanged<double> onChanged;
  const _SliderRow({required this.label, required this.value, required this.min,
    required this.max, required this.color, required this.unit, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
    child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: AppText.title),
        Text(
            '${value % 1 == 0 ? value.toInt() : value.toStringAsFixed(1)}$unit',
            style: GoogleFonts.inter(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
      ]),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
            activeTrackColor: color, thumbColor: color,
            overlayColor: color.withOpacity(0.12)),
        child: Slider(
          value: value.clamp(min, max), min: min, max: max,
          divisions: ((max - min)).round(),
          onChanged: onChanged,
        ),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('${min.toInt()}$unit', style: AppText.body),
        Text('${max.toInt()}$unit', style: AppText.body),
      ]),
    ]),
  );
}