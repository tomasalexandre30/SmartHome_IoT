import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/smartspace_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../models/models.dart';

class ZoneHeader extends StatelessWidget {
  final Zone zone;
  final bool isCurrentZone;
  const ZoneHeader({super.key, required this.zone, required this.isCurrentZone});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            zone.color.withOpacity(0.35),
            zone.color.withOpacity(0.08),
            AppTheme.background,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(58, 18, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: zone.color.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: zone.color.withOpacity(0.35)),
                    ),
                    child: Icon(zone.icon, color: zone.color, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(zone.name,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w900)),
                  ),
                  ZoneStatusBadge(zone: zone),
                ],
              ),
              const SizedBox(height: 10),
              if (isCurrentZone)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: SS.pill(color: zone.color),
                  child: Text('Estás aqui',
                      style: TextStyle(
                          color: zone.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ZoneQuickSummary extends StatelessWidget {
  final Zone zone;
  const ZoneQuickSummary({super.key, required this.zone});

  @override
  Widget build(BuildContext context) => Container(
    decoration: SS.glowCard(glowColor: zone.color),
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Expanded(child: ZoneSummaryItem(
          icon: Icons.groups_rounded,
          label: 'Ocupantes',
          value: '${zone.occupantCount}',
          color: zone.color,
        )),
        const SizedBox(width: 10),
        Expanded(child: ZoneSummaryItem(
          icon: Icons.lightbulb_rounded,
          label: 'Luz',
          value: zone.lightOn ? 'Ligada' : 'Off',
          color: zone.lightOn ? AppTheme.warning : AppTheme.textMuted,
        )),
        const SizedBox(width: 10),
        Expanded(child: ZoneSummaryItem(
          icon: Icons.bolt_rounded,
          label: 'Energia',
          value: '${zone.energyUsageWh.toStringAsFixed(1)} Wh',
          color: AppTheme.success,
        )),
      ],
    ),
  );
}

class ZoneSummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const ZoneSummaryItem({super.key, required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.border),
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(value,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
      ],
    ),
  );
}

class ZoneQuickControls extends StatelessWidget {
  final Zone zone;
  const ZoneQuickControls({super.key, required this.zone});

  @override
  Widget build(BuildContext context) {
    final ss = context.read<SmartSpaceProvider>();
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: ZoneControlButton(
              icon: Icons.lightbulb_rounded,
              label: 'LED RGB',
              activeLabel: zone.lightOn ? 'Ligado' : 'Desligado',
              active: zone.lightOn,
              color: AppTheme.warning,
              onTap: () => ss.toggleLight(zone.id),
            )),
            const SizedBox(width: 10),
            Expanded(child: ZoneControlButton(
              icon: Icons.volume_up_rounded,
              label: 'Buzzer',
              activeLabel: zone.buzzerOn ? 'Ativo' : 'Inativo',
              active: zone.buzzerOn,
              color: AppTheme.error,
              onTap: () => ss.toggleBuzzer(zone.id),
            )),
          ],
        ),
        if (zone.lightOn) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: SS.card(),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.brightness_6_rounded, color: AppTheme.warning, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Intensidade',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
                    Text('${(zone.lightIntensity * 100).round()}%',
                        style: const TextStyle(color: AppTheme.warning, fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
                Slider(
                  value: zone.lightIntensity,
                  min: 0, max: 1, divisions: 10,
                  activeColor: AppTheme.warning,
                  inactiveColor: AppTheme.border,
                  onChanged: (v) => ss.setLightIntensity(zone.id, v),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class ZoneControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String activeLabel;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const ZoneControlButton({super.key, required this.icon, required this.label,
    required this.activeLabel, required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? color.withOpacity(0.45) : AppTheme.border,
          width: active ? 1.4 : 1,
        ),
        boxShadow: active
            ? [BoxShadow(color: color.withOpacity(0.12), blurRadius: 18)]
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: active ? color.withOpacity(0.15) : AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: active ? color : AppTheme.textMuted, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(activeLabel, style: TextStyle(
                    color: active ? color : AppTheme.textMuted,
                    fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Icon(active ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
              color: active ? color : AppTheme.textMuted, size: 34),
        ],
      ),
    ),
  );
}

class ZoneSensorDashboard extends StatelessWidget {
  final Zone zone;
  const ZoneSensorDashboard({super.key, required this.zone});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(child: SensorTile(
            icon: Icons.thermostat_rounded, label: 'Temperatura',
            value: zone.temperature != null ? '${zone.temperature!.toStringAsFixed(1)}°C' : '—',
            color: AppTheme.warning,
          )),
          const SizedBox(width: 10),
          Expanded(child: SensorTile(
            icon: Icons.water_drop_rounded, label: 'Humidade',
            value: zone.humidity != null ? '${zone.humidity!.toStringAsFixed(0)}%' : '—',
            color: AppTheme.accent,
          )),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(child: SensorTile(
            icon: Icons.wb_sunny_rounded, label: 'Luminosidade',
            value: zone.luminosity != null ? '${zone.luminosity!.toStringAsFixed(0)} lx' : '—',
            color: AppTheme.warning,
          )),
          const SizedBox(width: 10),
          Expanded(child: SensorTile(
            icon: Icons.motion_photos_on_rounded, label: 'Movimento',
            value: zone.motionDetected == null ? '—' : zone.motionDetected! ? 'Detetado' : 'Nenhum',
            color: zone.motionDetected == true ? AppTheme.success : AppTheme.textMuted,
          )),
        ],
      ),
    ],
  );
}

