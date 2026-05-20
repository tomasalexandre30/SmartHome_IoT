import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/smartspace_provider.dart';
import '../../services/beacon_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../zone_detail_widgets.dart';

String _safeUidLabel(String uid) =>
    uid.length >= 6 ? uid.substring(0, 6) : uid;

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
                  color: ble.scanning ? AppTheme.accent : AppTheme.textMuted,
                ),
                onPressed: () =>
                ble.scanning ? ble.stopScanning() : ble.startScanning(),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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

// ── Zones Summary ─────────────────────────────────────────────────────────────

class _ZonesSummary extends StatelessWidget {
  final List<Zone> zones;
  const _ZonesSummary({required this.zones});

  @override
  Widget build(BuildContext context) {
    final free = zones.where((z) => z.status == ZoneStatus.free).length;
    final occupied = zones.where((z) => z.status == ZoneStatus.occupied).length;
    final unknown = zones.where((z) => z.status == ZoneStatus.unknown).length;
    final totalOccupants = zones.fold<int>(0, (s, z) => s + z.occupantCount);
    final activeLights = zones.where((z) => z.lightOn).length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: SS.glowCard(glowColor: AppTheme.accent),
      child: Column(children: [
        Row(children: [
          Expanded(child: _SummaryItem(value: '$occupied', label: 'Ocupadas', color: AppTheme.error, icon: Icons.meeting_room_rounded)),
          _vDivider(),
          Expanded(child: _SummaryItem(value: '$free', label: 'Livres', color: AppTheme.success, icon: Icons.door_front_door_rounded)),
          _vDivider(),
          Expanded(child: _SummaryItem(value: '$unknown', label: 'Desconhecidas', color: AppTheme.textMuted, icon: Icons.help_outline_rounded)),
          _vDivider(),
          Expanded(child: _SummaryItem(value: '${zones.length}', label: 'Total', color: AppTheme.accent, icon: Icons.grid_view_rounded)),
        ]),
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 12),
        Row(children: [
          _InfoChip(icon: Icons.groups_rounded, label: '$totalOccupants pessoas presentes', color: AppTheme.success),
          const SizedBox(width: 8),
          _InfoChip(icon: Icons.lightbulb_rounded, label: '$activeLights luz${activeLights != 1 ? "es" : ""} ativa${activeLights != 1 ? "s" : ""}', color: AppTheme.warning),
        ]),
      ]),
    );
  }

  Widget _vDivider() => Container(width: 1, height: 36, color: AppTheme.border, margin: const EdgeInsets.symmetric(horizontal: 4));
}

class _SummaryItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final IconData icon;
  const _SummaryItem({required this.value, required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, color: color, size: 16),
    const SizedBox(height: 4),
    Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
    Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9), textAlign: TextAlign.center),
  ]);
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.2))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 12),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── Zone Card ─────────────────────────────────────────────────────────────────

class _ZoneCard extends StatefulWidget {
  final Zone zone;
  final BeaconService ble;
  const _ZoneCard({required this.zone, required this.ble});

  @override
  State<_ZoneCard> createState() => _ZoneCardState();
}

class _ZoneCardState extends State<_ZoneCard> with SingleTickerProviderStateMixin {
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
    final db = context.read<DatabaseService>();
    final z = ss.zoneById(widget.zone.id) ?? widget.zone;
    final beacon = widget.ble.beacons.where((b) => b.zoneId == z.id).firstOrNull;
    final occupancyPct = z.occupantCount / 10.0;

    String resolveUid(String uid) => db.displayNameCache[uid] ?? _safeUidLabel(uid);

    return Container(
      decoration: SS.card(accentColor: _expanded ? z.color : null),
      child: Column(children: [
        // ── Header ───────────────────────────────────────────────────────────
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: z.color.withOpacity(0.15), borderRadius: BorderRadius.circular(13)),
                child: Icon(z.icon, color: z.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(z.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    ZoneStatusBadge(zone: z),
                    if (z.isAbsoluteLocked) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.error.withOpacity(0.4)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.lock_rounded, color: AppTheme.error, size: 10),
                          const SizedBox(width: 3),
                          const Text('ABSOLUTE', style: TextStyle(color: AppTheme.error, fontSize: 9, fontWeight: FontWeight.w800)),
                        ]),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    z.presentUsers.isNotEmpty
                        ? z.presentUsers.map(resolveUid).join(', ')
                        : '${z.occupantCount} ocupante${z.occupantCount != 1 ? "s" : ""}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ]),
              ),
              Row(children: [
                QuickToggle(icon: z.lightOn ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded,
                    active: z.lightOn, color: AppTheme.warning, onTap: () => ss.toggleLight(z.id), size: 32),
                const SizedBox(width: 6),
                QuickToggle(icon: z.buzzerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    active: z.buzzerOn, color: AppTheme.error, onTap: () => ss.toggleBuzzer(z.id), size: 32),
                const SizedBox(width: 6),
                Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppTheme.textMuted, size: 20),
              ]),
            ]),
          ),
        ),

        // ── Barra de ocupação ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: occupancyPct.clamp(0.0, 1.0),
                  backgroundColor: AppTheme.border,
                  valueColor: AlwaysStoppedAnimation(
                    occupancyPct > 0.8 ? AppTheme.error : occupancyPct > 0.5 ? AppTheme.warning : z.color,
                  ),
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('${z.occupantCount}/10', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          ]),
        ),

        // ── Expanded com tabs ─────────────────────────────────────────────────
        if (_expanded) ...[
          const Divider(height: 1),
          TabBar(
            controller: _tabCtrl,
            indicatorColor: z.color,
            labelColor: z.color,
            unselectedLabelColor: AppTheme.textMuted,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            tabs: const [Tab(text: 'Controlo'), Tab(text: 'Sensores'), Tab(text: 'Configuração')],
          ),
          const Divider(height: 1),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: _tabCtrl.index == 0
                    ? (z.lightOn ? 700 : (z.presentUsers.isNotEmpty ? 320 : 220))
                    : _tabCtrl.index == 1
                    ? (z.temperature != null || z.humidity != null || z.luminosity != null ? 280 : 160)
                    : 680,
              ),
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

        if (beacon != null && beacon.isNearby)
          BleInfoBar(beacon: beacon, showDistance: _expanded),
      ]),
    );
  }
}

