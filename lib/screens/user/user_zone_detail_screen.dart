import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/smartspace_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../models/models.dart';
import '../zone_detail_widgets.dart';

class UserZoneDetailScreen extends StatefulWidget {
  final String zoneId;
  const UserZoneDetailScreen({super.key, required this.zoneId});

  @override
  State<UserZoneDetailScreen> createState() => _UserZoneDetailScreenState();
}

class _UserZoneDetailScreenState extends State<UserZoneDetailScreen> {
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
                    title: 'Controlo on-demand',
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
                        message: 'Nenhum utilizador detetado nesta zona.')
                        : Wrap(
                      spacing: 8, runSpacing: 8,
                      children: zone.presentUsers
                          .map((u) => ZoneUserChip(name: u))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ZoneSection(
                    title: 'Energia',
                    child: ZoneEnergyCard(zone: zone),
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