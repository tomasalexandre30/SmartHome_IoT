import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/smartspace_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../models/models.dart';
import '../zone_detail_widgets.dart';

class AdminZoneDetailScreen extends StatefulWidget {
  final String zoneId;
  const AdminZoneDetailScreen({super.key, required this.zoneId});

  @override
  State<AdminZoneDetailScreen> createState() => _AdminZoneDetailScreenState();
}

class _AdminZoneDetailScreenState extends State<AdminZoneDetailScreen> {
  bool _showDemo = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<SmartSpaceProvider>(builder: (context, ss, _) {
      final zone = ss.zoneById(widget.zoneId);
      if (zone == null) {
        return const Scaffold(
          backgroundColor: AppTheme.background,
          body: Center(child: Text('Zona não encontrada',
              style: TextStyle(color: AppTheme.textPrimary))),
        );
      }

      final isCurrentZone = ss.currentZoneId == widget.zoneId;

      return Scaffold(
        backgroundColor: AppTheme.background,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: AppTheme.background,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: ZoneHeader(zone: zone, isCurrentZone: isCurrentZone),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  ZoneQuickSummary(zone: zone),
                  const SizedBox(height: 18),

                  ZoneSection(
                    title: 'Controlo',
                    child: ZoneQuickControls(zone: zone),
                  ),
                  const SizedBox(height: 18),

                  ZoneSection(
                    title: 'Sensores',
                    child: ZoneSensorDashboard(zone: zone),
                  ),
                  const SizedBox(height: 18),

                  ZoneSection(
                    title: 'Ocupantes',
                    trailing: Text(
                      '${zone.occupantCount} detetado${zone.occupantCount == 1 ? "" : "s"}',
                      style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                    child: zone.presentUsers.isEmpty
                        ? const ZoneEmptyState(
                        icon: Icons.person_off_rounded,
                        message: 'Nenhum utilizador nesta zona.')
                        : Wrap(
                      spacing: 8, runSpacing: 8,
                      children: zone.presentUsers
                          .map((u) => ZoneUserChip(name: u))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── Só admin ────────────────────────────────────────
                  ZoneSection(
                    title: 'Automações',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: SS.pill(color: const Color(0xFF8B5CF6)),
                      child: const Text('Preparado',
                          style: TextStyle(
                              color: Color(0xFF8B5CF6),
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                    child: zone.rules.isEmpty
                        ? const ZoneEmptyState(
                        icon: Icons.auto_fix_high_rounded,
                        message: 'Sem regras configuradas. Pronto para receber automações quando o ESP32 estiver ligado.')
                        : Column(
                      children: zone.rules.map((r) => _RuleRow(rule: r)).toList(),
                    ),
                  ),
                  const SizedBox(height: 18),

                  ZoneSection(
                    title: 'Política de Resolução de Conflitos',
                    child: const _ConflictPolicyCard(),
                  ),
                  const SizedBox(height: 18),

                  ZoneSection(
                    title: 'Limiares de Automação',
                    child: _ThresholdsCard(zone: zone),
                  ),
                  const SizedBox(height: 18),

                  ZoneSection(
                    title: 'Energia',
                    child: ZoneEnergyCard(zone: zone, isAdmin: true),
                  ),
                  const SizedBox(height: 18),

                  ZoneSection(
                    title: 'Modo demo',
                    trailing: TextButton.icon(
                      onPressed: () => setState(() => _showDemo = !_showDemo),
                      icon: Icon(
                        _showDemo ? Icons.visibility_off_rounded : Icons.tune_rounded,
                        size: 16, color: AppTheme.accent,
                      ),
                      label: Text(
                        _showDemo ? 'Esconder' : 'Simular',
                        style: const TextStyle(
                            color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _showDemo
                          ? ZoneDemoControls(zoneId: widget.zoneId)
                          : const ZoneDemoCollapsedCard(),
                    ),
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

class _RuleRow extends StatelessWidget {
  final AutomationRule rule;
  const _RuleRow({required this.rule});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: SS.glowCard(glowColor: rule.enabled ? const Color(0xFF8B5CF6) : null),
    child: Row(
      children: [
        const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF8B5CF6), size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(rule.label,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: SS.pill(
              color: rule.enabled ? const Color(0xFF8B5CF6) : AppTheme.textMuted),
          child: Text(rule.enabled ? 'Ativa' : 'Inativa',
              style: TextStyle(
                  color: rule.enabled ? const Color(0xFF8B5CF6) : AppTheme.textMuted,
                  fontSize: 10, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

class _ConflictPolicyCard extends StatefulWidget {
  const _ConflictPolicyCard();

  @override
  State<_ConflictPolicyCard> createState() => _ConflictPolicyCardState();
}

class _ConflictPolicyCardState extends State<_ConflictPolicyCard> {
  String _selected = 'average';

  final _policies = const [
    ('average', 'Média ponderada', Icons.equalizer_rounded),
    ('priority', 'Prioridade por papel', Icons.shield_rounded),
    ('first', 'Primeiro a chegar', Icons.timer_rounded),
    ('vote', 'Votação', Icons.how_to_vote_rounded),
  ];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: SS.card(),
    child: Wrap(
      spacing: 8, runSpacing: 8,
      children: _policies.map((p) {
        final (id, label, icon) = p;
        final active = _selected == id;
        return GestureDetector(
          onTap: () => setState(() => _selected = id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: active ? AppTheme.accent.withOpacity(0.12) : AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: active ? AppTheme.accent : AppTheme.border,
                  width: active ? 1.5 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    color: active ? AppTheme.accent : AppTheme.textMuted, size: 14),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: active ? AppTheme.accent : AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
              ],
            ),
          ),
        );
      }).toList(),
    ),
  );
}

class _ThresholdsCard extends StatelessWidget {
  final Zone zone;
  const _ThresholdsCard({required this.zone});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: SS.card(),
    child: Column(
      children: [
        _ThreshRow(icon: Icons.wb_sunny_rounded, label: 'Luminosidade mínima',
            value: '300 lx', color: AppTheme.warning,
            onEdit: () => _showDialog(context, 'Luminosidade mínima', '300')),
        const Divider(height: 20),
        _ThreshRow(icon: Icons.thermostat_rounded, label: 'Temperatura máxima',
            value: '28°C', color: AppTheme.error,
            onEdit: () => _showDialog(context, 'Temperatura máxima', '28')),
        const Divider(height: 20),
        _ThreshRow(icon: Icons.water_drop_rounded, label: 'Humidade máxima',
            value: '70%', color: AppTheme.accent,
            onEdit: () => _showDialog(context, 'Humidade máxima', '70')),
      ],
    ),
  );

  void _showDialog(BuildContext context, String label, String current) {
    final ctrl = TextEditingController(text: current);
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Guardar')),
        ],
      ),
    );
  }
}

class _ThreshRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onEdit;

  const _ThreshRow({required this.icon, required this.label,
    required this.value, required this.color, required this.onEdit});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 10),
      Expanded(child: Text(label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
      Text(value, style: TextStyle(
          color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: onEdit,
        child: const Icon(Icons.edit_rounded, color: AppTheme.textMuted, size: 16),
      ),
    ],
  );
}