// ── Tab: Controlo ─────────────────────────────────────────────────────────────

class _ControloTab extends StatelessWidget {
  final Zone zone;
  final SmartSpaceProvider ss;
  const _ControloTab({required this.zone, required this.ss});

  @override
  Widget build(BuildContext context) {
    final db = context.read<DatabaseService>();
    final isAbsoluteByMe = zone.absoluteLocked && zone.absoluteLockedBy == ss.uid;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Toggle ABSOLUTE ───────────────────────────────────────────────────
        _AbsoluteModeToggle(zone: zone, ss: ss),
        const SizedBox(height: 12),

        // Admin vê sempre tudo — ABSOLUTE só bloqueia os users
        // Quando ABSOLUTE ativo mostra banner informativo mas mantém controlos
        if (isAbsoluteByMe) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.error.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.lock_rounded, color: AppTheme.error, size: 14),
              const SizedBox(width: 8),
              const Expanded(child: Text(
                'Modo Absoluto ativo — users bloqueados',
                style: TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.w600),
              )),
            ]),
          ),
          const SizedBox(height: 12),
        ],

        // ── Poll status — sempre renderizado, o banner decide se se mostra ────
        _AdminPollBanner(zoneId: zone.id),

        // ── Toggle AUTO / MANUAL (admin) ──────────────────────────────────────
        _AdminLightModeSelector(zone: zone, ss: ss),
        const SizedBox(height: 12),

        // ── Toggles rápidos ───────────────────────────────────────────────────
        Row(children: [
          Expanded(
            child: _AdminToggleButton(
              icon: zone.lightOn ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded,
              label: 'Luz', active: zone.lightOn, color: AppTheme.warning,
              onTap: () => ss.toggleLight(zone.id),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _AdminToggleButton(
              icon: zone.buzzerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              label: 'Buzzer', active: zone.buzzerOn, color: AppTheme.error,
              onTap: () => ss.toggleBuzzer(zone.id),
            ),
          ),
        ]),

        if (zone.lightOn) ...[
          const SizedBox(height: 12),
          if (zone.lightMode == LightMode.auto)
            _AdminAutoLdrIndicator(zone: zone)
          else ...[
            _AdminIntensitySlider(zone: zone, ss: ss),
            const SizedBox(height: 12),
            _AdminColorPickerCard(zone: zone, ss: ss),
          ],
        ],

        // ── Users presentes ───────────────────────────────────────────────────
        if (zone.presentUsers.isNotEmpty) ...[
          const SizedBox(height: 14),
          const SectionLabel(label: 'Ocupantes'),
          const SizedBox(height: 8),
          _OccupantsCard(zone: zone, db: db),
        ],
      ]),
    );
  }
}

// ── Absolute Mode Toggle ──────────────────────────────────────────────────────

class _AbsoluteModeToggle extends StatelessWidget {
  final Zone zone;
  final SmartSpaceProvider ss;
  const _AbsoluteModeToggle({required this.zone, required this.ss});

  @override
  Widget build(BuildContext context) {
    final isActive = zone.isAbsoluteLocked;

    return GestureDetector(
      onTap: () => ss.setAbsoluteMode(zone.id, !isActive),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.error.withOpacity(0.10) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppTheme.error.withOpacity(0.5) : AppTheme.border,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: isActive ? AppTheme.error.withOpacity(0.15) : AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isActive ? AppTheme.error.withOpacity(0.4) : AppTheme.border),
            ),
            child: Icon(isActive ? Icons.lock_rounded : Icons.lock_open_rounded,
                color: isActive ? AppTheme.error : AppTheme.textMuted, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Modo Absoluto',
                  style: TextStyle(
                    color: isActive ? AppTheme.error : AppTheme.textPrimary,
                    fontSize: 14, fontWeight: FontWeight.w700,
                  )),
              Text(
                isActive
                    ? 'Users bloqueados — controlo total do admin'
                    : 'Ativar para bloquear todos os users',
                style: TextStyle(
                  color: isActive ? AppTheme.error.withOpacity(0.8) : AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ]),
          ),
          Switch(
            value: isActive,
            onChanged: (v) => ss.setAbsoluteMode(zone.id, v),
            activeColor: AppTheme.error,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ]),
      ),
    );
  }
}

