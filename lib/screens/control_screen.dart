import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/smartspace_provider.dart';
import '../services/beacon_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../models/models.dart';

class ControlScreen extends StatelessWidget {
  const ControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<SmartSpaceProvider, BeaconService>(
      builder: (context, ss, ble, _) => Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Controlo'),
          actions: [
            _ManualZoneSelector(
              zones: ss.zones,
              currentZoneId: ss.currentZoneId,
              onSelect: (id) => ss.updateZoneFromBeacon(id),
            ),
          ],
        ),
        body: ss.zones.isEmpty
            ? const Center(child: Text('Sem zonas configuradas'))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: ss.zones.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _ZoneControlCard(zone: ss.zones[i], isCurrentZone: ss.currentZoneId == ss.zones[i].id),
                ),
              ),
      ),
    );
  }
}

// ── Zone Control Card ─────────────────────────────────────────────────────────

class _ZoneControlCard extends StatelessWidget {
  final Zone zone;
  final bool isCurrentZone;
  const _ZoneControlCard({required this.zone, required this.isCurrentZone});

  @override
  Widget build(BuildContext context) {
    final ss = context.read<SmartSpaceProvider>();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCurrentZone ? zone.color : AppTheme.border, width: isCurrentZone ? 1.5 : 1),
        boxShadow: isCurrentZone ? [BoxShadow(color: zone.color.withOpacity(0.15), blurRadius: 20)] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: zone.color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: Icon(zone.icon, color: zone.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(zone.name, style: Theme.of(context).textTheme.titleMedium),
                      Text('${zone.occupantCount} ocupante${zone.occupantCount != 1 ? "s" : ""}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                if (isCurrentZone)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: SS.pill(color: zone.color),
                    child: Text('Aqui', style: TextStyle(color: zone.color, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Quick commands
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Comandos Rápidos', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _CommandButton(
                      icon: zone.lightOn ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded,
                      label: zone.lightOn ? 'Apagar Luz' : 'Ligar Luz',
                      color: AppTheme.warning,
                      active: zone.lightOn,
                      onTap: () => ss.toggleLight(zone.id),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _CommandButton(
                      icon: zone.buzzerOn ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      label: zone.buzzerOn ? 'Calar Buzzer' : 'Ativar Buzzer',
                      color: AppTheme.error,
                      active: zone.buzzerOn,
                      onTap: () => ss.toggleBuzzer(zone.id),
                    )),
                  ],
                ),
                if (zone.lightOn) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.brightness_6_rounded, color: AppTheme.textMuted, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Slider(
                          value: zone.lightIntensity,
                          onChanged: (v) => ss.setLightIntensity(zone.id, v),
                          activeColor: AppTheme.warning,
                          inactiveColor: AppTheme.border,
                        ),
                      ),
                      const Icon(Icons.brightness_7_rounded, color: AppTheme.warning, size: 16),
                    ],
                  ),
                ],

                // Sensor summary
                if (zone.temperature != null || zone.luminosity != null) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (zone.temperature != null) ...[
                        const Icon(Icons.thermostat_rounded, color: AppTheme.warning, size: 14),
                        const SizedBox(width: 4),
                        Text('${zone.temperature!.toStringAsFixed(1)}°C', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        const SizedBox(width: 12),
                      ],
                      if (zone.humidity != null) ...[
                        const Icon(Icons.water_drop_rounded, color: AppTheme.accent, size: 14),
                        const SizedBox(width: 4),
                        Text('${zone.humidity!.toStringAsFixed(0)}%', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        const SizedBox(width: 12),
                      ],
                      if (zone.luminosity != null) ...[
                        const Icon(Icons.wb_sunny_rounded, color: AppTheme.warning, size: 14),
                        const SizedBox(width: 4),
                        Text('${zone.luminosity!.toStringAsFixed(0)} lx', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _CommandButton({required this.icon, required this.label, required this.color,
      required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.15) : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? color.withOpacity(0.4) : AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: active ? color : AppTheme.textMuted, size: 22),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(
            color: active ? color : AppTheme.textMuted,
            fontSize: 12, fontWeight: FontWeight.w500,
          ), textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

// ── Manual Zone Selector ──────────────────────────────────────────────────────

class _ManualZoneSelector extends StatelessWidget {
  final List<Zone> zones;
  final String? currentZoneId;
  final ValueChanged<String?> onSelect;

  const _ManualZoneSelector({required this.zones, this.currentZoneId, required this.onSelect});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.room_rounded, color: AppTheme.accent),
    tooltip: 'Simular zona',
    onPressed: () => showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Simular zona atual', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Para testes sem beacons físicos', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 16),
            ...zones.map((z) => ListTile(
              leading: Icon(z.icon, color: z.color),
              title: Text(z.name, style: const TextStyle(color: AppTheme.textPrimary)),
              trailing: currentZoneId == z.id
                  ? const Icon(Icons.check_circle_rounded, color: AppTheme.success)
                  : null,
              onTap: () {
                onSelect(z.id);
                Navigator.pop(context);
              },
            )),
            ListTile(
              leading: const Icon(Icons.clear_rounded, color: AppTheme.textMuted),
              title: const Text('Nenhuma zona', style: TextStyle(color: AppTheme.textMuted)),
              onTap: () { onSelect(null); Navigator.pop(context); },
            ),
          ],
        ),
      ),
    ),
  );
}
