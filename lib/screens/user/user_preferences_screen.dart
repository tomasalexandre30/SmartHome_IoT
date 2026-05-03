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

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(title: const Text('As minhas preferências')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [

              // ── Header ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(18),
                decoration: SS.glowCard(glowColor: AppTheme.accent),
                child: Row(
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppTheme.accent.withOpacity(0.25),
                            width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          (user?.displayName ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? 'Utilizador',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Define as tuas preferências por zona.\nSão aplicadas automaticamente quando entras.',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Preferências por zona ──────────────────────────────
              const _SectionLabel(label: 'Preferências por zona'),
              const SizedBox(height: 10),
              ...ss.zones.map((z) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ZonePreferenceCard(zone: z),
              )),

              const SizedBox(height: 20),

              // ── Não incomodar global ───────────────────────────────
              const _SectionLabel(label: 'Modo não incomodar'),
              const SizedBox(height: 10),
              _DoNotDisturbCard(zones: ss.zones),
            ],
          ),
        );
      },
    );
  }
}

// ── Zone Preference Card ───────────────────────────────────────────────────────

class _ZonePreferenceCard extends StatefulWidget {
  final Zone zone;
  const _ZonePreferenceCard({required this.zone});

  @override
  State<_ZonePreferenceCard> createState() => _ZonePreferenceCardState();
}

class _ZonePreferenceCardState extends State<_ZonePreferenceCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ss = context.watch<SmartSpaceProvider>();
    final prefs = ss.preferencesFor(widget.zone.id);
    final z = widget.zone;

    return Container(
      decoration: SS.card(accentColor: _expanded ? z.color : null),
      child: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────
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
                      color: z.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(z.icon, color: z.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(z.name,
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          'Luz: ${(prefs.lightIntensity * 100).toInt()}% · Temp: ${prefs.temperatureTarget.toStringAsFixed(0)}°C',
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (prefs.doNotDisturb)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: SS.pill(color: AppTheme.textMuted),
                      child: const Text('DND',
                          style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
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

          // ── Expanded ───────────────────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Intensidade de luz
                  _PrefRow(
                    icon: Icons.lightbulb_rounded,
                    label: 'Intensidade de luz',
                    valueLabel: '${(prefs.lightIntensity * 100).toInt()}%',
                    color: AppTheme.warning,
                    child: Slider(
                      value: prefs.lightIntensity,
                      onChanged: (v) => ss.updatePreferences(
                          prefs.copyWith(lightIntensity: v)),
                      activeColor: AppTheme.warning,
                      inactiveColor: AppTheme.border,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Temperatura preferida
                  _PrefRow(
                    icon: Icons.thermostat_rounded,
                    label: 'Temperatura preferida',
                    valueLabel: '${prefs.temperatureTarget.toStringAsFixed(0)}°C',
                    color: AppTheme.error,
                    child: Slider(
                      value: prefs.temperatureTarget,
                      min: 16, max: 30,
                      onChanged: (v) => ss.updatePreferences(
                          prefs.copyWith(temperatureTarget: v)),
                      activeColor: AppTheme.error,
                      inactiveColor: AppTheme.border,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Cor de luz preferida
                  _ColorPicker(prefs: prefs, ss: ss),
                  const SizedBox(height: 8),

                  // Não incomodar
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: SS.card(),
                    child: Row(
                      children: [
                        const Icon(Icons.do_not_disturb_on_rounded,
                            color: AppTheme.textMuted, size: 18),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Não incomodar',
                                  style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                'Bloqueia notificações de entrada nesta zona',
                                style: TextStyle(
                                    color: AppTheme.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: prefs.doNotDisturb,
                          onChanged: (v) => ss.updatePreferences(
                              prefs.copyWith(doNotDisturb: v)),
                        ),
                      ],
                    ),
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

// ── Pref Row ───────────────────────────────────────────────────────────────────

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

// ── Color Picker ───────────────────────────────────────────────────────────────

class _ColorPicker extends StatelessWidget {
  final UserPreferences prefs;
  final SmartSpaceProvider ss;

  const _ColorPicker({required this.prefs, required this.ss});

  static const _colors = [
    (Color(0xFFFFFFFF), 'Branco'),
    (Color(0xFFFFF3B0), 'Quente'),
    (Color(0xFFFFD6A5), 'Âmbar'),
    (Color(0xFFCBF3F0), 'Frio'),
    (Color(0xFFA8DADC), 'Azul'),
    (Color(0xFFFFADAD), 'Rosa'),
  ];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: SS.card(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.palette_rounded,
                color: AppTheme.accent, size: 16),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Cor de luz preferida',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
            ),
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: prefs.lightColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.border),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _colors.map((c) {
            final (color, label) = c;
            final selected = prefs.lightColor.value == color.value;
            return GestureDetector(
              onTap: () => ss.updatePreferences(
                  prefs.copyWith(lightColor: color)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? AppTheme.accent : AppTheme.border,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.border),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(label,
                        style: TextStyle(
                          color: selected
                              ? AppTheme.accent
                              : AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        )),
                    if (selected) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.check_rounded,
                          color: AppTheme.accent, size: 12),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ),
  );
}

// ── Do Not Disturb Card ────────────────────────────────────────────────────────

class _DoNotDisturbCard extends StatelessWidget {
  final List<Zone> zones;
  const _DoNotDisturbCard({required this.zones});

  @override
  Widget build(BuildContext context) {
    final ss = context.watch<SmartSpaceProvider>();
    final anyDnd = zones.any((z) => ss.preferencesFor(z.id).doNotDisturb);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SS.card(accentColor: anyDnd ? AppTheme.textMuted : null),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: SS.iconBox(
                    color: anyDnd ? AppTheme.textMuted : AppTheme.accent),
                child: Icon(Icons.do_not_disturb_on_rounded,
                    color: anyDnd ? AppTheme.textMuted : AppTheme.accent,
                    size: 20),
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
                          ? 'Ativo em algumas zonas'
                          : 'Bloqueia notificações em todas as zonas',
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 12),
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
        ],
      ),
    );
  }
}

// ── Section Label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: const TextStyle(
      color: AppTheme.textMuted,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1,
    ),
  );
}