// ── Admin Light Mode Selector ─────────────────────────────────────────────────

class _AdminLightModeSelector extends StatelessWidget {
  final Zone zone;
  final SmartSpaceProvider ss;
  const _AdminLightModeSelector({required this.zone, required this.ss});

  @override
  Widget build(BuildContext context) {
    final isAuto = zone.lightMode == LightMode.auto;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        _ModePill(
          label: 'AUTO',
          icon: Icons.auto_awesome_rounded,
          sublabel: 'LDR ajusta intensidade',
          active: isAuto,
          color: AppTheme.accent,
          onTap: () => ss.setZoneLightMode(zone.id, LightMode.auto),
        ),
        const SizedBox(width: 4),
        _ModePill(
          label: 'MANUAL',
          icon: Icons.tune_rounded,
          sublabel: 'Controlo total',
          active: !isAuto,
          color: AppTheme.warning,
          onTap: () => ss.setZoneLightMode(zone.id, LightMode.manual),
        ),
      ]),
    );
  }
}

class _ModePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final String sublabel;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _ModePill({required this.label, required this.icon, required this.sublabel,
    required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: active ? Border.all(color: color.withOpacity(0.4), width: 1.5) : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: active ? color : AppTheme.textMuted, size: 16),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(
                color: active ? color : AppTheme.textMuted,
                fontSize: 12, fontWeight: FontWeight.w800)),
            Text(sublabel, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
          ]),
        ]),
      ),
    ),
  );
}

// ── Admin Auto LDR Indicator ──────────────────────────────────────────────────

class _AdminAutoLdrIndicator extends StatelessWidget {
  final Zone zone;
  const _AdminAutoLdrIndicator({required this.zone});

  @override
  Widget build(BuildContext context) {
    final ldr = zone.luminosity ?? 0.0;
    final threshold = zone.automations.ldrThreshold;
    final autoIntensity = (zone.lightIntensity * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: SS.glowCard(glowColor: AppTheme.accent),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.auto_awesome_rounded, color: AppTheme.accent, size: 16),
          const SizedBox(width: 8),
          const Expanded(child: Text('Intensidade automática (LDR)',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600))),
          Text('$autoIntensity%',
              style: const TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: zone.lightIntensity.clamp(0.0, 1.0),
            backgroundColor: AppTheme.border,
            color: AppTheme.accent,
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.wb_sunny_rounded, color: AppTheme.warning, size: 12),
          const SizedBox(width: 4),
          Text('LDR: ${ldr.toStringAsFixed(0)}%  ·  Limiar: ${threshold.toStringAsFixed(0)}%',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ]),
      ]),
    );
  }
}

// ── Occupants Card ────────────────────────────────────────────────────────────

class _OccupantsCard extends StatelessWidget {
  final Zone zone;
  final DatabaseService db;
  const _OccupantsCard({required this.zone, required this.db});

  @override
  Widget build(BuildContext context) {
    final modeColor = zone.lightMode == LightMode.auto ? AppTheme.accent : AppTheme.warning;
    final modeIcon = zone.lightMode == LightMode.auto ? Icons.auto_awesome_rounded : Icons.tune_rounded;
    final modeLabel = zone.lightMode == LightMode.auto ? 'AUTO' : 'MANUAL';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: SS.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Modo global da zona
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: modeColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: modeColor.withOpacity(0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(modeIcon, color: modeColor, size: 12),
            const SizedBox(width: 6),
            Text('Zona em $modeLabel', style: TextStyle(color: modeColor, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: zone.presentUsers.map((uid) {
            final name = db.displayNameCache[uid] ?? _safeUidLabel(uid);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: zone.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: zone.color.withOpacity(0.25)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.person_rounded, color: zone.color, size: 12),
                const SizedBox(width: 5),
                Text(name, style: TextStyle(color: zone.color, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

// ── Tab: Sensores ─────────────────────────────────────────────────────────────

class _SensoresTab extends StatelessWidget {
  final Zone zone;
  const _SensoresTab({required this.zone});

  @override
  Widget build(BuildContext context) {
    final hasSensors = zone.temperature != null || zone.humidity != null ||
        zone.luminosity != null || zone.motionDetected != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: hasSensors
          ? Column(children: [
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.2,
          children: [
            if (zone.temperature != null)
              _SensorCard(icon: Icons.thermostat_rounded, label: 'Temperatura',
                  value: '${zone.temperature!.toStringAsFixed(1)}°C', color: AppTheme.error),
            if (zone.humidity != null)
              _SensorCard(icon: Icons.water_drop_rounded, label: 'Humidade',
                  value: '${zone.humidity!.toStringAsFixed(0)}%', color: AppTheme.accent),
            if (zone.luminosity != null)
              _SensorCard(icon: Icons.wb_sunny_rounded, label: 'Luminosidade',
                  value: '${zone.luminosity!.toStringAsFixed(0)}%', color: AppTheme.warning),
            if (zone.motionDetected != null)
              _SensorCard(icon: Icons.directions_run_rounded, label: 'Movimento',
                  value: zone.motionDetected! ? 'Detetado' : 'Sem movimento',
                  color: zone.motionDetected! ? AppTheme.error : AppTheme.textMuted),
          ],
        ),
        const SizedBox(height: 12),
        // Estado das automações
        _AutomationStatusCard(zone: zone),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12), decoration: SS.card(),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, color: AppTheme.textMuted, size: 14),
            SizedBox(width: 8),
            Expanded(child: Text('Dados em tempo real via ESP32',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
          ]),
        ),
      ])
          : Container(
        padding: const EdgeInsets.all(24), decoration: SS.card(),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.sensors_off_rounded, color: AppTheme.textMuted, size: 36),
          SizedBox(height: 10),
          Text('Sem dados de sensores', style: TextStyle(color: AppTheme.textPrimary,
              fontSize: 14, fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('Os dados aparecem aqui quando\no ESP32 estiver ligado.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ]),
      ),
    );
  }
}

class _SensorCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _SensorCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2))),
    child: Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          ])),
    ]),
  );
}

