import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/smartspace_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

// ── ZoneEnergyCard ────────────────────────────────────────────────────────────
// Widget reutilizável para mostrar o consumo energético de uma zona.
// isAdmin: true  → mostra controlos de limite, potências e reset
// isAdmin: false → vista read-only com métricas
//
// Uso na _ConfiguracaoTab (admin_zones_screen.dart):
//   ZoneEnergyCard(zone: z, isAdmin: true)
//
// Uso no dashboard do user (se quiseres mostrar energia):
//   ZoneEnergyCard(zone: z, isAdmin: false)

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
    final ratio = zone.energyUsageRatio; // null se sem limite
    final hasLimit = zone.energyLimitWh > 0;

    // Cor do indicador consoante consumo
    Color _ratioColor() {
      if (ratio == null) return AppTheme.accent;
      if (ratio >= 1.0) return AppTheme.error;
      if (ratio >= 0.9) return AppTheme.warning;
      return AppTheme.success;
    }

    final ratioColor = _ratioColor();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SS.glowCard(glowColor: ratioColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: ratioColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ratioColor.withOpacity(0.3)),
              ),
              child: Icon(Icons.bolt_rounded, color: ratioColor, size: 18),
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
            // Badge de alerta se perto/acima do limite
            if (hasLimit && ratio != null && ratio >= 0.9)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ratioColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ratioColor.withOpacity(0.4)),
                ),
                child: Text(
                  ratio >= 1.0 ? 'EXCEDIDO' : 'AVISO',
                  style: TextStyle(color: ratioColor, fontSize: 9,
                      fontWeight: FontWeight.w800),
                ),
              ),
          ]),

          const SizedBox(height: 16),

          // ── Métricas principais ─────────────────────────────────────────────
          Row(children: [
            Expanded(child: _MetricBox(
              label: 'Consumido',
              value: _formatWh(zone.energyUsageWh),
              color: ratioColor,
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

          // ── Barra de progresso (só com limite definido) ─────────────────────
          if (hasLimit && ratio != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio.clamp(0.0, 1.0),
                    backgroundColor: AppTheme.border,
                    valueColor: AlwaysStoppedAnimation(ratioColor),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(ratio * 100).clamp(0, 999).toInt()}%',
                style: TextStyle(
                    color: ratioColor, fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ]),
          ],

          // ── Potências nominais (read-only, sempre visível) ──────────────────
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(children: [
              _PowerChip(
                icon: Icons.lightbulb_rounded,
                label: 'LED',
                value: '${zone.actuatorConfig.ledRgbWatts.toStringAsFixed(1)} W',
                color: AppTheme.warning,
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 24, color: AppTheme.border),
              const SizedBox(width: 8),
              _PowerChip(
                icon: Icons.volume_up_rounded,
                label: 'Buzzer',
                value: '${zone.actuatorConfig.buzzerWatts.toStringAsFixed(1)} W',
                color: AppTheme.error,
              ),
              if (zone.lightOn) ...[
                const SizedBox(width: 8),
                Container(width: 1, height: 24, color: AppTheme.border),
                const SizedBox(width: 8),
                _PowerChip(
                  icon: Icons.electric_bolt_rounded,
                  label: 'Atual',
                  value: '${_currentPower(zone).toStringAsFixed(1)} W',
                  color: AppTheme.accent,
                ),
              ],
            ]),
          ),

          // ── Controlos admin ─────────────────────────────────────────────────
          if (isAdmin) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            const SectionLabel(label: 'Configuração'),
            const SizedBox(height: 10),
            _AdminEnergyControls(zone: zone),
          ],
        ],
      ),
    );
  }

  double _currentPower(Zone z) {
    double w = 0;
    if (z.lightOn) w += z.actuatorConfig.ledRgbWatts * z.lightIntensity;
    if (z.buzzerOn) w += z.actuatorConfig.buzzerWatts;
    return w;
  }

  String _formatWh(double wh) {
    if (wh >= 1000) return '${(wh / 1000).toStringAsFixed(2)} kWh';
    if (wh >= 1) return '${wh.toStringAsFixed(1)} Wh';
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
      Text(value,
          style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800),
          textAlign: TextAlign.center),
      const SizedBox(height: 2),
      Text(label,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
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
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
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

      // ── Limite de energia ──────────────────────────────────────────────────
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

      // ── Potência LED ───────────────────────────────────────────────────────
      _AdminControlRow(
        icon: Icons.lightbulb_rounded,
        label: 'Potência do LED (W máx)',
        value: '${zone.actuatorConfig.ledRgbWatts.toStringAsFixed(1)} W',
        color: AppTheme.warning,
        onTap: () => _showActuatorDialog(context, ss, isLed: true),
      ),

      const SizedBox(height: 8),

      // ── Potência Buzzer ────────────────────────────────────────────────────
      _AdminControlRow(
        icon: Icons.volume_up_rounded,
        label: 'Potência do Buzzer',
        value: '${zone.actuatorConfig.buzzerWatts.toStringAsFixed(1)} W',
        color: AppTheme.error,
        onTap: () => _showActuatorDialog(context, ss, isLed: false),
      ),

      const SizedBox(height: 12),

      // ── Reset ──────────────────────────────────────────────────────────────
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

  // ── Dialog: limite de energia ───────────────────────────────────────────────
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
                  'Ao atingir 90% recebes um aviso. Ao atingir 100% recebes um alerta crítico.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Toggle sem limite / com limite
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
                min: 10, max: 1000,
                divisions: 99,
                activeColor: AppTheme.warning,
                inactiveColor: AppTheme.border,
                onChanged: (v) => setD(() => limit = v),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
                Text('10 Wh', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                Text('1000 Wh', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
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

  // ── Dialog: potência dos atuadores ─────────────────────────────────────────
  void _showActuatorDialog(BuildContext context, SmartSpaceProvider ss,
      {required bool isLed}) {
    final current = isLed
        ? zone.actuatorConfig.ledRgbWatts
        : zone.actuatorConfig.buzzerWatts;
    double value = current;
    final label = isLed ? 'Potência do LED (W máximo a 100%)' : 'Potência do Buzzer (W)';
    final color = isLed ? AppTheme.warning : AppTheme.error;
    final max = isLed ? 20.0 : 5.0;

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
              activeColor: color,
              inactiveColor: AppTheme.border,
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

  // ── Confirmação de reset ────────────────────────────────────────────────────
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
            child: const Text('Fazer reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Linha de controlo admin ───────────────────────────────────────────────────

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
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
        Text(value,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        const Icon(Icons.edit_rounded, color: AppTheme.textMuted, size: 14),
      ]),
    ),
  );
}