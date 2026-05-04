import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/smartspace_provider.dart';
import '../../services/beacon_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../models/models.dart';
import 'admin_zone_detail_screen.dart';

class AdminZonesScreen extends StatelessWidget {
  const AdminZonesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<SmartSpaceProvider, BeaconService>(
      builder: (context, ss, ble, _) => Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Gestão de Zonas'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
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
            ),
          ],
        ),
        body: ListView(
          padding:
          const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _ZonesSummary(zones: ss.zones),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Zonas'),
            const SizedBox(height: 10),
            ...ss.zones.map((z) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ZoneCard(zone: z, ble: ble),
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
    final free =
        zones.where((z) => z.status == ZoneStatus.free).length;
    final occupied = zones
        .where((z) => z.status == ZoneStatus.occupied)
        .length;
    final unknown = zones
        .where((z) => z.status == ZoneStatus.unknown)
        .length;
    final totalOccupants =
    zones.fold<int>(0, (s, z) => s + z.occupantCount);
    final activeLights =
        zones.where((z) => z.lightOn).length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: SS.glowCard(glowColor: AppTheme.accent),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  value: '$occupied',
                  label: 'Ocupadas',
                  color: AppTheme.error,
                  icon: Icons.meeting_room_rounded,
                ),
              ),
              _vDivider(),
              Expanded(
                child: _SummaryItem(
                  value: '$free',
                  label: 'Livres',
                  color: AppTheme.success,
                  icon: Icons.door_front_door_rounded,
                ),
              ),
              _vDivider(),
              Expanded(
                child: _SummaryItem(
                  value: '$unknown',
                  label: 'Desconhecidas',
                  color: AppTheme.textMuted,
                  icon: Icons.help_outline_rounded,
                ),
              ),
              _vDivider(),
              Expanded(
                child: _SummaryItem(
                  value: '${zones.length}',
                  label: 'Total',
                  color: AppTheme.accent,
                  icon: Icons.grid_view_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoChip(
                icon: Icons.groups_rounded,
                label: '$totalOccupants pessoas presentes',
                color: AppTheme.success,
              ),
              const SizedBox(width: 8),
              _InfoChip(
                icon: Icons.lightbulb_rounded,
                label:
                '$activeLights luz${activeLights != 1 ? "es" : ""} ativa${activeLights != 1 ? "s" : ""}',
                color: AppTheme.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
      width: 1,
      height: 36,
      color: AppTheme.border,
      margin:
      const EdgeInsets.symmetric(horizontal: 4));
}

class _SummaryItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final IconData icon;

  const _SummaryItem({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(height: 4),
      Text(value,
          style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800)),
      Text(label,
          style: const TextStyle(
              color: AppTheme.textMuted, fontSize: 9),
          textAlign: TextAlign.center),
    ],
  );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
        horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

// ── Zone Card ──────────────────────────────────────────────────────────────────

class _ZoneCard extends StatefulWidget {
  final Zone zone;
  final BeaconService ble;
  const _ZoneCard({required this.zone, required this.ble});

  @override
  State<_ZoneCard> createState() => _ZoneCardState();
}

class _ZoneCardState extends State<_ZoneCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ss = context.watch<SmartSpaceProvider>();
    final z = ss.zoneById(widget.zone.id) ?? widget.zone;
    final beacon = widget.ble.beacons
        .where((b) => b.zoneId == z.id)
        .firstOrNull;
    final occupancyPct = z.occupantCount / 10.0;

    return Container(
      decoration:
      SS.card(accentColor: _expanded ? z.color : null),
      child: Column(
        children: [
          // ── Header ─────────────────────────────────────────
          InkWell(
            onTap: () =>
                setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: z.color.withOpacity(0.15),
                      borderRadius:
                      BorderRadius.circular(13),
                    ),
                    child: Icon(z.icon,
                        color: z.color, size: 22),
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
                                    color:
                                    AppTheme.textPrimary,
                                    fontSize: 15,
                                    fontWeight:
                                    FontWeight.w700)),
                            const SizedBox(width: 8),
                            ZoneStatusBadge(zone: z),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          z.presentUsers.isNotEmpty
                              ? z.presentUsers.join(', ')
                              : '${z.occupantCount} ocupante${z.occupantCount != 1 ? "s" : ""}',
                          style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                        size: 32,
                      ),
                      const SizedBox(width: 6),
                      QuickToggle(
                        icon: z.buzzerOn
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        active: z.buzzerOn,
                        color: AppTheme.error,
                        onTap: () =>
                            ss.toggleBuzzer(z.id),
                        size: 32,
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: AppTheme.textMuted,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Barra de ocupação ───────────────────────────────
          Padding(
            padding:
            const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: occupancyPct.clamp(0.0, 1.0),
                      backgroundColor: AppTheme.border,
                      valueColor: AlwaysStoppedAnimation(
                        occupancyPct > 0.8
                            ? AppTheme.error
                            : occupancyPct > 0.5
                            ? AppTheme.warning
                            : z.color,
                      ),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${z.occupantCount}/10',
                    style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 10)),
              ],
            ),
          ),

          // ── Expanded com tabs ───────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1),
            TabBar(
              controller: _tabCtrl,
              indicatorColor: z.color,
              labelColor: z.color,
              unselectedLabelColor: AppTheme.textMuted,
              labelStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Controlo'),
                Tab(text: 'Sensores'),
                Tab(text: 'Configuração'),
              ],
            ),
            const Divider(height: 1),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: SizedBox(
                height: _tabCtrl.index == 0
                    ? (z.lightOn
                    ? (z.presentUsers.isNotEmpty ? 320 : 220)
                    : (z.presentUsers.isNotEmpty ? 240 : 140))
                    : _tabCtrl.index == 1
                    ? (z.temperature != null ||
                    z.humidity != null ||
                    z.luminosity != null ||
                    z.motionDetected != null
                    ? 260
                    : 160)
                    : 480,
                child: TabBarView(
                  controller: _tabCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _ControloTab(zone: z, ss: ss),
                    _SensoresTab(zone: z),
                    _ConfiguracaoTab(zone: z, ss: ss),
                  ],
                ),
              ),
            ),
          ],

          // ── BLE info ────────────────────────────────────────
          if (beacon != null && beacon.isNearby)
            BleInfoBar(
              beacon: beacon,
              showDistance: _expanded,
            ),
        ],
      ),
    );
  }
}

