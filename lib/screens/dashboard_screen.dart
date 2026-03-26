import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/beacon_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _beaconService = BeaconService();
  final SensorData _sensorData = SensorData.placeholder;
  Room _currentRoom = Room.unknown;
  List<BeaconReading> _beacons = [];

  @override
  void initState() {
    super.initState();
    _beaconService.roomStream.listen((r) { if (mounted) setState(() => _currentRoom = r); });
    _beaconService.beaconsStream.listen((b) { if (mounted) setState(() => _beacons = b); });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            title: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: AppColors.indigo, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.home_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text('Smart Room', style: GoogleFonts.inter(
                  color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
            ]),
            actions: [
              _ConnectionBadge(connected: _currentRoom != Room.unknown),
              const SizedBox(width: 16),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: AppColors.border),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            sliver: SliverList(delegate: SliverChildListDelegate([

              // ─── ROOM BANNER ───────────────
              _RoomBanner(room: _currentRoom),
              const SizedBox(height: 24),

              // ─── SECTION: SENSORES ─────────
              _SectionLabel(text: 'Sensores ambientais'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _MetricCard(
                  label: 'Temperatura',
                  value: _sensorData.temperature.toStringAsFixed(1),
                  unit: '°C',
                  icon: Icons.device_thermostat_rounded,
                  accent: _tempColor(_sensorData.temperature),
                  sublabel: _tempStatus(_sensorData.temperature),
                )),
                const SizedBox(width: 12),
                Expanded(child: _MetricCard(
                  label: 'Humidade',
                  value: _sensorData.humidity.toStringAsFixed(0),
                  unit: '%',
                  icon: Icons.water_drop_outlined,
                  accent: AppColors.teal,
                  sublabel: 'Confortável',
                )),
              ]),
              const SizedBox(height: 12),
              _LuminosityCard(percent: _sensorData.luminosityPercent),
              const SizedBox(height: 28),

              // ─── SECTION: BEACONS ──────────
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _SectionLabel(text: 'Beacons BLE'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.indigoLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${_beacons.length} / 3',
                      style: GoogleFonts.inter(color: AppColors.indigo, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 12),
              _BeaconList(beacons: _beacons),
              const SizedBox(height: 20),

              // ─── NOTE ──────────────────────
              _InfoNote(text: 'Dados de sensores estáticos. Ligação ao ESP32 pendente.'),
            ])),
          ),
        ],
      ),
    );
  }

  Color _tempColor(double t) {
    if (t > 28) return AppColors.rose;
    if (t > 25) return AppColors.amber;
    return AppColors.green;
  }
  String _tempStatus(double t) {
    if (t > 28) return 'Muito quente';
    if (t > 25) return 'Quente';
    if (t < 16) return 'Frio';
    return 'Confortável';
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: AppText.label,
  );
}

class _ConnectionBadge extends StatelessWidget {
  final bool connected;
  const _ConnectionBadge({required this.connected});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: connected ? AppColors.greenDim : AppColors.roseDim,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6,
            decoration: BoxDecoration(
              color: connected ? AppColors.green : AppColors.rose,
              shape: BoxShape.circle,
            )),
        const SizedBox(width: 5),
        Text(connected ? 'Online' : 'Offline',
            style: GoogleFonts.inter(
                color: connected ? AppColors.green : AppColors.rose,
                fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _RoomBanner extends StatelessWidget {
  final Room room;
  const _RoomBanner({required this.room});
  @override
  Widget build(BuildContext context) {
    final isKnown = room != Room.unknown;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isKnown ? AppColors.indigo : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isKnown ? Colors.transparent : AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: isKnown ? Colors.white.withOpacity(0.15) : AppColors.bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(child: Text(room.emoji, style: const TextStyle(fontSize: 24))),
        ),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Localização atual',
              style: GoogleFonts.inter(
                  color: isKnown ? Colors.white.withOpacity(0.7) : AppColors.textSecondary,
                  fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          Text(room.displayName,
              style: GoogleFonts.inter(
                  color: isKnown ? Colors.white : AppColors.textPrimary,
                  fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
        ]),
        const Spacer(),
        if (isKnown)
          Icon(Icons.location_on_rounded, color: Colors.white.withOpacity(0.5), size: 20),
      ]),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label, value, unit, sublabel;
  final IconData icon;
  final Color accent;
  const _MetricCard({required this.label, required this.value, required this.unit,
    required this.icon, required this.accent, required this.sublabel});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label.toUpperCase(), style: AppText.label),
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accent, size: 16),
          ),
        ]),
        const SizedBox(height: 12),
        RichText(text: TextSpan(children: [
          TextSpan(text: value, style: GoogleFonts.inter(
              color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          TextSpan(text: unit, style: GoogleFonts.inter(
              color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w400)),
        ])),
        const SizedBox(height: 6),
        Text(sublabel, style: AppText.body),
      ]),
    );
  }
}

class _LuminosityCard extends StatelessWidget {
  final double percent;
  const _LuminosityCard({required this.percent});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('LUMINOSIDADE', style: AppText.label),
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: AppColors.amberDim,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.wb_sunny_rounded, color: AppColors.amber, size: 16),
          ),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${percent.toStringAsFixed(0)}', style: GoogleFonts.inter(
              color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          Text('%', style: GoogleFonts.inter(
              color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w400)),
          const Spacer(),
          Text(
              percent < 30 ? 'Escuro' : percent < 70 ? 'Médio' : 'Claro',
              style: GoogleFonts.inter(
                  color: AppColors.amber, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percent / 100,
            backgroundColor: AppColors.border,
            color: AppColors.amber,
            minHeight: 8,
          ),
        ),
      ]),
    );
  }
}

class _BeaconList extends StatelessWidget {
  final List<BeaconReading> beacons;
  const _BeaconList({required this.beacons});
  @override
  Widget build(BuildContext context) {
    if (beacons.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: [
          Icon(Icons.bluetooth_disabled_rounded, color: AppColors.textMuted, size: 32),
          const SizedBox(height: 8),
          Text('Nenhum beacon detetado', style: AppText.body),
        ]),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: beacons.asMap().entries.map((e) {
          final i = e.key; final b = e.value;
          return Column(children: [
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: i == 0 ? AppColors.indigoLight : AppColors.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Text(b.room.emoji, style: const TextStyle(fontSize: 16))),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.room.displayName, style: AppText.title),
                  Text('Major ${b.major} · Minor ${b.minor}', style: AppText.body),
                ]),
                const Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(b.signalBar, style: GoogleFonts.inter(
                      color: i == 0 ? AppColors.indigo : AppColors.textMuted, fontSize: 12)),
                  Text('${b.rssi} dBm', style: GoogleFonts.inter(
                      color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
                ]),
              ]),
            ),
          ]);
        }).toList(),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  final String text;
  const _InfoNote({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.indigoLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.indigo.withOpacity(0.15)),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, color: AppColors.indigo, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: GoogleFonts.inter(
            color: AppColors.indigo, fontSize: 12, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}