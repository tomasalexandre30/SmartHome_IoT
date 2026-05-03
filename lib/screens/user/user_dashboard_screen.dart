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
  bool showBleDebug = false;

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
                    child: const Icon(Icons.hub_rounded,
                        color: Colors.white, size: 18),
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
                        ble.scanning
                            ? 'BLE ativo · A detetar zona'
                            : 'BLE parado',
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

                  // ── Zona atual ───────────────────────────────────────
                  _UserLocationCard(
                    currentZone: currentZone,
                    currentBeacon: currentBeacon,
                    scanning: ble.scanning,
                    zones: ss.zones,
                  ),
                  const SizedBox(height: 20),

                  // ── Mapa de zonas ────────────────────────────────────
                  const SectionHeader(title: 'Zonas'),
                  ...ss.zones.map((z) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ZoneCard(
                      zone: z,
                      isCurrentZone: z.id == currentZoneId,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              UserZoneDetailScreen(zoneId: z.id),
                        ),
                      ),
                    ),
                  )),

                  const SizedBox(height: 20),

                  // ── Atividade recente (só do utilizador) ─────────────
                  SectionHeader(
                    title: 'A minha atividade',
                    trailing: Text(
                      '${ss.logs.length} eventos',
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ),
                  ...ss.logs.take(5).map((e) => LogTile(event: e)),
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

// ── User Location Card ─────────────────────────────────────────────────────────

class _UserLocationCard extends StatelessWidget {
  final Zone? currentZone;
  final Beacon? currentBeacon;
  final bool scanning;
  final List<Zone> zones;

  const _UserLocationCard({
    required this.currentZone,
    required this.currentBeacon,
    required this.scanning,
    required this.zones,
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
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                scanning
                    ? Icons.bluetooth_searching_rounded
                    : Icons.location_off_rounded,
                color: scanning ? AppTheme.accent : AppTheme.textMuted,
                size: 32,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scanning
                        ? 'A localizar-te...'
                        : 'Localização desconhecida',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    scanning
                        ? 'A ler os beacons BLE próximos'
                        : 'Ativa o BLE para detetar a tua zona',
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SS.glowCard(glowColor: currentZone!.color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Estás em',
              style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: currentZone!.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(currentZone!.icon,
                    color: currentZone!.color, size: 32),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentZone!.name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentBeacon != null
                          ? '${currentBeacon!.rssi} dBm · ${currentBeacon!.distance.toStringAsFixed(1)} m'
                          : 'Sinal BLE não disponível',
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              ZoneStatusBadge(zone: currentZone!),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SensorTile(
                  icon: Icons.thermostat_rounded,
                  label: 'Temp.',
                  value: currentZone!.temperature != null
                      ? '${currentZone!.temperature!.toStringAsFixed(1)}°C'
                      : '—',
                  color: AppTheme.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SensorTile(
                  icon: Icons.water_drop_rounded,
                  label: 'Hum.',
                  value: currentZone!.humidity != null
                      ? '${currentZone!.humidity!.toStringAsFixed(0)}%'
                      : '—',
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SensorTile(
                  icon: Icons.wb_sunny_rounded,
                  label: 'Luz',
                  value: currentZone!.luminosity != null
                      ? '${currentZone!.luminosity!.toStringAsFixed(0)} lx'
                      : '—',
                  color: AppTheme.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

