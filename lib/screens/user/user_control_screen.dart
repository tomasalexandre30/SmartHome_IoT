import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/smartspace_provider.dart';
import '../../services/beacon_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../models/models.dart';

class UserControlScreen extends StatelessWidget {
  const UserControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<SmartSpaceProvider, BeaconService>(
      builder: (context, ss, ble, _) {
        final currentZoneId = ss.currentZoneId ?? ble.currentZoneId;
        final currentZone =
            ss.zones.where((z) => z.id == currentZoneId).firstOrNull;

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(title: const Text('Controlo')),
          body: currentZone == null
              ? _NoZoneState(scanning: ble.scanning)
              : ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              _CurrentZoneBanner(zone: currentZone),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Controlos'),
              const SizedBox(height: 10),
              _ControlsGrid(zone: currentZone),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Sensores da zona'),
              const SizedBox(height: 10),
              _SensorsCard(zone: currentZone),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Estado das outras zonas'),
              const SizedBox(height: 10),
              ...ss.zones
                  .where((z) => z.id != currentZoneId)
                  .map((z) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OtherZoneRow(zone: z),
              )),
            ],
          ),
        );
      },
    );
  }
}

// ── No Zone State ──────────────────────────────────────────────────────────────

class _NoZoneState extends StatelessWidget {
  final bool scanning;
  const _NoZoneState({required this.scanning});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                scanning ? Icons.bluetooth_searching_rounded : Icons.location_off_rounded,
                color: AppTheme.accent,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              scanning ? 'À procura da tua zona...' : 'Nenhuma zona detetada',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              scanning
                  ? 'Os controlos ficam disponíveis quando a tua zona for detetada.'
                  : 'Ativa o scan BLE no Dashboard para detetar a tua zona.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Current Zone Banner ────────────────────────────────────────────────────────

class _CurrentZoneBanner extends StatelessWidget {
  final Zone zone;
  const _CurrentZoneBanner({required this.zone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: SS.glowCard(glowColor: zone.color),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: zone.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(zone.icon, color: zone.color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Zona atual',
                    style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(zone.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.people_rounded, size: 12, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      '${zone.occupantCount} ocupante${zone.occupantCount != 1 ? "s" : ""}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ZoneStatusBadge(zone: zone),
        ],
      ),
    );
  }
}

// ── Controls Grid ──────────────────────────────────────────────────────────────

class _ControlsGrid extends StatelessWidget {
  final Zone zone;
  const _ControlsGrid({required this.zone});

  @override
  Widget build(BuildContext context) {
    final ss = context.read<SmartSpaceProvider>();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _BigToggleBtn(
                icon: zone.lightOn
                    ? Icons.lightbulb_rounded
                    : Icons.lightbulb_outline_rounded,
                label: 'LED RGB',
                sublabel: zone.lightOn ? 'Ligado' : 'Desligado',
                active: zone.lightOn,
                color: AppTheme.warning,
                onTap: () => ss.toggleLight(zone.id),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BigToggleBtn(
                icon: zone.buzzerOn
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                label: 'Buzzer',
                sublabel: zone.buzzerOn ? 'Ativo' : 'Inativo',
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            decoration: SS.card(),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: SS.iconBox(color: AppTheme.warning),
                      child: const Icon(Icons.brightness_6_rounded,
                          color: AppTheme.warning, size: 16),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Intensidade da luz',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${(zone.lightIntensity * 100).toInt()}%',
                        style: const TextStyle(
                            color: AppTheme.warning,
                            fontSize: 13,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    value: zone.lightIntensity,
                    onChanged: (v) => ss.setLightIntensity(zone.id, v),
                    activeColor: AppTheme.warning,
                    inactiveColor: AppTheme.border,
                  ),
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0%', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                    Text('100%', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Big Toggle Button ──────────────────────────────────────────────────────────

class _BigToggleBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _BigToggleBtn({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.10) : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? color.withOpacity(0.35) : AppTheme.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: active ? color.withOpacity(0.15) : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon,
                      color: active ? color : AppTheme.textMuted, size: 22),
                ),
                Switch(
                  value: active,
                  onChanged: (_) => onTap(),
                  activeColor: color,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(label,
                style: TextStyle(
                  color: active ? AppTheme.textPrimary : AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: active ? color : AppTheme.textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(sublabel,
                    style: TextStyle(
                      color: active ? color : AppTheme.textMuted,
                      fontSize: 12,
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sensors Card ───────────────────────────────────────────────────────────────

class _SensorsCard extends StatelessWidget {
  final Zone zone;
  const _SensorsCard({required this.zone});

  @override
  Widget build(BuildContext context) {
    final hasData = zone.temperature != null ||
        zone.humidity != null ||
        zone.luminosity != null ||
        zone.motionDetected != null;

    if (!hasData) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: SS.card(),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: SS.iconBox(color: AppTheme.textMuted),
              child: const Icon(Icons.sensors_off_rounded,
                  color: AppTheme.textMuted, size: 20),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sem dados de sensores',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: 2),
                  Text('Aguarda a ligação ao ESP32.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: SS.card(),
      child: Column(
        children: [
          if (zone.temperature != null)
            _SensorRow(icon: Icons.thermostat_rounded, label: 'Temperatura',
                value: '${zone.temperature!.toStringAsFixed(1)}°C', color: AppTheme.warning),
          if (zone.humidity != null) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            _SensorRow(icon: Icons.water_drop_rounded, label: 'Humidade',
                value: '${zone.humidity!.toStringAsFixed(0)}%', color: AppTheme.accent),
          ],
          if (zone.luminosity != null) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            _SensorRow(icon: Icons.wb_sunny_rounded, label: 'Luminosidade',
                value: '${zone.luminosity!.toStringAsFixed(0)} lx',
                color: const Color(0xFFFFB830)),
          ],
          if (zone.motionDetected != null) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            _SensorRow(
              icon: Icons.motion_photos_on_rounded,
              label: 'Movimento',
              value: zone.motionDetected! ? 'Detetado' : 'Sem movimento',
              color: zone.motionDetected! ? AppTheme.success : AppTheme.textMuted,
            ),
          ],
        ],
      ),
    );
  }
}

class _SensorRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SensorRow({
    required this.icon, required this.label,
    required this.value, required this.color,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      children: [
        Container(
          width: 38, height: 38,
          decoration: SS.iconBox(color: color),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14))),
        Text(value,
            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

// ── Other Zone Row ─────────────────────────────────────────────────────────────

class _OtherZoneRow extends StatelessWidget {
  final Zone zone;
  const _OtherZoneRow({required this.zone});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: SS.card(),
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
              Text(zone.name,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.people_rounded, size: 12, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    '${zone.occupantCount} ocupante${zone.occupantCount != 1 ? "s" : ""}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        ZoneStatusBadge(zone: zone),
      ],
    ),
  );
}