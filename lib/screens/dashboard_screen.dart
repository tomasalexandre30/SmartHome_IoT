import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/smartspace_provider.dart';
import '../services/beacon_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../models/models.dart';
import 'zone_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool showBleDebug = false;

  @override
  Widget build(BuildContext context) {
    return Consumer2<SmartSpaceProvider, BeaconService>(
      builder: (context, ss, ble, _) {
        final currentZoneId = ble.currentZoneId ?? ss.currentZoneId;
        final currentZone = ss.zones.where((z) => z.id == currentZoneId).firstOrNull;

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
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.location_city_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SmartSpace',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        ble.scanning ? 'BLE ativo · Sistema online' : 'BLE parado',
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
                  onPressed: () => ble.scanning ? ble.stopScanning() : ble.startScanning(),
                  tooltip: ble.scanning ? 'Parar scan BLE' : 'Iniciar scan BLE',
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: ConnectionBanner(connected: ss.isConnected),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _SystemOverviewCard(
                    currentZone: currentZone,
                    currentBeacon: currentBeacon,
                    scanning: ble.scanning,
                    zones: ss.zones,
                  ),

                  const SizedBox(height: 20),

                  const SectionHeader(title: 'Zonas'),
                  const SizedBox(height: 4),

                  ...ss.zones.map(
                        (z) {
                      final beacon = ble.beacons
                          .where((b) => b.zoneId == z.id)
                          .firstOrNull;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ZoneCard(
                          zone: z,
                          isCurrentZone: z.id == currentZoneId,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ZoneDetailScreen(zoneId: z.id),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  SectionHeader(
                    title: 'Debug BLE',
                    trailing: TextButton.icon(
                      onPressed: () {
                        setState(() => showBleDebug = !showBleDebug);
                      },
                      icon: Icon(
                        showBleDebug
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 16,
                        color: AppTheme.accent,
                      ),
                      label: Text(
                        showBleDebug ? 'Esconder' : 'Mostrar',
                        style: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  if (showBleDebug) ...[
                    _BleDebugHeader(
                      scanning: ble.scanning,
                      onTap: () => ble.scanning
                          ? ble.stopScanning()
                          : ble.startScanning(),
                    ),
                    const SizedBox(height: 10),
                    ...ble.beacons.map(
                          (b) => BeaconSignalRow(
                        beacon: b,
                        isActive: b.zoneId == currentZoneId,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  SectionHeader(
                    title: 'Atividade Recente',
                    trailing: TextButton(
                      onPressed: () {},
                      child: const Text(
                        'Ver tudo',
                        style: TextStyle(
                          color: AppTheme.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  ...ss.logs.take(5).map((e) => LogTile(event: e)),

                  if (ss.logs.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Nenhum evento ainda',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
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

class _SystemOverviewCard extends StatelessWidget {
  final Zone? currentZone;
  final Beacon? currentBeacon;
  final bool scanning;
  final List<Zone> zones;

  const _SystemOverviewCard({
    required this.currentZone,
    required this.currentBeacon,
    required this.scanning,
    required this.zones,
  });

  @override
  Widget build(BuildContext context) {
    final occupiedZones = zones.where((z) => z.status == ZoneStatus.occupied).length;
    final totalOccupants = zones.fold<int>(0, (sum, z) => sum + z.occupantCount);

    if (currentZone == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: SS.glowCard(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        scanning ? 'A procurar localização...' : 'Localização desconhecida',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        scanning
                            ? 'A ler os sinais dos beacons BLE próximos'
                            : 'Ativa o scan BLE para detetar a tua zona',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _OverviewStats(
              occupiedZones: occupiedZones,
              totalOccupants: totalOccupants,
              signalLabel: 'Sem zona',
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
          const Text(
            'Zona atual',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: currentZone!.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  currentZone!.icon,
                  color: currentZone!.color,
                  size: 32,
                ),
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
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              ZoneStatusBadge(zone: currentZone!),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 16),

          _OverviewStats(
            occupiedZones: occupiedZones,
            totalOccupants: totalOccupants,
            signalLabel: currentBeacon != null ? currentBeacon!.signalBar : '—',
          ),

          const SizedBox(height: 16),

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

class _OverviewStats extends StatelessWidget {
  final int occupiedZones;
  final int totalOccupants;
  final String signalLabel;

  const _OverviewStats({
    required this.occupiedZones,
    required this.totalOccupants,
    required this.signalLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            icon: Icons.meeting_room_rounded,
            label: 'Zonas ocupadas',
            value: '$occupiedZones',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStat(
            icon: Icons.groups_rounded,
            label: 'Ocupantes',
            value: '$totalOccupants',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStat(
            icon: Icons.bluetooth_rounded,
            label: 'Sinal',
            value: signalLabel,
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.accent, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _BleDebugHeader extends StatelessWidget {
  final bool scanning;
  final VoidCallback onTap;

  const _BleDebugHeader({
    required this.scanning,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: SS.card(),
      child: Row(
        children: [
          Icon(
            scanning ? Icons.bluetooth_searching_rounded : Icons.bluetooth_disabled_rounded,
            color: scanning ? AppTheme.accent : AppTheme.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              scanning
                  ? 'Scan BLE ativo em ciclos'
                  : 'Scan BLE parado',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _ScanButton(
            scanning: scanning,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  final bool scanning;
  final VoidCallback onTap;

  const _ScanButton({
    required this.scanning,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: SS.pill(
        color: scanning ? AppTheme.success : AppTheme.accent,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            scanning ? Icons.stop_rounded : Icons.play_arrow_rounded,
            size: 14,
            color: scanning ? AppTheme.success : AppTheme.accent,
          ),
          const SizedBox(width: 4),
          Text(
            scanning ? 'Parar' : 'Iniciar',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scanning ? AppTheme.success : AppTheme.accent,
            ),
          ),
        ],
      ),
    ),
  );
}