// ── Automation Status Card ────────────────────────────────────────────────────

class _AutomationStatusCard extends StatelessWidget {
  final Zone zone;
  const _AutomationStatusCard({required this.zone});

  @override
  Widget build(BuildContext context) {
    final a = zone.automations;
    final ldr  = zone.luminosity;
    final temp = zone.temperature;
    final hum  = zone.humidity;
    if (ldr == null && temp == null && hum == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: SS.glowCard(glowColor: const Color(0xFF8B5CF6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.auto_fix_high_rounded, color: Color(0xFF8B5CF6), size: 14),
          SizedBox(width: 8),
          Text('Estado das Automações',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        if (ldr != null && a.autoLightEnabled)
          _StatusRow(label: 'Luz automática', sensor: '${ldr.toStringAsFixed(0)}%',
              threshold: '< ${a.ldrThreshold.toStringAsFixed(0)}%',
              triggered: ldr < a.ldrThreshold, color: AppTheme.warning),
        if (temp != null && a.autoTempEnabled) ...[
          if (ldr != null && a.autoLightEnabled) const SizedBox(height: 6),
          _StatusRow(label: 'Alerta temperatura', sensor: '${temp.toStringAsFixed(1)}°C',
              threshold: '> ${a.tempThreshold.toStringAsFixed(0)}°C',
              triggered: temp > a.tempThreshold, color: AppTheme.error),
        ],
        if (hum != null && a.autoHumEnabled) ...[
          if ((ldr != null && a.autoLightEnabled) || (temp != null && a.autoTempEnabled))
            const SizedBox(height: 6),
          _StatusRow(label: 'Alerta humidade', sensor: '${hum.toStringAsFixed(0)}%',
              threshold: '> ${a.humThreshold.toStringAsFixed(0)}%',
              triggered: hum > a.humThreshold, color: AppTheme.accent),
        ],
      ]),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label, sensor, threshold;
  final bool triggered;
  final Color color;
  const _StatusRow({required this.label, required this.sensor, required this.threshold,
    required this.triggered, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(
        color: triggered ? color : AppTheme.textMuted, shape: BoxShape.circle)),
    const SizedBox(width: 8),
    Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
    Text(sensor, style: TextStyle(color: triggered ? color : AppTheme.textMuted,
        fontSize: 12, fontWeight: FontWeight.w700)),
    const SizedBox(width: 4),
    Text(threshold, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
    const SizedBox(width: 8),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: triggered ? color.withOpacity(0.12) : AppTheme.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: triggered ? color.withOpacity(0.4) : AppTheme.border),
      ),
      child: Text(triggered ? 'ATIVA' : 'OK',
          style: TextStyle(color: triggered ? color : AppTheme.textMuted,
              fontSize: 9, fontWeight: FontWeight.w800)),
    ),
  ]);
}

// ── Tab: Configuração ─────────────────────────────────────────────────────────

class _ConfiguracaoTab extends StatefulWidget {
  final Zone zone;
  final SmartSpaceProvider ss;
  const _ConfiguracaoTab({required this.zone, required this.ss});

  @override
  State<_ConfiguracaoTab> createState() => _ConfiguracaoTabState();
}

class _ConfiguracaoTabState extends State<_ConfiguracaoTab> {
  bool _showDemo = false;

