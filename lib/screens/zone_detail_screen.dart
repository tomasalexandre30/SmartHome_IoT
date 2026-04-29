import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/smartspace_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../models/models.dart';

class ZoneDetailScreen extends StatelessWidget {
  final String zoneId;
  const ZoneDetailScreen({super.key, required this.zoneId});

  @override
  Widget build(BuildContext context) {
    return Consumer<SmartSpaceProvider>(builder: (context, ss, _) {
      final zone = ss.zoneById(zoneId);
      if (zone == null) return const Scaffold(body: Center(child: Text('Zona não encontrada')));

      final isCurrentZone = ss.currentZoneId == zoneId;

      return Scaffold(
        backgroundColor: AppTheme.background,
        body: CustomScrollView(
          slivers: [
            // ── Header ───────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 160,
              pinned: true,
              backgroundColor: AppTheme.background,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [zone.color.withOpacity(0.3), AppTheme.background],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(70, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: zone.color.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(zone.icon, color: zone.color, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(zone.name,
                                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                              ),
                              ZoneStatusBadge(zone: zone),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (isCurrentZone)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: SS.pill(color: zone.color),
                              child: Text('Estás aqui',
                                  style: TextStyle(color: zone.color, fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── Occupants ────────────────────────────────────────
                  _Section(
                    title: 'Ocupantes (${zone.occupantCount})',
                    child: zone.presentUsers.isEmpty
                        ? const _EmptyState(message: 'Nenhum utilizador detetado')
                        : Wrap(
                            spacing: 8,
                            children: zone.presentUsers.map((u) => _UserChip(name: u)).toList(),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // ── Sensors ──────────────────────────────────────────
                  _Section(
                    title: 'Sensores',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: SS.pill(color: AppTheme.textMuted),
                      child: const Text('ESP32 pendente', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: SensorTile(icon: Icons.thermostat_rounded, label: 'Temperatura',
                                value: zone.temperature != null ? '${zone.temperature!.toStringAsFixed(1)}°C' : '—', color: AppTheme.warning)),
                            const SizedBox(width: 10),
                            Expanded(child: SensorTile(icon: Icons.water_drop_rounded, label: 'Humidade',
                                value: zone.humidity != null ? '${zone.humidity!.toStringAsFixed(0)}%' : '—', color: AppTheme.accent)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: SensorTile(icon: Icons.wb_sunny_rounded, label: 'Luminosidade',
                                value: zone.luminosity != null ? '${zone.luminosity!.toStringAsFixed(0)} lx' : '—', color: AppTheme.warning)),
                            const SizedBox(width: 10),
                            Expanded(child: SensorTile(icon: Icons.motion_photos_on_rounded, label: 'Movimento',
                                value: zone.motionDetected == null ? '—' : zone.motionDetected! ? 'Detetado' : 'Nenhum',
                                color: zone.motionDetected == true ? AppTheme.success : AppTheme.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Actuators ─────────────────────────────────────────
                  _Section(
                    title: 'Atuadores',
                    child: Column(
                      children: [
                        _ActuatorRow(
                          icon: Icons.lightbulb_rounded,
                          label: 'Iluminação (LED RGB)',
                          active: zone.lightOn,
                          color: AppTheme.warning,
                          onToggle: () => ss.toggleLight(zoneId),
                          trailing: zone.lightOn
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Intensidade', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                      Slider(
                                        value: zone.lightIntensity,
                                        onChanged: (v) => ss.setLightIntensity(zoneId, v),
                                        activeColor: AppTheme.warning,
                                        inactiveColor: AppTheme.border,
                                      ),
                                    ],
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 10),
                        _ActuatorRow(
                          icon: Icons.volume_up_rounded,
                          label: 'Buzzer (alerta sonoro)',
                          active: zone.buzzerOn,
                          color: AppTheme.error,
                          onToggle: () => ss.toggleBuzzer(zoneId),
                        ),
                        const SizedBox(height: 10),
                        _ActuatorRow(
                          icon: Icons.monitor_rounded,
                          label: 'LCD Local',
                          active: true,
                          color: AppTheme.accent,
                          onToggle: null, // always on
                          subtitle: 'Mostra ocupação em tempo real',
                          readOnly: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Automation rules ──────────────────────────────────
                  _Section(
                    title: 'Automações',
                    trailing: TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add_rounded, size: 14, color: AppTheme.accent),
                      label: const Text('Adicionar', style: TextStyle(fontSize: 12, color: AppTheme.accent)),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                    ),
                    child: zone.rules.isEmpty
                        ? const _EmptyState(message: 'Sem regras de automação. Adiciona uma regra para automatizar esta zona.')
                        : Column(
                            children: zone.rules.map((r) => _RuleRow(rule: r)).toList(),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // ── Energy ────────────────────────────────────────────
                  _Section(
                    title: 'Consumo Energético',
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: SS.glowCard(glowColor: AppTheme.success),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt_rounded, color: AppTheme.success, size: 32),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${zone.energyUsageWh.toStringAsFixed(2)} Wh',
                                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
                              const Text('Consumo estimado (sessão atual)',
                                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Demo controls (mock sensor injection) ─────────────
                  _Section(
                    title: 'Simulação (Demo)',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: SS.pill(color: AppTheme.accent),
                      child: const Text('Sem ESP32', style: TextStyle(color: AppTheme.accent, fontSize: 10)),
                    ),
                    child: _DemoControls(zoneId: zoneId),
                  ),
                ]),
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _Section({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeader(title: title, trailing: trailing),
      child,
    ],
  );
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: SS.glowCard(),
    child: Text(message, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13), textAlign: TextAlign.center),
  );
}

class _UserChip extends StatelessWidget {
  final String name;
  const _UserChip({required this.name});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: SS.pill(color: AppTheme.accent),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircleAvatar(radius: 8, backgroundColor: AppTheme.accent, child: Icon(Icons.person_rounded, size: 10, color: Colors.white)),
        const SizedBox(width: 6),
        Text(name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    ),
  );
}

class _ActuatorRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color color;
  final VoidCallback? onToggle;
  final String? subtitle;
  final bool readOnly;
  final Widget? trailing;

  const _ActuatorRow({
    required this.icon,
    required this.label,
    required this.active,
    required this.color,
    required this.onToggle,
    this.subtitle,
    this.readOnly = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 250),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: active ? color.withOpacity(0.4) : AppTheme.border),
      boxShadow: active ? [BoxShadow(color: color.withOpacity(0.1), blurRadius: 12)] : null,
    ),
    child: Column(
      children: [
        Row(
          children: [
            Icon(icon, color: active ? color : AppTheme.textMuted, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                  if (subtitle != null)
                    Text(subtitle!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                ],
              ),
            ),
            if (!readOnly && onToggle != null)
              Switch(value: active, onChanged: (_) => onToggle!())
            else if (readOnly)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: SS.pill(color: AppTheme.success),
                child: const Text('Ativo', style: TextStyle(color: AppTheme.success, fontSize: 11)),
              ),
          ],
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

class _RuleRow extends StatelessWidget {
  final AutomationRule rule;
  const _RuleRow({required this.rule});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: SS.glowCard(glowColor: rule.enabled ? const Color(0xFF8B5CF6) : null),
      child: Row(
        children: [
          const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF8B5CF6), size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(rule.label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: SS.pill(color: rule.enabled ? const Color(0xFF8B5CF6) : AppTheme.textMuted),
            child: Text(rule.enabled ? 'Ativa' : 'Inativa',
                style: TextStyle(color: rule.enabled ? const Color(0xFF8B5CF6) : AppTheme.textMuted, fontSize: 10)),
          ),
        ],
      ),
    ),
  );
}

// ── Demo Controls ─────────────────────────────────────────────────────────────

class _DemoControls extends StatefulWidget {
  final String zoneId;
  const _DemoControls({required this.zoneId});

  @override
  State<_DemoControls> createState() => _DemoControlsState();
}

class _DemoControlsState extends State<_DemoControls> {
  double _temp = 22;
  double _hum  = 50;
  double _lux  = 300;
  bool _motion = false;

  @override
  Widget build(BuildContext context) {
    final ss = context.read<SmartSpaceProvider>();

    void inject() => ss.injectSensorData(widget.zoneId,
        temperature: _temp, humidity: _hum, luminosity: _lux, motion: _motion);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SS.glowCard(glowColor: AppTheme.accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Simula dados de sensores para testar automações sem o ESP32.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          const SizedBox(height: 14),

          _Slider(label: 'Temperatura', value: _temp, min: 10, max: 40, unit: '°C',
              color: AppTheme.warning, onChanged: (v) { setState(() => _temp = v); inject(); }),
          _Slider(label: 'Humidade', value: _hum, min: 0, max: 100, unit: '%',
              color: AppTheme.accent, onChanged: (v) { setState(() => _hum = v); inject(); }),
          _Slider(label: 'Luminosidade', value: _lux, min: 0, max: 1000, unit: ' lx',
              color: AppTheme.warning, onChanged: (v) { setState(() => _lux = v); inject(); }),

          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Movimento', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const Spacer(),
              Switch(value: _motion, onChanged: (v) { setState(() => _motion = v); inject(); }),
            ],
          ),
        ],
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  final String label;
  final double value;
  final double min, max;
  final String unit;
  final Color color;
  final ValueChanged<double> onChanged;

  const _Slider({required this.label, required this.value, required this.min, required this.max,
      required this.unit, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const Spacer(),
          Text('${value.toStringAsFixed(0)}$unit', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
      Slider(value: value, min: min, max: max, onChanged: onChanged, activeColor: color, inactiveColor: AppTheme.border),
    ],
  );
}
