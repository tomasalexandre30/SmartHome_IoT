import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});
  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  ActuatorState _state = const ActuatorState();

  void _send(ActuatorState s) {
    setState(() => _state = s);
    debugPrint('MQTT: ${s.toJson()}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Controlo'),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.border)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          _LedCard(state: _state, onChanged: _send),
          const SizedBox(height: 16),
          _BuzzerCard(state: _state, onChanged: _send),
          const SizedBox(height: 24),
          Text('MODOS RÁPIDOS', style: AppText.label),
          const SizedBox(height: 12),
          _QuickModes(onSelect: _send),
          const SizedBox(height: 24),
          _PayloadCard(state: _state),
        ],
      ),
    );
  }
}

class _LedCard extends StatelessWidget {
  final ActuatorState state;
  final ValueChanged<ActuatorState> onChanged;
  const _LedCard({required this.state, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: state.ledOn ? AppColors.indigo.withOpacity(0.3) : AppColors.border),
      ),
      child: Column(children: [
        // Header toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: state.ledOn ? AppColors.indigo : AppColors.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.lightbulb_rounded,
                  color: state.ledOn ? Colors.white : AppColors.textSecondary, size: 20),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('LED RGB', style: AppText.title),
              Text(state.ledOn ? 'Ligado' : 'Desligado', style: AppText.body),
            ]),
            const Spacer(),
            Switch(value: state.ledOn, onChanged: (v) => onChanged(state.copyWith(ledOn: v))),
          ]),
        ),

        if (state.ledOn) ...[
          Container(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Brilho
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('BRILHO', style: AppText.label),
                Text('${(state.ledBrightness * 100).round()}%',
                    style: GoogleFonts.inter(color: AppColors.indigo, fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 4),
              Slider(value: state.ledBrightness, min: 0.05, max: 1.0,
                  onChanged: (v) => onChanged(state.copyWith(ledBrightness: v))),
              const SizedBox(height: 16),

              // Cor
              Text('COR', style: AppText.label),
              const SizedBox(height: 10),
              Row(children: LedColor.values.map((c) {
                final sel = state.ledColor == c;
                return Expanded(child: GestureDetector(
                  onTap: () => onChanged(state.copyWith(ledColor: c)),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.indigoLight : AppColors.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? AppColors.indigo : AppColors.border,
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    child: Column(children: [
                      Container(width: 16, height: 16,
                          decoration: BoxDecoration(
                            color: _col(c), shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                          )),
                      const SizedBox(height: 5),
                      Text(c.displayName, style: GoogleFonts.inter(
                          color: sel ? AppColors.indigo : AppColors.textSecondary,
                          fontSize: 10, fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
                    ]),
                  ),
                ));
              }).toList()),
            ]),
          ),
        ],
      ]),
    );
  }

  Color _col(LedColor c) {
    switch (c) {
      case LedColor.white:  return const Color(0xFFF9FAFB);
      case LedColor.warm:   return const Color(0xFFFCD34D);
      case LedColor.cyan:   return const Color(0xFF67E8F9);
      case LedColor.orange: return const Color(0xFFFB923C);
    }
  }
}

class _BuzzerCard extends StatelessWidget {
  final ActuatorState state;
  final ValueChanged<ActuatorState> onChanged;
  const _BuzzerCard({required this.state, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: state.buzzerOn ? AppColors.amber.withOpacity(0.4) : AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: state.buzzerOn ? AppColors.amberDim : AppColors.bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(state.buzzerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: state.buzzerOn ? AppColors.amber : AppColors.textSecondary, size: 20),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Buzzer', style: AppText.title),
          Text(state.buzzerOn ? 'A tocar' : 'Silencioso', style: AppText.body),
        ]),
        const Spacer(),
        Switch(
          value: state.buzzerOn,
          thumbColor: WidgetStateProperty.all(Colors.white),
          trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.amber : AppColors.border),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          onChanged: (v) => onChanged(state.copyWith(buzzerOn: v)),
        ),
      ]),
    );
  }
}

class _QuickModes extends StatelessWidget {
  final ValueChanged<ActuatorState> onSelect;
  const _QuickModes({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final modes = [
      ('Foco',     '💡', 'Branco intenso',
      const ActuatorState(ledOn: true, ledBrightness: 1.0, ledColor: LedColor.white)),
      ('Noturno',  '🌙', 'Quente e suave',
      const ActuatorState(ledOn: true, ledBrightness: 0.2, ledColor: LedColor.warm)),
      ('Alerta',   '🔔', 'LED + buzzer',
      const ActuatorState(ledOn: true, ledBrightness: 1.0, ledColor: LedColor.orange, buzzerOn: true)),
      ('Desligar', '⏹', 'Tudo off',
      const ActuatorState()),
    ];
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.0,
      children: modes.map((m) => GestureDetector(
        onTap: () => onSelect(m.$4),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            Text(m.$1 == 'Desligar' ? '⏹' : m.$2, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(m.$1, style: AppText.title),
                Text(m.$3, style: AppText.body),
              ],
            )),
          ]),
        ),
      )).toList(),
    );
  }
}

class _PayloadCard extends StatelessWidget {
  final ActuatorState state;
  const _PayloadCard({required this.state});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('MQTT → home/sala/control', style: AppText.label),
        ]),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            state.toJson().entries.map((e) => '"${e.key}": ${e.value}').join('\n'),
            style: GoogleFonts.jetBrainsMono(color: AppColors.textSecondary, fontSize: 12, height: 1.8),
          ),
        ),
      ]),
    );
  }
}