  @override
  Widget build(BuildContext context) {
    final z = widget.zone;
    final a = z.automations;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Capacidade ────────────────────────────────────────────────────────
        const SectionLabel(label: 'Capacidade'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14), decoration: SS.card(),
          child: Row(children: [
            const Icon(Icons.groups_rounded, color: AppTheme.accent, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${z.occupantCount} / 10 pessoas',
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
              const Text('Ocupação atual / capacidade máxima',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ])),
            TextButton(onPressed: () {}, child: const Text('Editar')),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Energia ───────────────────────────────────────────────────────────
        const SectionLabel(label: 'Energia'),
        const SizedBox(height: 8),
        ZoneEnergyCard(zone: z, isAdmin: true),
        const SizedBox(height: 16),

        // ── Limiares de Automação ─────────────────────────────────────────────
        const SectionLabel(label: 'Limiares de Automação'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14), decoration: SS.card(),
          child: Column(children: [
            _ThresholdRow(
              icon: Icons.wb_sunny_rounded, label: 'Luminosidade mínima',
              value: '${a.ldrThreshold.toStringAsFixed(0)}%', color: AppTheme.warning,
              enabled: a.autoLightEnabled,
              onToggle: (v) => widget.ss.updateAutomations(z.id, a.copyWith(autoLightEnabled: v)),
              onEdit: () => _showThresholdDialog(context,
                  label: 'Luminosidade mínima', unit: '%', current: a.ldrThreshold,
                  min: 0, max: 100, hint: 'Ligar luz quando luminosidade abaixo deste valor',
                  onSave: (v) => widget.ss.updateAutomations(z.id, a.copyWith(ldrThreshold: v))),
            ),
            const Divider(height: 20),
            _ThresholdRow(
              icon: Icons.thermostat_rounded, label: 'Temperatura máxima',
              value: '${a.tempThreshold.toStringAsFixed(0)}°C', color: AppTheme.error,
              enabled: a.autoTempEnabled,
              onToggle: (v) => widget.ss.updateAutomations(z.id, a.copyWith(autoTempEnabled: v)),
              onEdit: () => _showThresholdDialog(context,
                  label: 'Temperatura máxima', unit: '°C', current: a.tempThreshold,
                  min: 10, max: 50, hint: 'Activar buzzer quando temperatura acima deste valor',
                  onSave: (v) => widget.ss.updateAutomations(z.id, a.copyWith(tempThreshold: v))),
            ),
            const Divider(height: 20),
            _ThresholdRow(
              icon: Icons.water_drop_rounded, label: 'Humidade máxima',
              value: '${a.humThreshold.toStringAsFixed(0)}%', color: AppTheme.accent,
              enabled: a.autoHumEnabled,
              onToggle: (v) => widget.ss.updateAutomations(z.id, a.copyWith(autoHumEnabled: v)),
              onEdit: () => _showThresholdDialog(context,
                  label: 'Humidade máxima', unit: '%', current: a.humThreshold,
                  min: 0, max: 100, hint: 'Activar buzzer quando humidade acima deste valor',
                  onSave: (v) => widget.ss.updateAutomations(z.id, a.copyWith(humThreshold: v))),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Política de Conflitos ─────────────────────────────────────────────
        const SectionLabel(label: 'Política de Resolução de Conflitos'),
        const SizedBox(height: 8),
        _ConflictPolicySelector(zoneId: z.id),
        const SizedBox(height: 16),

        // ── Modo Demo ─────────────────────────────────────────────────────────
        Row(children: [
          const Expanded(child: SectionLabel(label: 'Modo demo')),
          TextButton.icon(
            onPressed: () => setState(() => _showDemo = !_showDemo),
            icon: Icon(_showDemo ? Icons.visibility_off_rounded : Icons.tune_rounded,
                size: 14, color: AppTheme.accent),
            label: Text(_showDemo ? 'Esconder' : 'Simular',
                style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _showDemo
              ? ZoneDemoControls(key: const ValueKey('demo-on'), zoneId: z.id)
              : const ZoneDemoCollapsedCard(key: ValueKey('demo-off')),
        ),
      ]),
    );
  }

  void _showThresholdDialog(BuildContext context, {
    required String label, required String unit, required double current,
    required double min, required double max, required String hint,
    required void Function(double) onSave,
  }) {
    double sliderValue = current.clamp(min, max);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: AppTheme.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Editar $label',
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(hint, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border)),
              child: Text('${sliderValue.toStringAsFixed(0)}$unit',
                  style: const TextStyle(color: AppTheme.textPrimary,
                      fontSize: 28, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),
            Slider(
              value: sliderValue, min: min, max: max,
              divisions: (max - min).toInt(),
              activeColor: AppTheme.accent, inactiveColor: AppTheme.border,
              onChanged: (v) => setStateDialog(() => sliderValue = v),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${min.toInt()}$unit', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              Text('${max.toInt()}$unit', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () { onSave(sliderValue); Navigator.pop(ctx); },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Conflict Policy Selector ──────────────────────────────────────────────────

class _ConflictPolicySelector extends StatefulWidget {
  final String zoneId;
  const _ConflictPolicySelector({required this.zoneId});
  @override
  State<_ConflictPolicySelector> createState() => _ConflictPolicySelectorState();
}

class _ConflictPolicySelectorState extends State<_ConflictPolicySelector> {
  String _selected = 'average';

  final _policies = const [
    ('average', 'Média ponderada', Icons.equalizer_rounded),
    ('priority', 'Prioridade por papel', Icons.shield_rounded),
    ('first', 'Primeiro a chegar', Icons.timer_rounded),
    ('vote', 'Votação', Icons.how_to_vote_rounded),
  ];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14), decoration: SS.card(),
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
                width: active ? 1.5 : 1,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: active ? AppTheme.accent : AppTheme.textMuted, size: 14),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(
                color: active ? AppTheme.accent : AppTheme.textSecondary,
                fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              )),
            ]),
          ),
        );
      }).toList(),
    ),
  );
}

