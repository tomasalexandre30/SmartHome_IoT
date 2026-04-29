import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/smartspace_provider.dart';
import '../services/beacon_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../models/models.dart';
import 'zone_detail_screen.dart';

class ControlScreen extends StatelessWidget {
  const ControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<SmartSpaceProvider, BeaconService>(
      builder: (context, ss, ble, _) {
        final currentZoneId = ss.currentZoneId ?? ble.currentZoneId;

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.background,
            elevation: 0,
            title: const Text('Controlo'),
            actions: [
              _ManualZoneSelector(
                zones: ss.zones,
                currentZoneId: currentZoneId,
                onSelect: (id) => ss.updateZoneFromBeacon(id),
              ),
            ],
          ),
          body: ss.zones.isEmpty
              ? const Center(
            child: Text(
              'Sem zonas configuradas',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          )
              : ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              _ControlHero(
                zones: ss.zones,
                currentZoneId: currentZoneId,
                scanning: ble.scanning,
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Zonas controláveis'),
              ...ss.zones.map(
                    (zone) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ZoneControlCard(
                    zone: zone,
                    isCurrentZone: currentZoneId == zone.id,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ControlHero extends StatelessWidget {
  final List<Zone> zones;
  final String? currentZoneId;
  final bool scanning;

  const _ControlHero({
    required this.zones,
    required this.currentZoneId,
    required this.scanning,
  });

  @override
  Widget build(BuildContext context) {
    final activeLights = zones.where((z) => z.lightOn).length;
    final activeBuzzers = zones.where((z) => z.buzzerOn).length;
    final currentZone = zones.where((z) => z.id == currentZoneId).firstOrNull;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: SS.glowCard(glowColor: currentZone?.color ?? AppTheme.accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: (currentZone?.color ?? AppTheme.accent).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  currentZone?.icon ?? Icons.tune_rounded,
                  color: currentZone?.color ?? AppTheme.accent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Painel de controlo',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      currentZone != null
                          ? 'Zona atual: ${currentZone.name}'
                          : 'Nenhuma zona ativa',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: SS.pill(
                  color: scanning ? AppTheme.success : AppTheme.textMuted,
                ),
                child: Text(
                  scanning ? 'BLE ativo' : 'BLE off',
                  style: TextStyle(
                    color: scanning ? AppTheme.success : AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniControlStat(
                  icon: Icons.lightbulb_rounded,
                  label: 'Luzes ligadas',
                  value: '$activeLights',
                  color: AppTheme.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniControlStat(
                  icon: Icons.volume_up_rounded,
                  label: 'Buzzers ativos',
                  value: '$activeBuzzers',
                  color: AppTheme.error,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniControlStat(
                  icon: Icons.meeting_room_rounded,
                  label: 'Zonas',
                  value: '${zones.length}',
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniControlStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniControlStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
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

class _ZoneControlCard extends StatelessWidget {
  final Zone zone;
  final bool isCurrentZone;

  const _ZoneControlCard({
    required this.zone,
    required this.isCurrentZone,
  });

  @override
  Widget build(BuildContext context) {
    final ss = context.read<SmartSpaceProvider>();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrentZone ? zone.color : AppTheme.border,
          width: isCurrentZone ? 1.5 : 1,
        ),
        boxShadow: isCurrentZone
            ? [
          BoxShadow(
            color: zone.color.withOpacity(0.17),
            blurRadius: 20,
          ),
        ]
            : null,
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ZoneDetailScreen(zoneId: zone.id),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: zone.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(zone.icon, color: zone.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                zone.name,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (isCurrentZone) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: SS.pill(color: zone.color),
                                child: Text(
                                  'Aqui',
                                  style: TextStyle(
                                    color: zone.color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${zone.occupantCount} ocupante${zone.occupantCount == 1 ? "" : "s"} · ${zone.statusLabel}',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textMuted,
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _CommandButton(
                        icon: zone.lightOn
                            ? Icons.lightbulb_rounded
                            : Icons.lightbulb_outline_rounded,
                        label: 'LED RGB',
                        status: zone.lightOn ? 'Ligado' : 'Desligado',
                        color: AppTheme.warning,
                        active: zone.lightOn,
                        onTap: () => ss.toggleLight(zone.id),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CommandButton(
                        icon: zone.buzzerOn
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        label: 'Buzzer',
                        status: zone.buzzerOn ? 'Ativo' : 'Inativo',
                        color: AppTheme.error,
                        active: zone.buzzerOn,
                        onTap: () => ss.toggleBuzzer(zone.id),
                      ),
                    ),
                  ],
                ),

                if (zone.lightOn) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: SS.card(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.brightness_6_rounded,
                              color: AppTheme.warning,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Intensidade',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${(zone.lightIntensity * 100).round()}%',
                              style: const TextStyle(
                                color: AppTheme.warning,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: zone.lightIntensity,
                          min: 0,
                          max: 1,
                          divisions: 10,
                          onChanged: (v) => ss.setLightIntensity(zone.id, v),
                          activeColor: AppTheme.warning,
                          inactiveColor: AppTheme.border,
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                _SensorSummary(zone: zone),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String status;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _CommandButton({
    required this.icon,
    required this.label,
    required this.status,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.14) : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? color.withOpacity(0.45) : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: active ? color : AppTheme.textMuted,
              size: 21,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: active ? color : AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    status,
                    style: TextStyle(
                      color: active ? color : AppTheme.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              active ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
              color: active ? color : AppTheme.textMuted,
              size: 30,
            ),
          ],
        ),
      ),
    );
  }
}

class _SensorSummary extends StatelessWidget {
  final Zone zone;

  const _SensorSummary({
    required this.zone,
  });

  @override
  Widget build(BuildContext context) {
    final hasAnySensor = zone.temperature != null ||
        zone.humidity != null ||
        zone.luminosity != null ||
        zone.motionDetected != null;

    if (!hasAnySensor) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: SS.card(),
        child: const Row(
          children: [
            Icon(Icons.sensors_rounded, color: AppTheme.textMuted, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sem dados de sensores. Usa o modo demo ou liga o ESP32.',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: SS.card(),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          if (zone.temperature != null)
            _SensorMiniChip(
              icon: Icons.thermostat_rounded,
              value: '${zone.temperature!.toStringAsFixed(1)}°C',
              color: AppTheme.warning,
            ),
          if (zone.humidity != null)
            _SensorMiniChip(
              icon: Icons.water_drop_rounded,
              value: '${zone.humidity!.toStringAsFixed(0)}%',
              color: AppTheme.accent,
            ),
          if (zone.luminosity != null)
            _SensorMiniChip(
              icon: Icons.wb_sunny_rounded,
              value: '${zone.luminosity!.toStringAsFixed(0)} lx',
              color: AppTheme.warning,
            ),
          if (zone.motionDetected != null)
            _SensorMiniChip(
              icon: Icons.motion_photos_on_rounded,
              value: zone.motionDetected! ? 'Movimento' : 'Sem movimento',
              color: zone.motionDetected! ? AppTheme.success : AppTheme.textMuted,
            ),
        ],
      ),
    );
  }
}

class _SensorMiniChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _SensorMiniChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: SS.pill(color: color),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualZoneSelector extends StatelessWidget {
  final List<Zone> zones;
  final String? currentZoneId;
  final ValueChanged<String?> onSelect;

  const _ManualZoneSelector({
    required this.zones,
    this.currentZoneId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.room_rounded, color: AppTheme.accent),
      tooltip: 'Simular zona',
      onPressed: () => showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.surfaceCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        builder: (_) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Simular zona atual',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Útil para testar a app sem depender do BLE.',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              ...zones.map(
                    (z) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(z.icon, color: z.color),
                  title: Text(
                    z.name,
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  trailing: currentZoneId == z.id
                      ? const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.success,
                  )
                      : null,
                  onTap: () {
                    onSelect(z.id);
                    Navigator.pop(context);
                  },
                ),
              ),
              const Divider(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.clear_rounded,
                  color: AppTheme.textMuted,
                ),
                title: const Text(
                  'Nenhuma zona',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
                onTap: () {
                  onSelect(null);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