// ── Tab: Controlo ──────────────────────────────────────────────────────────────

class _ControloTab extends StatelessWidget {
  final Zone zone;
  final SmartSpaceProvider ss;

  const _ControloTab({required this.zone, required this.ss});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _AdminToggleButton(
                  icon: zone.lightOn
                      ? Icons.lightbulb_rounded
                      : Icons.lightbulb_outline_rounded,
                  label: 'Luz',
                  active: zone.lightOn,
                  color: AppTheme.warning,
                  onTap: () => ss.toggleLight(zone.id),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AdminToggleButton(
                  icon: zone.buzzerOn
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  label: 'Buzzer',
                  active: zone.buzzerOn,
                  color: AppTheme.error,
                  onTap: () => ss.toggleBuzzer(zone.id),
                ),
              ),
            ],
          ),
          if (zone.lightOn) ...[
            const SizedBox(height: 12),
            Container(
              padding:
              const EdgeInsets.fromLTRB(14, 12, 14, 4),
              decoration: SS.card(),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                          Icons.brightness_6_rounded,
                          color: AppTheme.warning,
                          size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Intensidade da luz',
                            style: TextStyle(
                                color:
                                AppTheme.textSecondary,
                                fontSize: 13)),
                      ),
                      Text(
                        '${(zone.lightIntensity * 100).toInt()}%',
                        style: const TextStyle(
                            color: AppTheme.warning,
                            fontSize: 13,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  Slider(
                    value: zone.lightIntensity,
                    onChanged: (v) =>
                        ss.setLightIntensity(zone.id, v),
                    activeColor: AppTheme.warning,
                    inactiveColor: AppTheme.border,
                  ),
                ],
              ),
            ),
          ],
          if (zone.presentUsers.isNotEmpty) ...[
            const SizedBox(height: 14),
            const SectionLabel(label: 'Ocupantes'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: SS.card(),
              child: Wrap(
                spacing: 8, runSpacing: 8,
                children: zone.presentUsers
                    .map((u) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: zone.color.withOpacity(0.1),
                    borderRadius:
                    BorderRadius.circular(8),
                    border: Border.all(
                        color: zone.color
                            .withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_rounded,
                          color: zone.color,
                          size: 12),
                      const SizedBox(width: 5),
                      Text(u,
                          style: TextStyle(
                              color: zone.color,
                              fontSize: 11,
                              fontWeight:
                              FontWeight.w600)),
                    ],
                  ),
                ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tab: Sensores ──────────────────────────────────────────────────────────────

class _SensoresTab extends StatelessWidget {
  final Zone zone;
  const _SensoresTab({required this.zone});

  @override
  Widget build(BuildContext context) {
    final hasSensors = zone.temperature != null ||
        zone.humidity != null ||
        zone.luminosity != null ||
        zone.motionDetected != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: hasSensors
          ? Column(
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics:
            const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: [
              if (zone.temperature != null)
                _SensorCard(
                  icon: Icons.thermostat_rounded,
                  label: 'Temperatura',
                  value:
                  '${zone.temperature!.toStringAsFixed(1)}°C',
                  color: AppTheme.error,
                ),
              if (zone.humidity != null)
                _SensorCard(
                  icon: Icons.water_drop_rounded,
                  label: 'Humidade',
                  value:
                  '${zone.humidity!.toStringAsFixed(0)}%',
                  color: AppTheme.accent,
                ),
              if (zone.luminosity != null)
                _SensorCard(
                  icon: Icons.wb_sunny_rounded,
                  label: 'Luminosidade',
                  value:
                  '${zone.luminosity!.toStringAsFixed(0)} lx',
                  color: AppTheme.warning,
                ),
              if (zone.motionDetected != null)
                _SensorCard(
                  icon: Icons.directions_run_rounded,
                  label: 'Movimento',
                  value: zone.motionDetected!
                      ? 'Detetado'
                      : 'Sem movimento',
                  color: zone.motionDetected!
                      ? AppTheme.error
                      : AppTheme.textMuted,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: SS.card(),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppTheme.textMuted,
                    size: 14),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                      'Dados em tempo real via ESP32',
                      style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      )
          : Container(
        padding: const EdgeInsets.all(24),
        decoration: SS.card(),
        child: const Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(Icons.sensors_off_rounded,
                color: AppTheme.textMuted, size: 36),
            SizedBox(height: 10),
            Text('Sem dados de sensores',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text(
              'Os dados aparecem aqui quando\no ESP32 estiver ligado.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SensorCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SensorCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
        horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10)),
            ],
          ),
        ),
      ],
    ),
  );
}

