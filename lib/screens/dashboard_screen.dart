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

  // Dados estáticos enquanto não há ESP32
  // Quando integrares o MQTT, substituis por um Stream
  final SensorData _sensorData = SensorData.placeholder;

  Room _currentRoom = Room.unknown;
  List<BeaconReading> _beacons = [];

  @override
  void initState() {
    super.initState();
    _beaconService.roomStream.listen((room) {
      if (mounted) setState(() => _currentRoom = room);
    });
    _beaconService.beaconsStream.listen((beacons) {
      if (mounted) setState(() => _beacons = beacons);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Room'),
        actions: [
          _ConnectionDot(connected: _currentRoom != Room.unknown),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ─── SALA ATUAL ───────────────────
          _RoomCard(room: _currentRoom, beacons: _beacons),
          const SizedBox(height: 16),

          // ─── SENSORES (estáticos por agora)
          Text('Sensores', style: AppText.label),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _SensorCard(
              label: 'Temperatura',
              value: '${_sensorData.temperature.toStringAsFixed(1)}°',
              unit: 'C',
              icon: Icons.thermostat_rounded,
              color: _tempColor(_sensorData.temperature),
              sublabel: _tempStatus(_sensorData.temperature),
            )),
            const SizedBox(width: 12),
            Expanded(child: _SensorCard(
              label: 'Humidade',
              value: '${_sensorData.humidity.toStringAsFixed(0)}',
              unit: '%',
              icon: Icons.water_drop_rounded,
              color: AppColors.green,
              sublabel: 'Normal',
            )),
          ]),
          const SizedBox(height: 12),
          _LuminosityCard(luminosityPercent: _sensorData.luminosityPercent),

          const SizedBox(height: 24),

          // ─── BEACONS DETETADOS ────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Beacons detetados', style: AppText.label),
              Text('${_beacons.length}/3', style: AppText.label),
            ],
          ),
          const SizedBox(height: 10),
          _BeaconList(beacons: _beacons),

          const SizedBox(height: 24),

          // ─── NOTA DE PLACEHOLDER ──────────
          _PlaceholderNote(),
        ],
      ),
    );
  }

  Color _tempColor(double temp) {
    if (temp > 28) return AppColors.red;
    if (temp > 25) return AppColors.orange;
    if (temp < 16) return AppColors.green;
    return AppColors.green;
  }

  String _tempStatus(double temp) {
    if (temp > 28) return 'Muito quente';
    if (temp > 25) return 'Quente';
    if (temp < 16) return 'Frio';
    return 'Confortável';
  }
}

// ─── CARD DA SALA ATUAL ───────────────────────
class _RoomCard extends StatelessWidget {
  final Room room;
  final List<BeaconReading> beacons;

  const _RoomCard({required this.room, required this.beacons});

  @override
  Widget build(BuildContext context) {
    final isKnown = room != Room.unknown;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isKnown ? AppColors.green.withOpacity(0.3) : AppColors.border,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isKnown ? AppColors.cyanDim : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                room.emoji,
                style: const TextStyle(fontSize: 26),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Localização atual', style: AppText.label),
                const SizedBox(height: 4),
                Text(
                  room.displayName,
                  style: GoogleFonts.dmSans(
                    color: isKnown ? AppColors.textPrimary : AppColors.textSecondary,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
          if (isKnown)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.cyanDim,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Ativo',
                style: GoogleFonts.dmSans(
                  color: AppColors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── CARD DE SENSOR ───────────────────────────
class _SensorCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final String sublabel;

  const _SensorCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppText.label),
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: value, style: AppText.value(color)),
                TextSpan(
                  text: unit,
                  style: GoogleFonts.jetBrainsMono(
                    color: color.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(sublabel, style: AppText.body),
        ],
      ),
    );
  }
}

// ─── CARD DE LUMINOSIDADE ─────────────────────
class _LuminosityCard extends StatelessWidget {
  final double luminosityPercent;

  const _LuminosityCard({required this.luminosityPercent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Luminosidade', style: AppText.label),
              Icon(Icons.light_mode_rounded, color: AppColors.orange, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${luminosityPercent.toStringAsFixed(0)}',
                style: AppText.value(AppColors.orange),
              ),
              Text(
                '%',
                style: GoogleFonts.jetBrainsMono(
                  color: AppColors.orange.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                luminosityPercent < 30 ? 'Escuro' : luminosityPercent < 70 ? 'Médio' : 'Claro',
                style: AppText.body,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Barra de progresso
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: luminosityPercent / 100,
              backgroundColor: AppColors.border,
              color: AppColors.orange,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── LISTA DE BEACONS ─────────────────────────
class _BeaconList extends StatelessWidget {
  final List<BeaconReading> beacons;

  const _BeaconList({required this.beacons});

  @override
  Widget build(BuildContext context) {
    if (beacons.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Center(
          child: Text('Nenhum beacon detetado', style: AppText.body),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: beacons.asMap().entries.map((e) {
          final i = e.key;
          final b = e.value;
          return Column(
            children: [
              if (i > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == 0 ? AppColors.green : AppColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(b.room.displayName, style: AppText.title),
                    const Spacer(),
                    Text(
                      b.signalBar,
                      style: GoogleFonts.jetBrainsMono(
                        color: i == 0 ? AppColors.green : AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 64,
                      child: Text(
                        '${b.rssi} dBm',
                        textAlign: TextAlign.end,
                        style: GoogleFonts.jetBrainsMono(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─── NOTA DE PLACEHOLDER ──────────────────────
class _PlaceholderNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.orange.withOpacity(0.2), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.orange, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sensores com dados estáticos. Atualizam automaticamente quando o ESP32 estiver ligado.',
              style: GoogleFonts.dmSans(
                color: AppColors.orange.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── INDICADOR DE CONEXÃO ─────────────────────
class _ConnectionDot extends StatefulWidget {
  final bool connected;
  const _ConnectionDot({required this.connected});

  @override
  State<_ConnectionDot> createState() => _ConnectionDotState();
}

class _ConnectionDotState extends State<_ConnectionDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: widget.connected ? _anim : const AlwaysStoppedAnimation(1.0),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.connected ? AppColors.green : AppColors.textMuted,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}