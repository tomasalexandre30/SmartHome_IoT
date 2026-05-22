import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/smartspace_provider.dart';
import '../services/database_service.dart';
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
          value: _formatWh(zone.energyUsageWh),
          color: AppTheme.success,
        )),
      ],
    ),
  );

  static String _formatWh(double wh) {
    if (wh >= 1000) return '${(wh / 1000).toStringAsFixed(2)} kWh';
    if (wh >= 1)    return '${wh.toStringAsFixed(1)} Wh';
    return '${(wh * 1000).toStringAsFixed(0)} mWh';
  }
}

class ZoneSummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const ZoneSummaryItem({super.key, required this.icon, required this.label,
    required this.value, required this.color});

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
                    const Icon(Icons.brightness_6_rounded,
                        color: AppTheme.warning, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Intensidade',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13))),
                    Text('${(zone.lightIntensity * 100).round()}%',
                        style: const TextStyle(color: AppTheme.warning,
                            fontSize: 13, fontWeight: FontWeight.w700)),
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
    required this.activeLabel, required this.active, required this.color,
    required this.onTap});

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
                    color: AppTheme.textPrimary, fontSize: 14,
                    fontWeight: FontWeight.w700)),
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
            value: zone.temperature != null
                ? '${zone.temperature!.toStringAsFixed(1)}°C' : '—',
            color: AppTheme.warning,
          )),
          const SizedBox(width: 10),
          Expanded(child: SensorTile(
            icon: Icons.water_drop_rounded, label: 'Humidade',
            value: zone.humidity != null
                ? '${zone.humidity!.toStringAsFixed(0)}%' : '—',
            color: AppTheme.accent,
          )),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(child: SensorTile(
            icon: Icons.wb_sunny_rounded, label: 'Luminosidade',
            value: zone.luminosity != null
                ? '${zone.luminosity!.toStringAsFixed(0)} lx' : '—',
            color: AppTheme.warning,
          )),
          const SizedBox(width: 10),
          Expanded(child: SensorTile(
            icon: Icons.motion_photos_on_rounded, label: 'Movimento',
            value: zone.motionDetected == null
                ? '—'
                : zone.motionDetected! ? 'Detetado' : 'Nenhum',
            color: zone.motionDetected == true
                ? AppTheme.success : AppTheme.textMuted,
          )),
        ],
      ),
    ],
  );
}

// ── ZoneEnergyCard — versão completa ─────────────────────────────────────────
// isAdmin: true  → mostra métricas + controlos de limite, potências e reset
// isAdmin: false → vista read-only com métricas e barra de progresso
class ZoneEnergyCard extends StatelessWidget {
  final Zone zone;
  final bool isAdmin;

  const ZoneEnergyCard({
    super.key,
    required this.zone,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    final ratio    = zone.energyUsageRatio;
    final hasLimit = zone.energyLimitWh > 0;

    Color ratioColor() {
      if (ratio == null) return AppTheme.success;
      if (ratio >= 1.0)  return AppTheme.error;
      if (ratio >= 0.9)  return AppTheme.warning;
      return AppTheme.success;
    }

    final color = ratioColor();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SS.glowCard(glowColor: color),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ────────────────────────────────────────────────────────────
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(Icons.bolt_rounded, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Consumo Energético',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14,
                      fontWeight: FontWeight.w700)),
              Text('Estimativa baseada no tempo de ativação',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
            ]),
          ),
          if (hasLimit && ratio != null && ratio >= 0.9)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Text(ratio >= 1.0 ? 'EXCEDIDO' : 'AVISO',
                  style: TextStyle(color: color, fontSize: 9,
                      fontWeight: FontWeight.w800)),
            ),
        ]),

        const SizedBox(height: 16),

        // ── Métricas ──────────────────────────────────────────────────────────
        Row(children: [
          Expanded(child: _MetricBox(
            label: 'Consumido',
            value: _formatWh(zone.energyUsageWh),
            color: color,
          )),
          if (hasLimit) ...[
            const SizedBox(width: 10),
            Expanded(child: _MetricBox(
              label: 'Limite',
              value: _formatWh(zone.energyLimitWh),
              color: AppTheme.textSecondary,
            )),
            const SizedBox(width: 10),
            Expanded(child: _MetricBox(
              label: 'Restante',
              value: zone.energyUsageWh >= zone.energyLimitWh
                  ? '0 Wh'
                  : _formatWh(zone.energyLimitWh - zone.energyUsageWh),
              color: zone.energyUsageWh >= zone.energyLimitWh
                  ? AppTheme.error
                  : AppTheme.success,
            )),
          ],
        ]),

        // ── Barra de progresso ────────────────────────────────────────────────
        if (hasLimit && ratio != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  backgroundColor: AppTheme.border,
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('${(ratio * 100).clamp(0, 999).toInt()}%',
                style: TextStyle(color: color, fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ]),
        ],

        // ── Potências nominais ────────────────────────────────────────────────
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(children: [
            _PowerChip(icon: Icons.lightbulb_rounded, label: 'LED',
                value: '${zone.actuatorConfig.ledRgbWatts.toStringAsFixed(1)} W',
                color: AppTheme.warning),
            const SizedBox(width: 8),
            Container(width: 1, height: 24, color: AppTheme.border),
            const SizedBox(width: 8),
            _PowerChip(icon: Icons.volume_up_rounded, label: 'Buzzer',
                value: '${zone.actuatorConfig.buzzerWatts.toStringAsFixed(1)} W',
                color: AppTheme.error),
            if (zone.lightOn) ...[
              const SizedBox(width: 8),
              Container(width: 1, height: 24, color: AppTheme.border),
              const SizedBox(width: 8),
              _PowerChip(icon: Icons.electric_bolt_rounded, label: 'Atual',
                  value: '${_currentPower(zone).toStringAsFixed(1)} W',
                  color: AppTheme.accent),
            ],
          ]),
        ),

        // ── Controlos admin ───────────────────────────────────────────────────
        if (isAdmin) ...[
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          const SectionLabel(label: 'Configuração'),
          const SizedBox(height: 10),
          _AdminEnergyControls(zone: zone),
        ],
      ]),
    );
  }

  double _currentPower(Zone z) {
    double w = 0;
    if (z.lightOn)  w += z.actuatorConfig.ledRgbWatts * z.lightIntensity;
    if (z.buzzerOn) w += z.actuatorConfig.buzzerWatts;
    return w;
  }

  static String _formatWh(double wh) {
    if (wh >= 1000) return '${(wh / 1000).toStringAsFixed(2)} kWh';
    if (wh >= 1)    return '${wh.toStringAsFixed(1)} Wh';
    return '${(wh * 1000).toStringAsFixed(0)} mWh';
  }
}