// ── Threshold Row ─────────────────────────────────────────────────────────────

class _ThresholdRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  const _ThresholdRow({required this.icon, required this.label, required this.value,
    required this.color, required this.enabled, required this.onToggle, required this.onEdit});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: enabled ? color : AppTheme.textMuted, size: 16),
    const SizedBox(width: 10),
    Expanded(child: Text(label, style: TextStyle(
        color: enabled ? AppTheme.textSecondary : AppTheme.textMuted, fontSize: 13))),
    Text(value, style: TextStyle(
        color: enabled ? color : AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w700)),
    const SizedBox(width: 8),
    GestureDetector(
      onTap: enabled ? onEdit : null,
      child: Icon(Icons.edit_rounded,
          color: enabled ? AppTheme.textMuted : AppTheme.border, size: 16),
    ),
    const SizedBox(width: 8),
    GestureDetector(
      onTap: () => onToggle(!enabled),
      child: Icon(
        enabled ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
        color: enabled ? color : AppTheme.textMuted, size: 28,
      ),
    ),
  ]);
}

// ── Admin Toggle Button ───────────────────────────────────────────────────────

class _AdminToggleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _AdminToggleButton({required this.icon, required this.label,
    required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.12) : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? color.withOpacity(0.4) : AppTheme.border),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: active ? color : AppTheme.textMuted, size: 18),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(
            color: active ? color : AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
        const Spacer(),
        Icon(active ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
            color: active ? color : AppTheme.textMuted, size: 26),
      ]),
    ),
  );
}

// ── Admin Intensity Slider ────────────────────────────────────────────────────

class _AdminIntensitySlider extends StatefulWidget {
  final Zone zone;
  final SmartSpaceProvider ss;
  const _AdminIntensitySlider({required this.zone, required this.ss});

  @override
  State<_AdminIntensitySlider> createState() => _AdminIntensitySliderState();
}

class _AdminIntensitySliderState extends State<_AdminIntensitySlider> {
  late double _localValue;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _localValue = widget.zone.lightIntensity;
  }

  @override
  void didUpdateWidget(_AdminIntensitySlider old) {
    super.didUpdateWidget(old);
    if (!_dragging) _localValue = widget.zone.lightIntensity;
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
    decoration: SS.card(),
    child: Column(children: [
      Row(children: [
        const Icon(Icons.brightness_6_rounded, color: AppTheme.warning, size: 16),
        const SizedBox(width: 8),
        const Expanded(child: Text('Intensidade',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
        Text('${(_localValue * 100).toInt()}%',
            style: const TextStyle(color: AppTheme.warning, fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
      Slider(
        value: _localValue,
        onChanged: (v) => setState(() { _localValue = v; _dragging = true; }),
        onChangeEnd: (v) { _dragging = false; widget.ss.setLightIntensity(widget.zone.id, v); },
        activeColor: AppTheme.warning, inactiveColor: AppTheme.border,
      ),
    ]),
  );
}

// ── Admin Color Picker Card ───────────────────────────────────────────────────

class _PresetColor {
  final String name;
  final Color color;
  const _PresetColor(this.name, this.color);
}

class _AdminColorPickerCard extends StatelessWidget {
  final Zone zone;
  final SmartSpaceProvider ss;
  const _AdminColorPickerCard({required this.zone, required this.ss});

  static const List<_PresetColor> _presets = [
    _PresetColor('Branco',   Color(0xFFFFFFFF)),
    _PresetColor('Vermelho', Color(0xFFFF0000)),
    _PresetColor('Verde',    Color(0xFF00FF00)),
    _PresetColor('Azul',     Color(0xFF0000FF)),
    _PresetColor('Amarelo',  Color(0xFFFFFF00)),
    _PresetColor('Ciano',    Color(0xFF00FFFF)),
    _PresetColor('Magenta',  Color(0xFFFF00FF)),
    _PresetColor('Laranja',  Color(0xFFFF6600)),
    _PresetColor('Roxo',     Color(0xFF8800FF)),
    _PresetColor('Rosa',     Color(0xFFFF0088)),
  ];

  @override
  Widget build(BuildContext context) {
    final currentColor = zone.lightColor;
    final isWhite = zone.lightR > 200 && zone.lightG > 200 && zone.lightB > 200;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: SS.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: isWhite ? const Color(0xFF2C2C2C) : currentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                  color: isWhite ? const Color(0xFF555555) : currentColor.withOpacity(0.5), width: 1.5),
            ),
            child: Icon(Icons.palette_rounded, color: isWhite ? Colors.white : currentColor, size: 15),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text('Cor do LED',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600))),
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: currentColor,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                  color: isWhite ? const Color(0xFF999999) : currentColor.withOpacity(0.5), width: 1.5),
              boxShadow: [BoxShadow(
                  color: isWhite ? Colors.grey.withOpacity(0.3) : currentColor.withOpacity(0.5),
                  blurRadius: 8, spreadRadius: 1)],
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: _presets.map((preset) {
            final isSelected = zone.lightR == preset.color.red &&
                zone.lightG == preset.color.green && zone.lightB == preset.color.blue;
            final isPresetWhite = preset.color == Colors.white;
            return GestureDetector(
              onTap: () => ss.setLightColor(zone.id, preset.color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isPresetWhite
                      ? (isSelected ? const Color(0xFF2C2C2C) : const Color(0xFFE8E8E8))
                      : preset.color.withOpacity(isSelected ? 0.25 : 0.10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isPresetWhite
                        ? (isSelected ? const Color(0xFF888888) : const Color(0xFFCCCCCC))
                        : (isSelected ? preset.color.withOpacity(0.8) : preset.color.withOpacity(0.3)),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 9, height: 9,
                    decoration: BoxDecoration(
                      color: preset.color, shape: BoxShape.circle,
                      border: isPresetWhite ? Border.all(color: const Color(0xFFAAAAAA), width: 1) : null,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(preset.name, style: TextStyle(
                    color: isPresetWhite ? (isSelected ? Colors.white : AppTheme.textPrimary) : preset.color,
                    fontSize: 11, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  )),
                ]),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        _RgbRow(label: 'R', value: zone.lightR, color: const Color(0xFFFF3333),
            onChanged: (v) => ss.setLightColor(zone.id, Color.fromRGBO(v, zone.lightG, zone.lightB, 1.0))),
        const SizedBox(height: 6),
        _RgbRow(label: 'G', value: zone.lightG, color: const Color(0xFF22CC22),
            onChanged: (v) => ss.setLightColor(zone.id, Color.fromRGBO(zone.lightR, v, zone.lightB, 1.0))),
        const SizedBox(height: 6),
        _RgbRow(label: 'B', value: zone.lightB, color: const Color(0xFF3366FF),
            onChanged: (v) => ss.setLightColor(zone.id, Color.fromRGBO(zone.lightR, zone.lightG, v, 1.0))),
        const SizedBox(height: 10),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppTheme.border)),
            child: Text('RGB(${zone.lightR}, ${zone.lightG}, ${zone.lightB})',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 10,
                    fontWeight: FontWeight.w600, fontFamily: 'monospace')),
          ),
        ),
      ]),
    );
  }
}

