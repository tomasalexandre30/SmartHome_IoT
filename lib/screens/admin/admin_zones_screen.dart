import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/smartspace_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../models/models.dart';

class AdminZonesScreen extends StatelessWidget {
  const AdminZonesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SmartSpaceProvider>(
      builder: (context, ss, _) => Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('Gestão de Zonas')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [

            // ── Resumo ───────────────────────────────────────────────────
            _ZonesSummary(zones: ss.zones),
            const SizedBox(height: 20),

            // ── Zonas ────────────────────────────────────────────────────
            const SectionHeader(title: 'Configuração de Zonas'),
            ...ss.zones.map((z) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ZoneConfigCard(zone: z),
            )),
          ],
        ),
      ),
    );
  }
}

// ── Zones Summary ──────────────────────────────────────────────────────────────

class _ZonesSummary extends StatelessWidget {
  final List<Zone> zones;
  const _ZonesSummary({required this.zones});

  @override
  Widget build(BuildContext context) {
    final free = zones.where((z) => z.status == ZoneStatus.free).length;
    final occupied = zones.where((z) => z.status == ZoneStatus.occupied).length;
    final unknown = zones.where((z) => z.status == ZoneStatus.unknown).length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: SS.glowCard(),
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(
              value: '$occupied',
              label: 'Ocupadas',
              color: AppTheme.error,
            ),
          ),
          _divider(),
          Expanded(
            child: _SummaryItem(
              value: '$free',
              label: 'Livres',
              color: AppTheme.success,
            ),
          ),
          _divider(),
          Expanded(
            child: _SummaryItem(
              value: '$unknown',
              label: 'Desconhecidas',
              color: AppTheme.textMuted,
            ),
          ),
          _divider(),
          Expanded(
            child: _SummaryItem(
              value: '${zones.length}',
              label: 'Total',
              color: AppTheme.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
      width: 1, height: 36, color: AppTheme.border,
      margin: const EdgeInsets.symmetric(horizontal: 4));
}

class _SummaryItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _SummaryItem({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value,
          style: TextStyle(
              color: color, fontSize: 22, fontWeight: FontWeight.w800)),
      Text(label,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
          textAlign: TextAlign.center),
    ],
  );
}

// ── Zone Config Card ───────────────────────────────────────────────────────────

class _ZoneConfigCard extends StatefulWidget {
  final Zone zone;
  const _ZoneConfigCard({required this.zone});

  @override
  State<_ZoneConfigCard> createState() => _ZoneConfigCardState();
}

