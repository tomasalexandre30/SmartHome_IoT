import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/smartspace_provider.dart';
import '../../services/beacon_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../models/models.dart';
import 'admin_zone_detail_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<SmartSpaceProvider, BeaconService>(
      builder: (context, ss, ble, _) {
        final auth = context.watch<AuthService>();
        final occupiedZones =
            ss.zones.where((z) => z.status == ZoneStatus.occupied).length;
        final totalOccupants =
        ss.zones.fold<int>(0, (s, z) => s + z.occupantCount);
        final activeLights = ss.zones.where((z) => z.lightOn).length;
        final activeBuzzers = ss.zones.where((z) => z.buzzerOn).length;

        return CustomScrollView(
          slivers: [
            // ── AppBar ───────────────────────────────────────────────────
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
                    child: const Icon(Icons.shield_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SmartSpace Admin',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary)),
                      Text(
                        ble.scanning ? 'BLE ativo · Sistema online' : 'BLE parado',
                        style: TextStyle(
                          fontSize: 11,
                          color: ble.scanning
                              ? AppTheme.success
                              : AppTheme.textMuted,
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
                  onPressed: () => ble.scanning
                      ? ble.stopScanning()
                      : ble.startScanning(),
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

                  // ── Boas-vindas ──────────────────────────────────────
                  _WelcomeBanner(name: auth.appUser?.displayName ?? 'Admin'),
                  const SizedBox(height: 16),

                  // ── Stats globais ────────────────────────────────────
                  _GlobalStatsGrid(
                    occupiedZones: occupiedZones,
                    totalZones: ss.zones.length,
                    totalOccupants: totalOccupants,
                    activeLights: activeLights,
                    activeBuzzers: activeBuzzers,
                  ),
                  const SizedBox(height: 20),

                  // ── Todas as zonas ───────────────────────────────────
                  const SectionHeader(title: 'Todas as Zonas'),
                  ...ss.zones.map((z) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AdminZoneCard(zone: z, ble: ble),
                  )),

                  const SizedBox(height: 20),

                  // ── Logs recentes (todos) ────────────────────────────
                  SectionHeader(
                    title: 'Atividade Global',
                    trailing: Text(
                      '${ss.logs.length} eventos',
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ),
                  ...ss.logs.take(8).map((e) => LogTile(event: e)),

                  if (ss.logs.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Nenhum evento ainda',
                            style: TextStyle(color: AppTheme.textMuted)),
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

// ── Welcome Banner ─────────────────────────────────────────────────────────────

class _WelcomeBanner extends StatelessWidget {
  final String name;
  const _WelcomeBanner({required this.name});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Bom dia'
        : hour < 18
        ? 'Boa tarde'
        : 'Boa noite';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: SS.glowCard(glowColor: AppTheme.accent),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.accent.withOpacity(0.25), width: 1.5),
            ),
            child: Center(
              child: Text(
                name[0].toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 20,
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
                  '$greeting, $name!',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Painel de administração SmartSpace',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.accentLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.accentBorder),
            ),
            child: const Text(
              '⚡ Admin',
              style: TextStyle(
                color: AppTheme.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Global Stats Grid ──────────────────────────────────────────────────────────

class _GlobalStatsGrid extends StatelessWidget {
  final int occupiedZones;
  final int totalZones;
  final int totalOccupants;
  final int activeLights;
  final int activeBuzzers;

  const _GlobalStatsGrid({
    required this.occupiedZones,
    required this.totalZones,
    required this.totalOccupants,
    required this.activeLights,
    required this.activeBuzzers,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.meeting_room_rounded,
                label: 'Zonas ocupadas',
                value: '$occupiedZones/$totalZones',
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.groups_rounded,
                label: 'Ocupantes totais',
                value: '$totalOccupants',
                color: AppTheme.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.lightbulb_rounded,
                label: 'Luzes ativas',
                value: '$activeLights',
                color: AppTheme.warning,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.volume_up_rounded,
                label: 'Buzzers ativos',
                value: '$activeBuzzers',
                color: AppTheme.error,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SS.card(accentColor: color),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Admin Zone Card ────────────────────────────────────────────────────────────

class _AdminZoneCard extends StatelessWidget {
  final Zone zone;
  final BeaconService ble;

  const _AdminZoneCard({required this.zone, required this.ble});

  @override
  Widget build(BuildContext context) {
    final ss = context.read<SmartSpaceProvider>();
    final beacon =
        ble.beacons.where((b) => b.zoneId == zone.id).firstOrNull;

    return Container(
      decoration: SS.card(accentColor: zone.color),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => AdminZoneDetailScreen(zoneId: zone.id)),
            ),
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: zone.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(zone.icon, color: zone.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(zone.name,
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          '${zone.occupantCount} ocupante${zone.occupantCount != 1 ? "s" : ""}'
                              '${zone.presentUsers.isNotEmpty ? " · ${zone.presentUsers.join(", ")}" : ""}',
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  ZoneStatusBadge(zone: zone),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppTheme.textMuted, size: 18),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // Controlo rápido admin
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Sensores
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (zone.temperature != null)
                        _MiniChip(
                          icon: Icons.thermostat_rounded,
                          value:
                          '${zone.temperature!.toStringAsFixed(1)}°C',
                          color: AppTheme.warning,
                        ),
                      if (zone.humidity != null)
                        _MiniChip(
                          icon: Icons.water_drop_rounded,
                          value: '${zone.humidity!.toStringAsFixed(0)}%',
                          color: AppTheme.accent,
                        ),
                      if (zone.luminosity != null)
                        _MiniChip(
                          icon: Icons.wb_sunny_rounded,
                          value:
                          '${zone.luminosity!.toStringAsFixed(0)}lx',
                          color: AppTheme.warning,
                        ),
                      if (zone.temperature == null &&
                          zone.humidity == null &&
                          zone.luminosity == null)
                        const _MiniChip(
                          icon: Icons.sensors_off_rounded,
                          value: 'Sem dados',
                          color: AppTheme.textMuted,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Controlos rápidos
                Row(
                  children: [
                    _QuickToggle(
                      icon: zone.lightOn
                          ? Icons.lightbulb_rounded
                          : Icons.lightbulb_outline_rounded,
                      active: zone.lightOn,
                      color: AppTheme.warning,
                      onTap: () => ss.toggleLight(zone.id),
                    ),
                    const SizedBox(width: 8),
                    _QuickToggle(
                      icon: zone.buzzerOn
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      active: zone.buzzerOn,
                      color: AppTheme.error,
                      onTap: () => ss.toggleBuzzer(zone.id),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // BLE info
          if (beacon != null && beacon.isNearby)
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.accentLight,
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bluetooth_searching_rounded,
                      color: AppTheme.accent, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    '${beacon.name} · ${beacon.rssi} dBm · ${beacon.distance.toStringAsFixed(1)}m',
                    style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(beacon.signalBar,
                      style: TextStyle(
                          color: beacon.signalColor, fontSize: 11)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _MiniChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: SS.pill(color: color),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 4),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _QuickToggle extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _QuickToggle({
    required this.icon,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.15) : AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: active
                ? color.withOpacity(0.4)
                : AppTheme.border),
      ),
      child: Icon(icon,
          color: active ? color : AppTheme.textMuted, size: 18),
    ),
  );
}