// ── Caixa de métrica ──────────────────────────────────────────────────────────
class _MetricBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MetricBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(children: [
      Text(value, style: TextStyle(color: color, fontSize: 15,
          fontWeight: FontWeight.w800), textAlign: TextAlign.center),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
          textAlign: TextAlign.center),
    ]),
  );
}

// ── Chip de potência ──────────────────────────────────────────────────────────
class _PowerChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _PowerChip({required this.icon, required this.label,
    required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(children: [
      Icon(icon, color: color, size: 12),
      const SizedBox(width: 4),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
        Text(value, style: TextStyle(color: color, fontSize: 11,
            fontWeight: FontWeight.w700)),
      ]),
    ]),
  );
}

// ── Controlos exclusivos do admin ─────────────────────────────────────────────
class _AdminEnergyControls extends StatelessWidget {
  final Zone zone;
  const _AdminEnergyControls({required this.zone});

  @override
  Widget build(BuildContext context) {
    final ss = context.read<SmartSpaceProvider>();

    return Column(children: [
      _AdminControlRow(
        icon: Icons.flag_rounded,
        label: 'Limite de energia',
        value: zone.energyLimitWh > 0
            ? '${zone.energyLimitWh.toStringAsFixed(0)} Wh'
            : 'Sem limite',
        color: AppTheme.warning,
        onTap: () => _showLimitDialog(context, ss),
      ),
      const SizedBox(height: 8),
      _AdminControlRow(
        icon: Icons.lightbulb_rounded,
        label: 'Potência do LED (W máx)',
        value: '${zone.actuatorConfig.ledRgbWatts.toStringAsFixed(1)} W',
        color: AppTheme.warning,
        onTap: () => _showActuatorDialog(context, ss, isLed: true),
      ),
      const SizedBox(height: 8),
      _AdminControlRow(
        icon: Icons.volume_up_rounded,
        label: 'Potência do Buzzer',
        value: '${zone.actuatorConfig.buzzerWatts.toStringAsFixed(1)} W',
        color: AppTheme.error,
        onTap: () => _showActuatorDialog(context, ss, isLed: false),
      ),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () => _confirmReset(context, ss),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.error.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.error.withOpacity(0.3)),
          ),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.restart_alt_rounded, color: AppTheme.error, size: 14),
            SizedBox(width: 6),
            Text('Fazer reset do acumulador',
                style: TextStyle(color: AppTheme.error, fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    ]);
  }

  void _showLimitDialog(BuildContext context, SmartSpaceProvider ss) {
    double limit = zone.energyLimitWh > 0 ? zone.energyLimitWh : 100.0;
    bool hasLimit = zone.energyLimitWh > 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: AppTheme.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Limite de energia',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
              'Define o limite de consumo acumulado para esta zona (Wh). '
                  'A 90% recebes um aviso. A 100% recebes um alerta crítico.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => setD(() => hasLimit = !hasLimit),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(children: [
                  const Expanded(child: Text('Ativar limite',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
                  Switch(
                    value: hasLimit,
                    onChanged: (v) => setD(() => hasLimit = v),
                    activeColor: AppTheme.warning,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ]),
              ),
            ),
            if (hasLimit) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border)),
                child: Text('${limit.toStringAsFixed(0)} Wh',
                    style: const TextStyle(color: AppTheme.textPrimary,
                        fontSize: 28, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 8),
              Slider(
                value: limit.clamp(10, 1000),
                min: 10, max: 1000, divisions: 99,
                activeColor: AppTheme.warning, inactiveColor: AppTheme.border,
                onChanged: (v) => setD(() => limit = v),
              ),
              const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('10 Wh',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                Text('1000 Wh',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
              ]),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
              onPressed: () {
                ss.setEnergyLimit(zone.id, hasLimit ? limit : 0.0);
                Navigator.pop(ctx);
              },
              child: const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showActuatorDialog(BuildContext context, SmartSpaceProvider ss,
      {required bool isLed}) {
    final current = isLed
        ? zone.actuatorConfig.ledRgbWatts
        : zone.actuatorConfig.buzzerWatts;
    double value  = current;
    final label   = isLed
        ? 'Potência do LED (W máximo a 100%)'
        : 'Potência do Buzzer (W)';
    final color   = isLed ? AppTheme.warning : AppTheme.error;
    final max     = isLed ? 20.0 : 5.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: AppTheme.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(label,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              isLed
                  ? 'Potência nominal do LED RGB a 100% de intensidade. '
                  'Usado para calcular o consumo real (W × intensidade).'
                  : 'Potência nominal do buzzer quando ativo.',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border)),
              child: Text('${value.toStringAsFixed(1)} W',
                  style: const TextStyle(color: AppTheme.textPrimary,
                      fontSize: 28, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 8),
            Slider(
              value: value.clamp(0.1, max),
              min: 0.1, max: max,
              divisions: ((max - 0.1) * 10).toInt(),
              activeColor: color, inactiveColor: AppTheme.border,
              onChanged: (v) => setD(() => value = v),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('0.1 W',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
              Text('${max.toInt()} W',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: color),
              onPressed: () {
                final newConfig = isLed
                    ? zone.actuatorConfig.copyWith(ledRgbWatts: value)
                    : zone.actuatorConfig.copyWith(buzzerWatts: value);
                ss.setActuatorConfig(zone.id, newConfig);
                Navigator.pop(ctx);
              },
              child: const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context, SmartSpaceProvider ss) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset do acumulador',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        content: Text(
          'Isto vai repor o consumo acumulado da ${zone.name} a 0 Wh '
              'e reiniciar o alerta de energia.\n\nTens a certeza?',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              ss.resetEnergyUsage(zone.id);
              Navigator.pop(ctx);
            },
            child: const Text('Fazer reset',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _AdminControlRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  final VoidCallback onTap;
  const _AdminControlRow({required this.icon, required this.label,
    required this.value, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13))),
        Text(value, style: TextStyle(color: color, fontSize: 13,
            fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        const Icon(Icons.edit_rounded, color: AppTheme.textMuted, size: 14),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

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
  const ZoneSection({super.key, required this.title, required this.child,
    this.trailing});

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
  double _hum  = 50;
  double _lux  = 300;
  bool _motion = false;

  @override
  Widget build(BuildContext context) {
    final ss = context.read<SmartSpaceProvider>();
    void inject() => ss.injectSensorData(
      widget.zoneId,
      temperature: _temp,
      humidity:    _hum,
      luminosity:  _lux,
      motion:      _motion,
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
          ZoneDemoSlider(label: 'Temperatura', value: _temp, min: 10, max: 40,
              unit: '°C', color: AppTheme.warning,
              onChanged: (v) { setState(() => _temp = v); inject(); }),
          ZoneDemoSlider(label: 'Humidade', value: _hum, min: 0, max: 100,
              unit: '%', color: AppTheme.accent,
              onChanged: (v) { setState(() => _hum = v); inject(); }),
          ZoneDemoSlider(label: 'Luminosidade', value: _lux, min: 0, max: 100,
              unit: '%', color: AppTheme.warning,
              onChanged: (v) { setState(() => _lux = v); inject(); }),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: SS.card(),
            child: Row(
              children: [
                const Icon(Icons.motion_photos_on_rounded,
                    color: AppTheme.success, size: 18),
                const SizedBox(width: 10),
                const Text('Movimento',
                    style: TextStyle(color: AppTheme.textPrimary,
                        fontSize: 13, fontWeight: FontWeight.w700)),
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
              color: AppTheme.textSecondary, fontSize: 13,
              fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('${value.toStringAsFixed(0)}$unit',
              style: TextStyle(color: color, fontSize: 13,
                  fontWeight: FontWeight.w800)),
        ],
      ),
      Slider(value: value, min: min, max: max,
          onChanged: onChanged, activeColor: color,
          inactiveColor: AppTheme.border),
    ],
  );
}