// ── Tab: Configuração ──────────────────────────────────────────────────────────

class _ConfiguracaoTab extends StatelessWidget {
  final Zone zone;
  final SmartSpaceProvider ss;

  const _ConfiguracaoTab(
      {required this.zone, required this.ss});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel(label: 'Capacidade'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: SS.card(),
            child: Row(
              children: [
                const Icon(Icons.groups_rounded,
                    color: AppTheme.accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${zone.occupantCount} / 10 pessoas',
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const Text(
                          'Ocupação atual / capacidade máxima',
                          style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Editar'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const SectionLabel(
              label: 'Limiares de Automação'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: SS.card(),
            child: Column(
              children: [
                _ThresholdRow(
                  icon: Icons.wb_sunny_rounded,
                  label: 'Luminosidade mínima',
                  value: '300 lx',
                  color: AppTheme.warning,
                  onEdit: () => _showThresholdDialog(
                      context, 'Luminosidade mínima', '300'),
                ),
                const Divider(height: 20),
                _ThresholdRow(
                  icon: Icons.thermostat_rounded,
                  label: 'Temperatura máxima',
                  value: '28°C',
                  color: AppTheme.error,
                  onEdit: () => _showThresholdDialog(
                      context, 'Temperatura máxima', '28'),
                ),
                const Divider(height: 20),
                _ThresholdRow(
                  icon: Icons.water_drop_rounded,
                  label: 'Humidade máxima',
                  value: '70%',
                  color: AppTheme.accent,
                  onEdit: () => _showThresholdDialog(
                      context, 'Humidade máxima', '70'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const SectionLabel(
              label: 'Política de Resolução de Conflitos'),
          const SizedBox(height: 8),
          _ConflictPolicySelector(zoneId: zone.id),

          const SizedBox(height: 16),
          const SectionLabel(label: 'Consumo Energético'),
          const SizedBox(height: 8),
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
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${zone.energyUsageWh.toStringAsFixed(1)} Wh',
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
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

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => AdminZoneDetailScreen(
                        zoneId: zone.id)),
              ),
              icon: const Icon(
                  Icons.auto_fix_high_rounded,
                  size: 16),
              label: const Text('Automações e modo demo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: zone.color,
                side: BorderSide(
                    color: zone.color.withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showThresholdDialog(BuildContext context,
      String label, String currentValue) {
    final ctrl = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Editar $label',
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style:
          const TextStyle(color: AppTheme.textPrimary),
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

class _ConflictPolicySelectorState
    extends State<_ConflictPolicySelector> {
  String _selected = 'average';

  final _policies = const [
    ('average', 'Média ponderada', Icons.equalizer_rounded),
    ('priority', 'Prioridade por papel',
    Icons.shield_rounded),
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
          onTap: () =>
              setState(() => _selected = id),
          child: AnimatedContainer(
            duration:
            const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? AppTheme.accent.withOpacity(0.12)
                  : AppTheme.surface,
              borderRadius:
              BorderRadius.circular(10),
              border: Border.all(
                  color: active
                      ? AppTheme.accent
                      : AppTheme.border,
                  width: active ? 1.5 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    color: active
                        ? AppTheme.accent
                        : AppTheme.textMuted,
                    size: 14),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: active
                            ? AppTheme.accent
                            : AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: active
                            ? FontWeight.w700
                            : FontWeight.w500)),
              ],
            ),
          ),
        );
      }).toList(),
    ),
  );
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
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 10),
      Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13))),
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
        color: active
            ? color.withOpacity(0.12)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: active
                ? color.withOpacity(0.4)
                : AppTheme.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              color: active ? color : AppTheme.textMuted,
              size: 18),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: active
                      ? color
                      : AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
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
