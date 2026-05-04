import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/smartspace_provider.dart';
import '../../services/beacon_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<SmartSpaceProvider, BeaconService>(
      builder: (context, ss, ble, _) {
        final auth = context.watch<AuthService>();
        final occupiedZones = ss.zones
            .where((z) => z.status == ZoneStatus.occupied)
            .length;
        final totalOccupants =
        ss.zones.fold<int>(0, (s, z) => s + z.occupantCount);
        final activeLights =
            ss.zones.where((z) => z.lightOn).length;
        final activeBuzzers =
            ss.zones.where((z) => z.buzzerOn).length;

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
                        ble.scanning
                            ? 'BLE ativo · Sistema online'
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
                    color: ble.scanning
                        ? AppTheme.accent
                        : AppTheme.textMuted,
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
              padding:
              const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _WelcomeBanner(
                    name: auth.appUser?.displayName ?? 'Admin',
                    ble: ble,
                    ss: ss,
                  ),
                  const SizedBox(height: 16),
                  _GlobalStatsRow(
                    occupiedZones: occupiedZones,
                    totalZones: ss.zones.length,
                    totalOccupants: totalOccupants,
                    activeLights: activeLights,
                    activeBuzzers: activeBuzzers,
                  ),
                  const SizedBox(height: 16),
                  _ZonesQuickRow(zones: ss.zones, ble: ble),
                  const SizedBox(height: 20),
                  const SectionHeader(
                      title: 'Utilizadores Online'),
                  const SizedBox(height: 10),
                  _OnlineUsersCard(zones: ss.zones),
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
  final BeaconService ble;
  final SmartSpaceProvider ss;

  const _WelcomeBanner({
    required this.name,
    required this.ble,
    required this.ss,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Bom dia'
        : hour < 18
        ? 'Boa tarde'
        : 'Boa noite';
    final dateStr =
        '${_weekday(now.weekday)}, ${now.day} ${_month(now.month)}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: SS.glowCard(glowColor: AppTheme.accent),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.accent.withOpacity(0.25),
                      width: 1.5),
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
                    Text('$greeting, $name!',
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(dateStr,
                        style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.accentLight,
                  borderRadius: BorderRadius.circular(8),
                  border:
                  Border.all(color: AppTheme.accentBorder),
                ),
                child: const Text('⚡ Admin',
                    style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatusDot(
                label: 'Firebase',
                active: ss.isConnected,
                activeLabel: 'Online',
                inactiveLabel: 'Offline',
              ),
              const SizedBox(width: 16),
              _StatusDot(
                label: 'BLE',
                active: ble.scanning,
                activeLabel: 'Ativo',
                inactiveLabel: 'Parado',
              ),
              const SizedBox(width: 16),
              _StatusDot(
                label: 'Zonas',
                active: true,
                activeLabel:
                '${ss.zones.where((z) => z.status == ZoneStatus.occupied).length}/${ss.zones.length} ativas',
                inactiveLabel: 'Sem dados',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _weekday(int d) {
    const days = [
      'Segunda', 'Terça', 'Quarta', 'Quinta',
      'Sexta', 'Sábado', 'Domingo'
    ];
    return days[d - 1];
  }

  String _month(int m) {
    const months = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];
    return months[m - 1];
  }
}

class _StatusDot extends StatelessWidget {
  final String label;
  final bool active;
  final String activeLabel;
  final String inactiveLabel;

  const _StatusDot({
    required this.label,
    required this.active,
    required this.activeLabel,
    required this.inactiveLabel,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7, height: 7,
        decoration: BoxDecoration(
          color: active
              ? AppTheme.success
              : AppTheme.textMuted,
          shape: BoxShape.circle,
          boxShadow: active
              ? [
            BoxShadow(
                color:
                AppTheme.success.withOpacity(0.4),
                blurRadius: 4,
                spreadRadius: 1)
          ]
              : null,
        ),
      ),
      const SizedBox(width: 5),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 9)),
          Text(
            active ? activeLabel : inactiveLabel,
            style: TextStyle(
              color: active
                  ? AppTheme.success
                  : AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ],
  );
}

// ── Global Stats Row ───────────────────────────────────────────────────────────

class _GlobalStatsRow extends StatelessWidget {
  final int occupiedZones;
  final int totalZones;
  final int totalOccupants;
  final int activeLights;
  final int activeBuzzers;

  const _GlobalStatsRow({
    required this.occupiedZones,
    required this.totalZones,
    required this.totalOccupants,
    required this.activeLights,
    required this.activeBuzzers,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: 14, horizontal: 8),
      decoration: SS.card(),
      child: Row(
        children: [
          _StatItem(
            icon: Icons.meeting_room_rounded,
            value: '$occupiedZones/$totalZones',
            label: 'Zonas',
            color: AppTheme.accent,
          ),
          _vDivider(),
          _StatItem(
            icon: Icons.groups_rounded,
            value: '$totalOccupants',
            label: 'Pessoas',
            color: AppTheme.success,
          ),
          _vDivider(),
          _StatItem(
            icon: Icons.lightbulb_rounded,
            value: '$activeLights',
            label: 'Luzes',
            color: activeLights > 0
                ? AppTheme.warning
                : AppTheme.textMuted,
          ),
          _vDivider(),
          _StatItem(
            icon: Icons.volume_up_rounded,
            value: '$activeBuzzers',
            label: 'Buzzers',
            color: activeBuzzers > 0
                ? AppTheme.error
                : AppTheme.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _vDivider() =>
      Container(width: 1, height: 40, color: AppTheme.border);
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textMuted, fontSize: 10)),
      ],
    ),
  );
}

// ── Zones Quick Row ────────────────────────────────────────────────────────────

class _ZonesQuickRow extends StatelessWidget {
  final List<Zone> zones;
  final BeaconService ble;

  const _ZonesQuickRow(
      {required this.zones, required this.ble});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SectionHeader(title: 'Estado das Zonas'),
        Container(
          decoration: SS.card(),
          child: Column(
            children: zones.asMap().entries.map((entry) {
              final i = entry.key;
              final z = entry.value;
              return _ZoneCompactRow(
                zone: z,
                ble: ble,
                isLast: i == zones.length - 1,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ZoneCompactRow extends StatelessWidget {
  final Zone zone;
  final BeaconService ble;
  final bool isLast;

  const _ZoneCompactRow({
    required this.zone,
    required this.ble,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final ss = context.watch<SmartSpaceProvider>();
    final z = ss.zoneById(zone.id) ?? zone;
    final beacon = ble.beacons
        .where((b) => b.zoneId == z.id)
        .firstOrNull;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isLast &&
                    (beacon == null || !beacon.isNearby)
                    ? Colors.transparent
                    : AppTheme.border,
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: z.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                Icon(z.icon, color: z.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(z.name,
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight:
                                FontWeight.w700)),
                        const SizedBox(width: 8),
                        ZoneStatusBadge(zone: z),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${z.occupantCount} pessoa${z.occupantCount != 1 ? "s" : ""}',
                          style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11),
                        ),
                        if (z.temperature != null) ...[
                          const SizedBox(width: 8),
                          const Icon(
                              Icons.thermostat_rounded,
                              color: AppTheme.warning,
                              size: 11),
                          const SizedBox(width: 2),
                          Text(
                            '${z.temperature!.toStringAsFixed(0)}°C',
                            style: const TextStyle(
                                color: AppTheme.warning,
                                fontSize: 10),
                          ),
                        ],
                        if (z.humidity != null) ...[
                          const SizedBox(width: 8),
                          const Icon(
                              Icons.water_drop_rounded,
                              color: AppTheme.accent,
                              size: 11),
                          const SizedBox(width: 2),
                          Text(
                            '${z.humidity!.toStringAsFixed(0)}%',
                            style: const TextStyle(
                                color: AppTheme.accent,
                                fontSize: 10),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  QuickToggle(
                    icon: z.lightOn
                        ? Icons.lightbulb_rounded
                        : Icons.lightbulb_outline_rounded,
                    active: z.lightOn,
                    color: AppTheme.warning,
                    onTap: () => ss.toggleLight(z.id),
                  ),
                  const SizedBox(width: 6),
                  QuickToggle(
                    icon: z.buzzerOn
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    active: z.buzzerOn,
                    color: AppTheme.error,
                    onTap: () => ss.toggleBuzzer(z.id),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (beacon != null && beacon.isNearby)
          BleInfoBar(
            beacon: beacon,
            showDistance: false,
            rounded: isLast,
          ),
      ],
    );
  }
}

// ── Online Users Card ──────────────────────────────────────────────────────────

class _OnlineUsersCard extends StatelessWidget {
  final List<Zone> zones;
  const _OnlineUsersCard({required this.zones});

  @override
  Widget build(BuildContext context) {
    final db = context.read<DatabaseService>();

    return StreamBuilder<List<OnlineUser>>(
      stream: db.onlineUsersStream(),
      builder: (context, snapshot) {
        final users = snapshot.data ?? [];

        if (users.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: SS.card(),
            child: const Row(
              children: [
                Icon(Icons.people_outline_rounded,
                    color: AppTheme.textMuted, size: 20),
                SizedBox(width: 12),
                Text('Nenhum utilizador online',
                    style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13)),
              ],
            ),
          );
        }

        return Container(
          decoration:
          SS.glowCard(glowColor: AppTheme.success),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.success
                            .withOpacity(0.12),
                        borderRadius:
                        BorderRadius.circular(10),
                      ),
                      child: const Icon(
                          Icons.people_rounded,
                          color: AppTheme.success,
                          size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${users.length} utilizador${users.length != 1 ? "es" : ""} online',
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.success
                            .withOpacity(0.12),
                        borderRadius:
                        BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              color: AppTheme.success,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: AppTheme.success
                                        .withOpacity(0.5),
                                    blurRadius: 4,
                                    spreadRadius: 1)
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('LIVE',
                              style: TextStyle(
                                  color: AppTheme.success,
                                  fontSize: 9,
                                  fontWeight:
                                  FontWeight.w800,
                                  letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...users.map((u) {
                final zone = u.currentZoneId != null
                    ? zones
                    .where(
                        (z) => z.id == u.currentZoneId)
                    .firstOrNull
                    : null;
                final initial = u.displayName.isNotEmpty
                    ? u.displayName[0].toUpperCase()
                    : u.uid[0].toUpperCase();

                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: u != users.last
                            ? AppTheme.border
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: (zone?.color ??
                              AppTheme.accent)
                              .withOpacity(0.12),
                          borderRadius:
                          BorderRadius.circular(12),
                          border: Border.all(
                              color: (zone?.color ??
                                  AppTheme.accent)
                                  .withOpacity(0.3)),
                        ),
                        child: Center(
                          child: Text(initial,
                              style: TextStyle(
                                  color: zone?.color ??
                                      AppTheme.accent,
                                  fontSize: 16,
                                  fontWeight:
                                  FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  u.displayName.isNotEmpty
                                      ? u.displayName
                                      : u.uid
                                      .substring(0, 6),
                                  style: const TextStyle(
                                      color: AppTheme
                                          .textPrimary,
                                      fontSize: 13,
                                      fontWeight:
                                      FontWeight.w600),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets
                                      .symmetric(
                                      horizontal: 6,
                                      vertical: 2),
                                  decoration: BoxDecoration(
                                    color: u.isAdmin
                                        ? AppTheme.accent
                                        .withOpacity(0.1)
                                        : AppTheme.success
                                        .withOpacity(0.1),
                                    borderRadius:
                                    BorderRadius.circular(
                                        4),
                                  ),
                                  child: Text(
                                    u.isAdmin
                                        ? '⚡ Admin'
                                        : '👤 User',
                                    style: TextStyle(
                                        color: u.isAdmin
                                            ? AppTheme.accent
                                            : AppTheme.success,
                                        fontSize: 9,
                                        fontWeight:
                                        FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              zone != null
                                  ? 'Na ${zone.name}'
                                  : 'Sem zona detetada',
                              style: TextStyle(
                                  color: zone?.color ??
                                      AppTheme.textMuted,
                                  fontSize: 11,
                                  fontWeight:
                                  FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      if (zone != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color:
                            zone.color.withOpacity(0.1),
                            borderRadius:
                            BorderRadius.circular(8),
                            border: Border.all(
                                color: zone.color
                                    .withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(zone.icon,
                                  color: zone.color,
                                  size: 12),
                              const SizedBox(width: 5),
                              Text(zone.name,
                                  style: TextStyle(
                                      color: zone.color,
                                      fontSize: 11,
                                      fontWeight:
                                      FontWeight.w700)),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.textMuted
                                .withOpacity(0.08),
                            borderRadius:
                            BorderRadius.circular(8),
                          ),
                          child: const Text('Sem zona',
                              style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 11,
                                  fontWeight:
                                  FontWeight.w600)),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

