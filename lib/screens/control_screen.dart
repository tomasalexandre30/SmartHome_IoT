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

  void _sendCommand(ActuatorState newState) {
    setState(() => _state = newState);
    debugPrint('Command: ${newState.toJson()}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Controlo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SectionHeader(title: 'LED RGB', icon: Icons.lightbulb_rounded),
          const SizedBox(height: 10),
          _LedCard(state: _state, onChanged: _sendCommand),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Buzzer', icon: Icons.volume_up_rounded),
          const SizedBox(height: 10),
          _BuzzerCard(state: _state, onChanged: _sendCommand),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Modos rápidos', icon: Icons.bolt_rounded),
          const SizedBox(height: 10),
          _QuickModes(onSelect: _sendCommand),
          const SizedBox(height: 24),
          _StatePreview(state: _state),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: state.ledOn ? AppColors.cyan.withOpacity(0.4) : AppColors.border,
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: state.ledOn ? AppColors.cyanDim : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.lightbulb_rounded,
                    color: state.ledOn ? AppColors.cyan : AppColors.textMuted, size: 20),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Energia', style: AppText.title),
                Text(state.ledOn ? 'Ligado' : 'Desligado', style: AppText.body),
              ]),
              const Spacer(),
              Switch(value: state.ledOn, onChanged: (v) => onChanged(state.copyWith(ledOn: v))),
            ],
          ),
          if (state.ledOn) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Brilho', style: AppText.label),
                Text('${(state.ledBrightness * 100).round()}%',
                    style: GoogleFonts.jetBrainsMono(color: AppColors.cyan, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            Slider(value: state.ledBrightness, min: 0.05, max: 1.0,
                onChanged: (v) => onChanged(state.copyWith(ledBrightness: v))),
            const SizedBox(height: 16),
            Text('Cor', style: AppText.label),
            const SizedBox(height: 10),
            Row(
              children: LedColor.values.map((color) {
                final isSelected = state.ledColor == color;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(state.copyWith(ledColor: color)),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.cyanDim : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.cyan : AppColors.border,
                          width: isSelected ? 1 : 0.5,
                        ),
                      ),
                      child: Column(children: [
                        Container(
                          width: 14, height: 14,
                          decoration: BoxDecoration(
                            color: _colorFor(color), shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border, width: 0.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(color.displayName,
                            style: GoogleFonts.dmSans(
                                color: isSelected ? AppColors.cyan : AppColors.textSecondary,
                                fontSize: 11, fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Color _colorFor(LedColor c) {
    switch (c) {
      case LedColor.white:  return Colors.white;
      case LedColor.warm:   return const Color(0xFFFFD580);
      case LedColor.cyan:   return const Color(0xFF4DD9E0);
      case LedColor.orange: return const Color(0xFFFF9A50);
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: state.buzzerOn ? AppColors.orange.withOpacity(0.4) : AppColors.border,
          width: 0.8,
        ),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: state.buzzerOn ? AppColors.orangeDim : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.volume_up_rounded,
              color: state.buzzerOn ? AppColors.orange : AppColors.textMuted, size: 20),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Buzzer', style: AppText.title),
          Text(state.buzzerOn ? 'A tocar' : 'Silencioso', style: AppText.body),
        ]),
        const Spacer(),
        Switch(
          value: state.buzzerOn,
          thumbColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.selected)) return Colors.white;
            return AppColors.textMuted;
          }),
          trackColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.selected)) return AppColors.orange;
            return AppColors.border;
          }),
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
      _QuickMode('Foco',     '💡', 'Luz branca intensa',
          const ActuatorState(ledOn: true, ledBrightness: 1.0, ledColor: LedColor.white)),
      _QuickMode('Noturno',  '🌙', 'Luz quente, fraca',
          const ActuatorState(ledOn: true, ledBrightness: 0.2, ledColor: LedColor.warm)),
      _QuickMode('Alerta',   '🚨', 'Luz + buzzer',
          const ActuatorState(ledOn: true, ledBrightness: 1.0, ledColor: LedColor.orange, buzzerOn: true)),
      _QuickMode('Desligar', '⏻',  'Tudo desligado', const ActuatorState()),
    ];

    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.2,
      children: modes.map((m) => GestureDetector(
        onTap: () => onSelect(m.state),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 0.8),
          ),
          child: Row(children: [
            Text(m.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(m.name, style: AppText.title),
                  Text(m.description, style: AppText.body),
                ]),
          ]),
        ),
      )).toList(),
    );
  }
}

class _QuickMode {
  final String name, emoji, description;
  final ActuatorState state;
  const _QuickMode(this.name, this.emoji, this.description, this.state);
}

class _StatePreview extends StatelessWidget {
  final ActuatorState state;
  const _StatePreview({required this.state});

  @override
  Widget build(BuildContext context) {
    final json = state.toJson();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Payload MQTT (pré-visualização)', style: AppText.label),
        const SizedBox(height: 8),
        Text(
          json.entries.map((e) => '"${e.key}": ${e.value}').join('\n'),
          style: GoogleFonts.jetBrainsMono(color: AppColors.textSecondary, fontSize: 12, height: 1.7),
        ),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: AppColors.textMuted, size: 14),
      const SizedBox(width: 6),
      Text(title.toUpperCase(), style: AppText.label),
    ]);
  }
}