class _ZoneConfigCardState extends State<_ZoneConfigCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ss = context.read<SmartSpaceProvider>();
    final z = widget.zone;

    return Container(
      decoration: SS.card(accentColor: z.color),
      child: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────
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
                    child: Icon(z.icon, color: z.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(z.name,
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        Text(
                          '${z.occupantCount} ocupante${z.occupantCount != 1 ? "s" : ""} · ${z.statusLabel}',
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  ZoneStatusBadge(zone: z),
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

          // ── Expanded config ───────────────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Controlo de atuadores
                  const _SectionLabel(label: 'Atuadores'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _AdminToggleButton(
                          icon: z.lightOn
                              ? Icons.lightbulb_rounded
                              : Icons.lightbulb_outline_rounded,
                          label: 'Luz',
                          active: z.lightOn,
                          color: AppTheme.warning,
                          onTap: () => ss.toggleLight(z.id),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _AdminToggleButton(
                          icon: z.buzzerOn
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          label: 'Buzzer',
                          active: z.buzzerOn,
                          color: AppTheme.error,
                          onTap: () => ss.toggleBuzzer(z.id),
                        ),
                      ),
                    ],
                  ),

                  if (z.lightOn) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.brightness_6_rounded,
                            color: AppTheme.warning, size: 16),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Intensidade da luz',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13)),
                        ),
                        Text(
                          '${(z.lightIntensity * 100).toInt()}%',
                          style: const TextStyle(
                              color: AppTheme.warning,
                              fontSize: 13,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    Slider(
                      value: z.lightIntensity,
                      onChanged: (v) => ss.setLightIntensity(z.id, v),
                      activeColor: AppTheme.warning,
                      inactiveColor: AppTheme.border,
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Limiares de automação
                  const _SectionLabel(label: 'Limiares de Automação'),
                  const SizedBox(height: 10),
                  _ThresholdRow(
                    icon: Icons.wb_sunny_rounded,
                    label: 'Luminosidade mínima',
                    value: '300 lx',
                    color: AppTheme.warning,
                    onEdit: () => _showThresholdDialog(
                        context, 'Luminosidade mínima', '300'),
                  ),
                  const SizedBox(height: 8),
                  _ThresholdRow(
                    icon: Icons.thermostat_rounded,
                    label: 'Temperatura máxima',
                    value: '28°C',
                    color: AppTheme.error,
                    onEdit: () => _showThresholdDialog(
                        context, 'Temperatura máxima', '28'),
                  ),
                  const SizedBox(height: 8),
                  _ThresholdRow(
                    icon: Icons.water_drop_rounded,
                    label: 'Humidade máxima',
                    value: '70%',
                    color: AppTheme.accent,
                    onEdit: () => _showThresholdDialog(
                        context, 'Humidade máxima', '70'),
                  ),

                  const SizedBox(height: 16),

                  // Política de conflitos
                  const _SectionLabel(label: 'Política de Resolução de Conflitos'),
                  const SizedBox(height: 10),
                  _ConflictPolicySelector(zoneId: z.id),

                  const SizedBox(height: 16),

                  // Capacidade máxima
                  const _SectionLabel(label: 'Capacidade Máxima'),
                  const SizedBox(height: 10),
                  _CapacityRow(zone: z),

                  const SizedBox(height: 16),

                  // Consumo energético
                  const _SectionLabel(label: 'Consumo Energético'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: SS.card(),
                    child: Row(
                      children: [
                        const Icon(Icons.bolt_rounded,
                            color: AppTheme.warning, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${z.energyUsageWh.toStringAsFixed(1)} Wh',
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Text('Consumo estimado',
                                  style: TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Definir limite'),
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

  void _showThresholdDialog(
      BuildContext context, String label, String currentValue) {
    final ctrl = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Editar $label',
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Guardar')),
        ],
      ),
    );
  }
}

// ── Conflict Policy Selector ───────────────────────────────────────────────────

class _ConflictPolicySelector extends StatefulWidget {
  final String zoneId;
  const _ConflictPolicySelector({required this.zoneId});

  @override
  State<_ConflictPolicySelector> createState() =>
      _ConflictPolicySelectorState();
}

class _ConflictPolicySelectorState extends State<_ConflictPolicySelector> {
  String _selected = 'average';

  final _policies = const [
    ('average', 'Média ponderada', Icons.equalizer_rounded),
    ('priority', 'Prioridade por papel', Icons.shield_rounded),
    ('first', 'Primeiro a chegar', Icons.timer_rounded),
    ('vote', 'Votação', Icons.how_to_vote_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _policies.map((p) {
        final (id, label, icon) = p;
        final active = _selected == id;
        return GestureDetector(
          onTap: () => setState(() => _selected = id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? AppTheme.accent.withOpacity(0.12)
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? AppTheme.accent : AppTheme.border,
                width: active ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    color: active ? AppTheme.accent : AppTheme.textMuted,
                    size: 14),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color:
                    active ? AppTheme.accent : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: active
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Capacity Row ───────────────────────────────────────────────────────────────

class _CapacityRow extends StatelessWidget {
  final Zone zone;
  const _CapacityRow({required this.zone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: SS.card(),
      child: Row(
        children: [
          const Icon(Icons.groups_rounded,
              color: AppTheme.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${zone.occupantCount} / 10 pessoas',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text('Ocupação atual / capacidade máxima',
                    style: TextStyle(
                        color: AppTheme.textMuted, fontSize: 11)),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text('Editar'),
          ),
        ],
      ),
    );
  }
}

// ── Threshold Row ──────────────────────────────────────────────────────────────

class _ThresholdRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onEdit;

  const _ThresholdRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: SS.card(),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onEdit,
            child: const Icon(Icons.edit_rounded,
                color: AppTheme.textMuted, size: 16),
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
      letterSpacing: 0.8,
    ),
  );
}

// ── Admin Toggle Button ────────────────────────────────────────────────────────

class _AdminToggleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _AdminToggleButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.12) : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? color.withOpacity(0.4) : AppTheme.border,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              color: active ? color : AppTheme.textMuted, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: active ? color : AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Icon(
            active
                ? Icons.toggle_on_rounded
                : Icons.toggle_off_rounded,
            color: active ? color : AppTheme.textMuted,
            size: 26,
          ),
        ],
      ),
    ),
  );
}