import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/smartspace_provider.dart';
import '../../services/beacon_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../models/models.dart';
import 'user_zone_detail_screen.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer2<SmartSpaceProvider, BeaconService>(
      builder: (context, ss, ble, _) {
        final auth = context.watch<AuthService>();
        final currentZoneId = ble.currentZoneId ?? ss.currentZoneId;
        final currentZone =
            ss.zones.where((z) => z.id == currentZoneId).firstOrNull;
        final currentBeacon = currentZone == null
            ? null
            : ble.beacons.where((b) => b.zoneId == currentZone.id).firstOrNull;

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: AppTheme.background,
              elevation: 0,
              title: Row(
                children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.hub_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Olá, ${auth.appUser?.displayName ?? "Utilizador"}!',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        ble.scanning ? 'BLE ativo · A detetar zona' : 'BLE parado',
                        style: TextStyle(
                          fontSize: 11,
                          color: ble.scanning ? AppTheme.success : AppTheme.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    ble.scanning
                        ? Icons.bluetooth_searching_rounded
                        : Icons.bluetooth_disabled_rounded,
                    color: ble.scanning ? AppTheme.accent : AppTheme.textMuted,
                  ),
                  onPressed: () =>
                  ble.scanning ? ble.stopScanning() : ble.startScanning(),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: Consumer<SmartSpaceProvider>(
                  builder: (context, ss, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConnectionBanner(connected: ss.isConnected),
                      ReconnectedBanner(connected: ss.isConnected),
                    ],
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  _UserLocationCard(
                    currentZone: currentZone,
                    currentBeacon: currentBeacon,
                    scanning: ble.scanning,
                  ),
                  const SizedBox(height: 24),

                  SectionHeader(
                    title: 'Zonas',
                    trailing: Text(
                      '${ss.zones.where((z) => z.status == ZoneStatus.occupied).length}/${ss.zones.length} ocupadas',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...ss.zones.map((z) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ZoneRowCard(
                      zone: z,
                      isCurrentZone: z.id == currentZoneId,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserZoneDetailScreen(zoneId: z.id),
                        ),
                      ),
                    ),
                  )),

                  const SizedBox(height: 24),

                  SectionHeader(
                    title: 'Atividade recente',
                    trailing: Text(
                      '${ss.logs.length} eventos',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (ss.logs.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: SS.card(),
                      child: const Column(
                        children: [
                          Icon(Icons.history_rounded, color: AppTheme.textMuted, size: 32),
                          SizedBox(height: 8),
                          Text('Nenhum evento ainda',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                        ],
                      ),
                    )
                  else
                    Container(
                      decoration: SS.card(),
                      child: Column(
                        children: ss.logs.take(5).toList().asMap().entries.map((entry) {
                          final i = entry.key;
                          final e = entry.value;
                          return Column(
                            children: [
                              if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                              LogTile(event: e),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── User Location Card ─────────────────────────────────────────────────────────

class _UserLocationCard extends StatelessWidget {
  final Zone? currentZone;
  final Beacon? currentBeacon;
  final bool scanning;

  const _UserLocationCard({
    required this.currentZone,
    required this.currentBeacon,
    required this.scanning,
  });

  @override
  Widget build(BuildContext context) {
    if (currentZone == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: SS.glowCard(),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                scanning ? Icons.bluetooth_searching_rounded : Icons.location_off_rounded,
                color: scanning ? AppTheme.accent : AppTheme.textMuted,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scanning ? 'A localizar-te...' : 'Localização desconhecida',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    scanning
                        ? 'A ler os beacons BLE próximos'
                        : 'Ativa o BLE para detetar a tua zona',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final zone = currentZone!;

    return Container(
      decoration: SS.glowCard(glowColor: zone.color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: zone.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(zone.icon, color: zone.color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Estás em',
                          style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(zone.name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          )),
                      if (currentBeacon != null)
                        Text(
                          '${currentBeacon!.rssi} dBm · ${currentBeacon!.distance.toStringAsFixed(1)} m',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                ZoneStatusBadge(zone: zone),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(
              children: [
                Expanded(child: _SensorMini(
                  icon: Icons.thermostat_rounded,
                  label: 'Temp.',
                  value: zone.temperature != null
                      ? '${zone.temperature!.toStringAsFixed(1)}°C' : '—',
                  color: AppTheme.warning,
                  hasData: zone.temperature != null,
                )),
                const SizedBox(width: 8),
                Expanded(child: _SensorMini(
                  icon: Icons.water_drop_rounded,
                  label: 'Hum.',
                  value: zone.humidity != null
                      ? '${zone.humidity!.toStringAsFixed(0)}%' : '—',
                  color: AppTheme.accent,
                  hasData: zone.humidity != null,
                )),
                const SizedBox(width: 8),
                Expanded(child: _SensorMini(
                  icon: Icons.wb_sunny_rounded,
                  label: 'Luz',
                  value: zone.luminosity != null
                      ? '${zone.luminosity!.toStringAsFixed(0)} lx' : '—',
                  color: const Color(0xFFFFB830),
                  hasData: zone.luminosity != null,
                )),
                const SizedBox(width: 8),
                Expanded(child: _SensorMini(
                  icon: Icons.people_rounded,
                  label: 'Ocup.',
                  value: '${zone.occupantCount}',
                  color: AppTheme.success,
                  hasData: true,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sensor Mini ────────────────────────────────────────────────────────────────

class _SensorMini extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool hasData;

  const _SensorMini({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.hasData,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = hasData ? color : AppTheme.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: hasData ? color.withOpacity(0.08) : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasData ? color.withOpacity(0.2) : AppTheme.border,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: effectiveColor, size: 18),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                color: effectiveColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              )),
          Text(label,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Zone Row Card ──────────────────────────────────────────────────────────────

class _ZoneRowCard extends StatelessWidget {
  final Zone zone;
  final bool isCurrentZone;
  final VoidCallback onTap;

  const _ZoneRowCard({
    required this.zone,
    required this.isCurrentZone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrentZone ? zone.color.withOpacity(0.5) : AppTheme.border,
            width: isCurrentZone ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: zone.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(zone.icon, color: zone.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(zone.name,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      if (isCurrentZone) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: zone.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Aqui',
                              style: TextStyle(
                                  color: zone.color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.people_rounded, size: 12, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${zone.occupantCount} ocupante${zone.occupantCount != 1 ? "s" : ""}',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                      if (zone.lightOn) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.lightbulb_rounded, size: 12, color: AppTheme.warning),
                        const SizedBox(width: 3),
                        const Text('Luz',
                            style: TextStyle(color: AppTheme.warning, fontSize: 12)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            ZoneStatusBadge(zone: zone),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}