class ZoneEnergyCard extends StatelessWidget {
  final Zone zone;
  final bool isAdmin;
  const ZoneEnergyCard({super.key, required this.zone, this.isAdmin = false});

  @override
  Widget build(BuildContext context) => Container(
    decoration: SS.glowCard(glowColor: AppTheme.success),
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppTheme.success.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.bolt_rounded, color: AppTheme.success, size: 30),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${zone.energyUsageWh.toStringAsFixed(2)} Wh',
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w900)),
              const Text('Consumo estimado da sessão',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              if (isAdmin) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('Definir limite de consumo',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class ZoneEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const ZoneEmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: SS.glowCard(),
    child: Column(
      children: [
        Icon(icon, color: AppTheme.textMuted, size: 28),
        const SizedBox(height: 8),
        Text(message,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
            textAlign: TextAlign.center),
      ],
    ),
  );
}

class ZoneUserChip extends StatelessWidget {
  final String name;
  const ZoneUserChip({super.key, required this.name});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: SS.pill(color: AppTheme.accent),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircleAvatar(
          radius: 9,
          backgroundColor: AppTheme.accent,
          child: Icon(Icons.person_rounded, size: 11, color: Colors.white),
        ),
        const SizedBox(width: 7),
        Text(name,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class ZoneSection extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const ZoneSection({super.key, required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeader(title: title, trailing: trailing),
      child,
    ],
  );
}

class ZoneDemoCollapsedCard extends StatelessWidget {
  const ZoneDemoCollapsedCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: SS.card(),
    child: const Row(
      children: [
        Icon(Icons.science_rounded, color: AppTheme.accent, size: 22),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Simula dados dos sensores enquanto o ESP32 não está ligado.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class ZoneDemoControls extends StatefulWidget {
  final String zoneId;
  const ZoneDemoControls({super.key, required this.zoneId});

  @override
  State<ZoneDemoControls> createState() => _ZoneDemoControlsState();
}

class _ZoneDemoControlsState extends State<ZoneDemoControls> {
  double _temp = 22;
  double _hum = 50;
  double _lux = 300;
  bool _motion = false;

  @override
  Widget build(BuildContext context) {
    final ss = context.read<SmartSpaceProvider>();
    void inject() => ss.injectSensorData(
      widget.zoneId,
      temperature: _temp,
      humidity: _hum,
      luminosity: _lux,
      motion: _motion,
    );

    return Container(
      key: const ValueKey('demo-expanded'),
      padding: const EdgeInsets.all(16),
      decoration: SS.glowCard(glowColor: AppTheme.accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Simula dados dos sensores físicos para testar a interface e as automações antes de ligares o ESP32.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ZoneDemoSlider(label: 'Temperatura', value: _temp, min: 10, max: 40, unit: '°C',
              color: AppTheme.warning, onChanged: (v) { setState(() => _temp = v); inject(); }),
          ZoneDemoSlider(label: 'Humidade', value: _hum, min: 0, max: 100, unit: '%',
              color: AppTheme.accent, onChanged: (v) { setState(() => _hum = v); inject(); }),
          ZoneDemoSlider(label: 'Luminosidade', value: _lux, min: 0, max: 1000, unit: ' lx',
              color: AppTheme.warning, onChanged: (v) { setState(() => _lux = v); inject(); }),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: SS.card(),
            child: Row(
              children: [
                const Icon(Icons.motion_photos_on_rounded, color: AppTheme.success, size: 18),
                const SizedBox(width: 10),
                const Text('Movimento',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                const Spacer(),
                Switch(
                  value: _motion,
                  onChanged: (v) { setState(() => _motion = v); inject(); },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ZoneDemoSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final Color color;
  final ValueChanged<double> onChanged;

  const ZoneDemoSlider({super.key, required this.label, required this.value,
    required this.min, required this.max, required this.unit,
    required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Text(label, style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('${value.toStringAsFixed(0)}$unit',
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
        ],
      ),
      Slider(value: value, min: min, max: max,
          onChanged: onChanged, activeColor: color, inactiveColor: AppTheme.border),
    ],
  );
}