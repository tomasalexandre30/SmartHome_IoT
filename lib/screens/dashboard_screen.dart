import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/smartspace_provider.dart';
import '../services/beacon_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../models/models.dart';
import 'zone_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<SmartSpaceProvider, BeaconService>(
      builder: (context, ss, ble, _) {
        final currentZone = ss.currentZone;

        return CustomScrollView(
          slivers: [
            // ── App bar ──────────────────────────────────────────────────
            SliverAppBar(
              floating: true,
              backgroundColor: AppTheme.background,
              title: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.location_city_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SmartSpace', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      Text('Sistema ativo', style: TextStyle(fontSize: 11, color: AppTheme.success)),
                    ],
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    ble.scanning ? Icons.bluetooth_searching_rounded : Icons.bluetooth_rounded,
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

                  // ── Current zone hero ────────────────────────────────
                  _CurrentZoneCard(zone: currentZone, scanning: ble.scanning),
                  const SizedBox(height: 24),

                  // ── Beacons ──────────────────────────────────────────
                  SectionHeader(
                    title: 'Sinais BLE',
                    trailing: _ScanButton(scanning: ble.scanning, onTap: () {
                      ble.scanning ? ble.stopScanning() : ble.startScanning();
                    }),
                  ),
                  ...ble.beacons.map((b) => BeaconSignalRow(
                    beacon: b,
                    isActive: b.zoneId == ss.currentZoneId,
                  )),
                  const SizedBox(height: 24),

                  // ── Zones ─────────────────────────────────────────────
                  const SectionHeader(title: 'Zonas'),
                  ...ss.zones.map((z) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ZoneCard(
                      zone: z,
                      isCurrentZone: z.id == ss.currentZoneId,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => ZoneDetailScreen(zoneId: z.id))),
                    ),
                  )),
                  const SizedBox(height: 24),

                  // ── Recent logs ──────────────────────────────────────
                  SectionHeader(
                    title: 'Atividade Recente',
                    trailing: TextButton(
                      onPressed: () {},
                      child: const Text('Ver tudo', style: TextStyle(color: AppTheme.accent, fontSize: 12)),
                    ),
                  ),
                  ...ss.logs.take(5).map((e) => LogTile(event: e)),

                  if (ss.logs.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Nenhum evento ainda', style: TextStyle(color: AppTheme.textMuted)),
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

// ── Current Zone Card ─────────────────────────────────────────────────────────

class _CurrentZoneCard extends StatelessWidget {
  final Zone? zone;
  final bool scanning;
  const _CurrentZoneCard({this.zone, required this.scanning});

  @override
  Widget build(BuildContext context) {
    if (zone == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: SS.glowCard(),
        child: Column(
          children: [
            Icon(
              scanning ? Icons.bluetooth_searching_rounded : Icons.location_off_rounded,
              color: scanning ? AppTheme.accent : AppTheme.textMuted,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              scanning ? 'A procurar localização...' : 'Localização desconhecida',
              style: TextStyle(
                color: scanning ? AppTheme.accent : AppTheme.textMuted,
                fontSize: 16, fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              scanning ? 'A ler sinais dos beacons BLE' : 'Ativa o scan BLE para detetar a tua zona',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SS.glowCard(glowColor: zone!.color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: zone!.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(zone!.icon, color: zone!.color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Estás em', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    Text(zone!.name,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              ZoneStatusBadge(zone: zone!),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Sensor grid (shows placeholder if no ESP32 yet)
          Row(
            children: [
              Expanded(child: SensorTile(
                icon: Icons.thermostat_rounded,
                label: 'Temperatura',
                value: zone!.temperature != null ? '${zone!.temperature!.toStringAsFixed(1)}°C' : '—',
                color: AppTheme.warning,
              )),
              const SizedBox(width: 10),
              Expanded(child: SensorTile(
                icon: Icons.water_drop_rounded,
                label: 'Humidade',
                value: zone!.humidity != null ? '${zone!.humidity!.toStringAsFixed(0)}%' : '—',
                color: AppTheme.accent,
              )),
              const SizedBox(width: 10),
              Expanded(child: SensorTile(
                icon: Icons.wb_sunny_rounded,
                label: 'Luminosidade',
                value: zone!.luminosity != null ? '${zone!.luminosity!.toStringAsFixed(0)} lx' : '—',
                color: AppTheme.warning,
              )),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  final bool scanning;
  final VoidCallback onTap;
  const _ScanButton({required this.scanning, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: SS.pill(color: scanning ? AppTheme.success : AppTheme.accent),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            scanning ? Icons.stop_rounded : Icons.play_arrow_rounded,
            size: 14, color: scanning ? AppTheme.success : AppTheme.accent,
          ),
          const SizedBox(width: 4),
          Text(scanning ? 'Parar' : 'Iniciar',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: scanning ? AppTheme.success : AppTheme.accent)),
        ],
      ),
    ),
  );
}