class _RgbRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final ValueChanged<int> onChanged;
  const _RgbRow({required this.label, required this.value, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 14, child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700))),
    const SizedBox(width: 6),
    Expanded(
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        ),
        child: Slider(
          value: value.toDouble(), min: 0, max: 255,
          onChanged: (v) => onChanged(v.toInt()),
          activeColor: color, inactiveColor: AppTheme.border,
        ),
      ),
    ),
    const SizedBox(width: 6),
    SizedBox(width: 26, child: Text('$value', textAlign: TextAlign.right,
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w600))),
  ]);
}

// ── Admin Poll Banner ─────────────────────────────────────────────────────────

// ── Admin Poll Banner — usa Consumer para reagir ao estado atual da zona ──────
// CRÍTICO: Não guardar zone como campo — sempre lê do provider para reagir
// imediatamente quando activePoll fica null após votação resolvida.

class _AdminPollBanner extends StatefulWidget {
  final String zoneId; // só o id, não o objeto Zone
  const _AdminPollBanner({required this.zoneId});

  @override
  State<_AdminPollBanner> createState() => _AdminPollBannerState();
}

class _AdminPollBannerState extends State<_AdminPollBanner> {
  int _remaining = 30;
  Timer? _timer;
  ZonePoll? _lastPoll; // para detetar mudança de poll

