import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/smartspace_provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../models/models.dart';

class UserPreferencesScreen extends StatelessWidget {
  const UserPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SmartSpaceProvider>(
      builder: (context, ss, _) {
        final auth = context.watch<AuthService>();
        final user = auth.appUser;
        final configuredZones = ss.zones.where((z) {
          final p = ss.preferencesFor(z.id);
          return p.enabled;
        }).length;

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(title: const Text('Preferências')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              _HeaderCard(
                displayName: user?.displayName ?? 'Utilizador',
                configuredZones: configuredZones,
                totalZones: ss.zones.length,
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Modo não incomodar'),
              const SizedBox(height: 10),
              _DoNotDisturbCard(zones: ss.zones),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Preferências por zona'),
              const SizedBox(height: 10),
              ...ss.zones.map((z) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ZonePreferenceCard(zone: z),
              )),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: SS.card(),
                child: const Row(
                  children: [
                    Icon(Icons.sync_rounded,
                        color: AppTheme.textMuted, size: 18),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'As preferências ativas são aplicadas automaticamente ao entrar numa zona.',
                        style:
                        TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Header Card ───────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final String displayName;
  final int configuredZones;
  final int totalZones;

  const _HeaderCard({
    required this.displayName,
    required this.configuredZones,
    required this.totalZones,
  });

  @override
  Widget build(BuildContext context) {
    final initial = displayName[0].toUpperCase();
    final allActive = configuredZones == totalZones;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: SS.glowCard(glowColor: AppTheme.accent),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppTheme.accent.withOpacity(0.25), width: 1.5),
                ),
                child: Center(
                  child: Text(initial,
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      )),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 3),
                    const Text(
                      'Preferências aplicadas ao entrar numa zona.',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: allActive
                                ? AppTheme.success.withOpacity(0.1)
                                : AppTheme.accentLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: allActive
                                  ? AppTheme.success.withOpacity(0.3)
                                  : AppTheme.accentBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6, height: 6,
                                decoration: BoxDecoration(
                                  color: allActive
                                      ? AppTheme.success
                                      : AppTheme.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$configuredZones/$totalZones zonas ativas',
                                style: TextStyle(
                                  color: allActive
                                      ? AppTheme.success
                                      : AppTheme.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Zone Preference Card ──────────────────────────────────────────────────────

class _ZonePreferenceCard extends StatefulWidget {
  final Zone zone;
  const _ZonePreferenceCard({required this.zone});

  @override
  State<_ZonePreferenceCard> createState() => _ZonePreferenceCardState();
}

class _ZonePreferenceCardState extends State<_ZonePreferenceCard> {
  bool _expanded = false;
  bool _saved = false;

  void _saveWithFeedback(
      BuildContext context, SmartSpaceProvider ss, UserPreferences prefs) {
    ss.updatePreferences(prefs);
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ss = context.watch<SmartSpaceProvider>();
    final prefs = ss.preferencesFor(widget.zone.id);
    final z = widget.zone;
    final isEnabled = prefs.enabled;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: SS.card(
          accentColor: _expanded
              ? z.color
              : isEnabled
              ? z.color.withOpacity(0.4)
              : null),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isEnabled
                          ? z.color.withOpacity(0.15)
                          : AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(z.icon,
                        color: isEnabled ? z.color : AppTheme.textMuted,
                        size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(z.name,
                                style: TextStyle(
                                    color: isEnabled
                                        ? AppTheme.textPrimary
                                        : AppTheme.textMuted,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isEnabled
                                    ? z.color.withOpacity(0.1)
                                    : AppTheme.surface,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isEnabled
                                      ? z.color.withOpacity(0.3)
                                      : AppTheme.border,
                                ),
                              ),
                              child: Text(
                                isEnabled ? 'Ativo' : 'Inativo',
                                style: TextStyle(
                                    color: isEnabled
                                        ? z.color
                                        : AppTheme.textMuted,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isEnabled
                              ? 'Luz: ${(prefs.lightIntensity * 100).toInt()}% · Temp: ${prefs.temperatureTarget.toStringAsFixed(0)}°C'
                              : 'Preferências desativadas para esta zona',
                          style: TextStyle(
                              color: isEnabled
                                  ? AppTheme.textMuted
                                  : AppTheme.textMuted.withOpacity(0.5),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (_saved)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.successLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded,
                              color: AppTheme.success, size: 12),
                          SizedBox(width: 4),
                          Text('Guardado',
                              style: TextStyle(
                                  color: AppTheme.success,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppTheme.textMuted,
                  ),
                ],
              ),
            ),
          ),

          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ── Toggle ativar/desativar ────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isEnabled
                          ? z.color.withOpacity(0.06)
                          : AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isEnabled
                            ? z.color.withOpacity(0.2)
                            : AppTheme.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.tune_rounded,
                            color:
                            isEnabled ? z.color : AppTheme.textMuted,
                            size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Usar preferências nesta zona',
                                style: TextStyle(
                                    color: isEnabled
                                        ? AppTheme.textPrimary
                                        : AppTheme.textMuted,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600),
                              ),
                              Text(
                                isEnabled
                                    ? 'Aplicado automaticamente ao entrar'
                                    : 'Sem configuração automática',
                                style: TextStyle(
                                    color: isEnabled
                                        ? z.color
                                        : AppTheme.textMuted,
                                    fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isEnabled,
                          onChanged: (v) => _saveWithFeedback(
                              context, ss, prefs.copyWith(enabled: v)),
                          activeColor: z.color,
                        ),
                      ],
                    ),
                  ),

                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 200),
                    crossFadeState: isEnabled
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    firstChild: Column(
                      children: [
                        const SizedBox(height: 10),
                        _PrefRow(
                          icon: Icons.lightbulb_rounded,
                          label: 'Intensidade de luz',
                          valueLabel:
                          '${(prefs.lightIntensity * 100).toInt()}%',
                          color: AppTheme.warning,
                          child: Slider(
                            value: prefs.lightIntensity,
                            onChanged: (v) => _saveWithFeedback(context,
                                ss, prefs.copyWith(lightIntensity: v)),
                            activeColor: AppTheme.warning,
                            inactiveColor: AppTheme.border,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _PrefRow(
                          icon: Icons.thermostat_rounded,
                          label: 'Temperatura preferida',
                          valueLabel:
                          '${prefs.temperatureTarget.toStringAsFixed(0)}°C',
                          color: AppTheme.error,
                          child: Slider(
                            value: prefs.temperatureTarget,
                            min: 16,
                            max: 30,
                            onChanged: (v) => _saveWithFeedback(context,
                                ss, prefs.copyWith(temperatureTarget: v)),
                            activeColor: AppTheme.error,
                            inactiveColor: AppTheme.border,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _ColorPickerCard(
                          prefs: prefs,
                          onColorChanged: (color) => _saveWithFeedback(
                              context, ss, prefs.copyWith(lightColor: color)),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: SS.card(),
                          child: Row(
                            children: [
                              Icon(
                                Icons.do_not_disturb_on_rounded,
                                color: prefs.doNotDisturb
                                    ? AppTheme.error
                                    : AppTheme.textMuted,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    const Text('Não incomodar',
                                        style: TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600)),
                                    Text(
                                      prefs.doNotDisturb
                                          ? 'Notificações bloqueadas nesta zona'
                                          : 'Bloqueia notificações de entrada',
                                      style: TextStyle(
                                          color: prefs.doNotDisturb
                                              ? AppTheme.error
                                              : AppTheme.textMuted,
                                          fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: prefs.doNotDisturb,
                                onChanged: (v) => _saveWithFeedback(context,
                                    ss, prefs.copyWith(doNotDisturb: v)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _saveWithFeedback(
                                context,
                                ss,
                                UserPreferences(
                                    zoneId: z.id, enabled: true)),
                            icon: const Icon(Icons.restart_alt_rounded,
                                color: AppTheme.textMuted, size: 16),
                            label: const Text('Repor predefinições',
                                style: TextStyle(
                                    color: AppTheme.textMuted)),
                            style: OutlinedButton.styleFrom(
                              side:
                              const BorderSide(color: AppTheme.border),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    secondChild: const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Pref Row ──────────────────────────────────────────────────────────────────

class _PrefRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valueLabel;
  final Color color;
  final Widget child;

  const _PrefRow({
    required this.icon,
    required this.label,
    required this.valueLabel,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
    decoration: SS.card(),
    child: Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
            ),
            Text(valueLabel,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        child,
      ],
    ),
  );
}

// ── Preset Color ──────────────────────────────────────────────────────────────

class _PresetColor {
  final String name;
  final Color color;
  const _PresetColor(this.name, this.color);
}

// ── Color Picker Card ─────────────────────────────────────────────────────────

class _ColorPickerCard extends StatelessWidget {
  final UserPreferences prefs;
  final ValueChanged<Color> onColorChanged;

  const _ColorPickerCard({
    required this.prefs,
    required this.onColorChanged,
  });

  static const List<_PresetColor> _presets = [
    _PresetColor('Branco',   Color(0xFFFFFFFF)),
    _PresetColor('Vermelho', Color(0xFFFF0000)),
    _PresetColor('Verde',    Color(0xFF00FF00)),
    _PresetColor('Azul',     Color(0xFF0000FF)),
    _PresetColor('Amarelo',  Color(0xFFFFFF00)),
    _PresetColor('Ciano',    Color(0xFF00FFFF)),
    _PresetColor('Magenta',  Color(0xFFFF00FF)),
    _PresetColor('Laranja',  Color(0xFFFF6600)),
    _PresetColor('Roxo',     Color(0xFF8800FF)),
    _PresetColor('Rosa',     Color(0xFFFF0088)),
  ];

  @override
  Widget build(BuildContext context) {
    final currentColor = prefs.lightColor;
    final isWhite = currentColor.red > 200 &&
        currentColor.green > 200 &&
        currentColor.blue > 200;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SS.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: isWhite
                      ? const Color(0xFF2C2C2C)
                      : currentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isWhite
                        ? const Color(0xFF555555)
                        : currentColor.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Icon(Icons.palette_rounded,
                    color: isWhite ? Colors.white : currentColor, size: 16),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Cor de luz preferida',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: currentColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isWhite
                        ? const Color(0xFF999999)
                        : currentColor.withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isWhite
                          ? Colors.grey.withOpacity(0.3)
                          : currentColor.withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Presets ───────────────────────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((preset) {
              final isSelected =
                  currentColor.red == preset.color.red &&
                      currentColor.green == preset.color.green &&
                      currentColor.blue == preset.color.blue;
              final isPresetWhite = preset.color == Colors.white;

              return GestureDetector(
                onTap: () => onColorChanged(preset.color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isPresetWhite
                        ? (isSelected
                        ? const Color(0xFF2C2C2C)
                        : const Color(0xFFE8E8E8))
                        : preset.color
                        .withOpacity(isSelected ? 0.25 : 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isPresetWhite
                          ? (isSelected
                          ? const Color(0xFF888888)
                          : const Color(0xFFCCCCCC))
                          : (isSelected
                          ? preset.color.withOpacity(0.8)
                          : preset.color.withOpacity(0.3)),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: preset.color,
                          shape: BoxShape.circle,
                          border: isPresetWhite
                              ? Border.all(
                              color: const Color(0xFFAAAAAA), width: 1)
                              : null,
                          boxShadow: isSelected
                              ? [
                            BoxShadow(
                              color: isPresetWhite
                                  ? Colors.grey.withOpacity(0.5)
                                  : preset.color.withOpacity(0.6),
                              blurRadius: 6,
                              spreadRadius: 1,
                            )
                          ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        preset.name,
                        style: TextStyle(
                          color: isPresetWhite
                              ? (isSelected
                              ? Colors.white
                              : AppTheme.textPrimary)
                              : preset.color,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // ── Sliders RGB ───────────────────────────────────────────────────
          _RgbSliderRow(
            label: 'R',
            value: currentColor.red,
            color: const Color(0xFFFF3333),
            onChanged: (v) => onColorChanged(
                Color.fromRGBO(v, currentColor.green, currentColor.blue, 1.0)),
          ),
          const SizedBox(height: 8),
          _RgbSliderRow(
            label: 'G',
            value: currentColor.green,
            color: const Color(0xFF22CC22),
            onChanged: (v) => onColorChanged(
                Color.fromRGBO(currentColor.red, v, currentColor.blue, 1.0)),
          ),
          const SizedBox(height: 8),
          _RgbSliderRow(
            label: 'B',
            value: currentColor.blue,
            color: const Color(0xFF3366FF),
            onChanged: (v) => onColorChanged(
                Color.fromRGBO(currentColor.red, currentColor.green, v, 1.0)),
          ),
          const SizedBox(height: 12),

          // ── RGB display ───────────────────────────────────────────────────
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text(
                'RGB(${currentColor.red}, ${currentColor.green}, ${currentColor.blue})',
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── RGB Slider Row ────────────────────────────────────────────────────────────

class _RgbSliderRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final ValueChanged<int> onChanged;

  const _RgbSliderRow({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          child: Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape:
              const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape:
              const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 255,
              onChanged: (v) => onChanged(v.toInt()),
              activeColor: color,
              inactiveColor: AppTheme.border,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 30,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ── Do Not Disturb Card ───────────────────────────────────────────────────────

class _DoNotDisturbCard extends StatelessWidget {
  final List<Zone> zones;
  const _DoNotDisturbCard({required this.zones});

  @override
  Widget build(BuildContext context) {
    final ss = context.watch<SmartSpaceProvider>();
    final anyDnd =
    zones.any((z) => ss.preferencesFor(z.id).doNotDisturb);
    final dndCount =
        zones.where((z) => ss.preferencesFor(z.id).doNotDisturb).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SS.card(accentColor: anyDnd ? AppTheme.error : null),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: SS.iconBox(
                    color: anyDnd ? AppTheme.error : AppTheme.accent),
                child: Icon(
                  anyDnd
                      ? Icons.do_not_disturb_on_rounded
                      : Icons.notifications_active_rounded,
                  color: anyDnd ? AppTheme.error : AppTheme.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ativar em todas as zonas',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    Text(
                      anyDnd
                          ? '$dndCount zona${dndCount != 1 ? "s" : ""} com DND ativo'
                          : 'Bloqueia notificações em todas as zonas',
                      style: TextStyle(
                          color: anyDnd
                              ? AppTheme.error
                              : AppTheme.textMuted,
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch(
                value: anyDnd,
                onChanged: (v) {
                  for (final z in zones) {
                    ss.updatePreferences(
                        ss.preferencesFor(z.id).copyWith(doNotDisturb: v));
                  }
                },
              ),
            ],
          ),
          if (anyDnd) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            ...zones
                .where((z) => ss.preferencesFor(z.id).doNotDisturb)
                .map((z) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: z.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(z.icon, color: z.color, size: 14),
                  ),
                  const SizedBox(width: 10),
                  Text(z.name,
                      style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => ss.updatePreferences(ss
                        .preferencesFor(z.id)
                        .copyWith(doNotDisturb: false)),
                    child: const Icon(Icons.close_rounded,
                        color: AppTheme.textMuted, size: 16),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}