  void _startTimer(ZonePoll poll) {
    _timer?.cancel();
    _remaining = poll.expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _remaining = (_remaining - 1).clamp(0, 30));
      if (_remaining <= 0) t.cancel();
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Consumer<SmartSpaceProvider>(
      builder: (context, ss, _) {
        // Sempre lê o estado fresco do provider
        final zone = ss.zoneById(widget.zoneId);
        final poll = zone?.activePoll;

        // Poll desapareceu → oculta imediatamente
        if (poll == null) {
          _timer?.cancel();
          _lastPoll = null;
          return const SizedBox.shrink();
        }

        // Poll nova → reinicia timer
        final pollId = '${poll.requestedBy}_${poll.expiresAt.millisecondsSinceEpoch}';
        final lastPollId = _lastPoll != null
            ? '${_lastPoll!.requestedBy}_${_lastPoll!.expiresAt.millisecondsSinceEpoch}'
            : null;
        if (pollId != lastPollId) {
          _lastPoll = poll;
          WidgetsBinding.instance.addPostFrameCallback((_) => _startTimer(poll));
        }

        final alreadyVoted = poll.votes.containsKey(ss.uid);
        final isRequester = poll.requestedBy == ss.uid;
        final yes = poll.yesVotes;
        final no  = poll.noVotes;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.warning.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.how_to_vote_rounded, color: AppTheme.warning, size: 14),
              const SizedBox(width: 6),
              Expanded(child: Text('Votação em curso — ${_remaining}s',
                  style: const TextStyle(color: AppTheme.warning, fontSize: 12, fontWeight: FontWeight.w700))),
              Text('$yes sim · $no não',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ]),
            const SizedBox(height: 6),
            Text('${poll.requestedByName} pediu: ${_actionLabel(poll.action, poll.intensity)}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            if (!alreadyVoted && !isRequester) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () async {
                    final pollSnapshot = poll; // captura antes do await
                    await ss.votePoll(widget.zoneId, false);
                    if (!mounted) return;
                    if (pollSnapshot.action == 'setIntensity' && zone != null) {
                      await Future.delayed(const Duration(milliseconds: 300));
                      if (mounted) _showCounterProposalDialog(context, ss, zone, pollSnapshot);
                    } else if (pollSnapshot.action == 'setColor' && zone != null) {
                      await Future.delayed(const Duration(milliseconds: 300));
                      if (mounted) _showColorCounterProposalDialog(context, ss, zone, pollSnapshot);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                    ),
                    child: const Center(child: Text('Não', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w700, fontSize: 12))),
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(child: GestureDetector(
                  onTap: () => ss.votePoll(widget.zoneId, true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                    ),
                    child: const Center(child: Text('Sim', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w700, fontSize: 12))),
                  ),
                )),
              ]),
            ] else
              Text(isRequester ? 'Aguarda a resposta dos outros...' : 'Votaste — a aguardar os restantes...',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ]),
        );
      },
    );
  }

  String _actionLabel(String action, double? intensity) {
    switch (action) {
      case 'lightOff':      return 'desligar luz';
      case 'lightOn':       return 'ligar luz';
      case 'setIntensity':  return 'intensidade ${intensity != null ? "${(intensity * 100).toInt()}%" : ""}';
      case 'setColor':      return 'mudar cor';
      case 'setModeAuto':   return 'modo AUTO';
      case 'setModeManual': return 'modo MANUAL';
      default:              return action;
    }
  }
}

// ── Counter-Proposal Dialogs (Admin) ─────────────────────────────────────────

void _showCounterProposalDialog(
    BuildContext context, SmartSpaceProvider ss, Zone zone, ZonePoll poll) {
  double sliderValue = zone.lightIntensity;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateDialog) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Qual a tua preferência de intensidade?',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            '${poll.requestedByName} pediu ${(poll.intensity! * 100).toInt()}%.\n'
                'Indica a tua preferência — será calculada a média.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border)),
            child: Text('${(sliderValue * 100).toInt()}%',
                style: const TextStyle(color: AppTheme.textPrimary,
                    fontSize: 28, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
          ),
          Slider(
            value: sliderValue, min: 0, max: 1,
            activeColor: AppTheme.warning, inactiveColor: AppTheme.border,
            onChanged: (v) => setStateDialog(() => sliderValue = v),
          ),
        ]),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            onPressed: () {
              ss.submitCounterProposal(zone.id, intensity: sliderValue);
              Navigator.of(ctx).pop();
            },
            child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

void _showColorCounterProposalDialog(
    BuildContext context, SmartSpaceProvider ss, Zone zone, ZonePoll poll) {
  int r = zone.lightR, g = zone.lightG, b = zone.lightB;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateDialog) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Qual a tua cor preferida?',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            '${poll.requestedByName} pediu uma mudança de cor.\n'
                'Indica a tua preferência — será calculada a média RGB.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Center(child: Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: Color.fromRGBO(r, g, b, 1.0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
          )),
          const SizedBox(height: 8),
          Row(children: [
            SizedBox(width: 16, child: Text('R', style: const TextStyle(color: Color(0xFFFF3333), fontSize: 12, fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            Expanded(child: Slider(value: r.toDouble(), min: 0, max: 255,
                activeColor: const Color(0xFFFF3333), inactiveColor: AppTheme.border,
                onChanged: (v) => setStateDialog(() => r = v.toInt()))),
            SizedBox(width: 30, child: Text('$r', textAlign: TextAlign.right,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11))),
          ]),
          Row(children: [
            SizedBox(width: 16, child: Text('G', style: const TextStyle(color: Color(0xFF22CC22), fontSize: 12, fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            Expanded(child: Slider(value: g.toDouble(), min: 0, max: 255,
                activeColor: const Color(0xFF22CC22), inactiveColor: AppTheme.border,
                onChanged: (v) => setStateDialog(() => g = v.toInt()))),
            SizedBox(width: 30, child: Text('$g', textAlign: TextAlign.right,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11))),
          ]),
          Row(children: [
            SizedBox(width: 16, child: Text('B', style: const TextStyle(color: Color(0xFF3366FF), fontSize: 12, fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            Expanded(child: Slider(value: b.toDouble(), min: 0, max: 255,
                activeColor: const Color(0xFF3366FF), inactiveColor: AppTheme.border,
                onChanged: (v) => setStateDialog(() => b = v.toInt()))),
            SizedBox(width: 30, child: Text('$b', textAlign: TextAlign.right,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11))),
          ]),
        ]),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            onPressed: () {
              ss.submitCounterProposal(zone.id, r: r, g: g, b: b);
              Navigator.of(ctx).pop();
            },
            child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}