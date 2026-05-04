import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

// ── ZoneStatusBadge ───────────────────────────────────────────────────────────

class ZoneStatusBadge extends StatelessWidget {
  final Zone zone;
  const ZoneStatusBadge({super.key, required this.zone});

  @override
  Widget build(BuildContext context) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: SS.pill(color: zone.statusColor),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(
            color: zone.statusColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: zone.statusColor.withOpacity(0.5),
                  blurRadius: 6,
                  spreadRadius: 1)
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(zone.statusLabel,
            style: TextStyle(
                color: zone.statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

// ── SensorTile ────────────────────────────────────────────────────────────────

class SensorTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const SensorTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: SS.glowCard(glowColor: color),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color ?? AppTheme.accent, size: 20),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
              color: color ?? AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            )),
      ],
    ),
  );
}

// ── ZoneCard ──────────────────────────────────────────────────────────────────

class ZoneCard extends StatelessWidget {
  final Zone zone;
  final bool isCurrentZone;
  final VoidCallback? onTap;

  const ZoneCard({
    super.key,
    required this.zone,
    this.isCurrentZone = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentZone ? zone.color : AppTheme.border,
          width: isCurrentZone ? 1.5 : 1,
        ),
        boxShadow: isCurrentZone
            ? [
          BoxShadow(
              color: zone.color.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 0)
        ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: zone.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(zone.icon,
                      color: zone.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(zone.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium),
                          if (isCurrentZone) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2),
                              decoration:
                              SS.pill(color: zone.color),
                              child: Text('Aqui',
                                  style: TextStyle(
                                      color: zone.color,
                                      fontSize: 10,
                                      fontWeight:
                                      FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                          '${zone.occupantCount} ocupante${zone.occupantCount != 1 ? "s" : ""}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall),
                    ],
                  ),
                ),
                ZoneStatusBadge(zone: zone),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                _ActuatorChip(
                  icon: Icons.lightbulb_rounded,
                  label: 'Luz',
                  active: zone.lightOn,
                  color: AppTheme.warning,
                ),
                const SizedBox(width: 8),
                _ActuatorChip(
                  icon: Icons.volume_up_rounded,
                  label: 'Buzzer',
                  active: zone.buzzerOn,
                  color: AppTheme.error,
                ),
                const Spacer(),
                if (zone.temperature != null)
                  Text(
                      '${zone.temperature!.toStringAsFixed(1)}°C',
                      style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ActuatorChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color color;

  const _ActuatorChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration:
    SS.pill(color: active ? color : AppTheme.textMuted),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 12,
            color: active ? color : AppTheme.textMuted),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active ? color : AppTheme.textMuted,
            )),
      ],
    ),
  );
}

// ── QuickToggle ───────────────────────────────────────────────────────────────

class QuickToggle extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  final double size;

  const QuickToggle({
    super.key,
    required this.icon,
    required this.active,
    required this.color,
    required this.onTap,
    this.size = 34,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size, height: size,
      decoration: BoxDecoration(
        color: active
            ? color.withOpacity(0.15)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(
            color: active
                ? color.withOpacity(0.4)
                : AppTheme.border),
      ),
      child: Icon(icon,
          color: active ? color : AppTheme.textMuted,
          size: size * 0.47),
    ),
  );
}

// ── SectionLabel ──────────────────────────────────────────────────────────────

class SectionLabel extends StatelessWidget {
  final String label;
  const SectionLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: const TextStyle(
      color: AppTheme.textMuted,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    ),
  );
}

// ── BleInfoBar ────────────────────────────────────────────────────────────────

class BleInfoBar extends StatelessWidget {
  final Beacon beacon;
  final bool showDistance;
  final bool rounded;

  const BleInfoBar({
    super.key,
    required this.beacon,
    this.showDistance = true,
    this.rounded = true,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: AppTheme.accentLight,
      borderRadius: rounded
          ? const BorderRadius.vertical(
          bottom: Radius.circular(14))
          : BorderRadius.zero,
    ),
    child: Row(
      children: [
        const Icon(Icons.bluetooth_searching_rounded,
            color: AppTheme.accent, size: 12),
        const SizedBox(width: 6),
        Text(
          showDistance
              ? '${beacon.name} · ${beacon.rssi} dBm · ${beacon.distance.toStringAsFixed(1)}m'
              : '${beacon.name} · ${beacon.rssi} dBm',
          style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 10,
              fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        Text(beacon.signalBar,
            style: TextStyle(
                color: beacon.signalColor, fontSize: 10)),
      ],
    ),
  );
}

// ── BeaconSignalRow ───────────────────────────────────────────────────────────

class BeaconSignalRow extends StatelessWidget {
  final Beacon beacon;
  final bool isActive;

  const BeaconSignalRow(
      {super.key, required this.beacon, this.isActive = false});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    padding: const EdgeInsets.symmetric(
        horizontal: 14, vertical: 10),
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: isActive
          ? AppTheme.accentLight
          : AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
          color:
          isActive ? AppTheme.accent : AppTheme.border),
    ),
    child: Row(
      children: [
        Icon(Icons.bluetooth_rounded,
            color: beacon.isNearby
                ? AppTheme.accent
                : AppTheme.textMuted,
            size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(beacon.name,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              Text(beacon.uuid,
                  style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10)),
            ],
          ),
        ),
        if (beacon.isNearby) ...[
          Text(beacon.signalBar,
              style: TextStyle(
                  color: beacon.signalColor, fontSize: 13)),
          const SizedBox(width: 8),
          Text('${beacon.rssi} dBm',
              style: TextStyle(
                  color: beacon.signalColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text('${beacon.distance.toStringAsFixed(1)}m',
              style: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 11)),
        ] else
          const Text('Fora de alcance',
              style: TextStyle(
                  color: AppTheme.textMuted, fontSize: 11)),
      ],
    ),
  );
}

// ── LogTile ───────────────────────────────────────────────────────────────────

class LogTile extends StatelessWidget {
  final LogEvent event;
  const LogTile({super.key, required this.event});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: event.color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child:
          Icon(event.icon, color: event.color, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.message,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13)),
              const SizedBox(height: 2),
              Text(_formatTime(event.timestamp),
                  style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10)),
            ],
          ),
        ),
      ],
    ),
  );

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'agora mesmo';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes}min';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── SectionHeader ─────────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader(
      {super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Text(title,
            style:
            Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

// ── ConnectionBanner ──────────────────────────────────────────────────────────

class ConnectionBanner extends StatelessWidget {
  final bool connected;
  const ConnectionBanner(
      {super.key, required this.connected});

  @override
  Widget build(BuildContext context) {
    if (connected) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          vertical: 10, horizontal: 16),
      color: AppTheme.error.withOpacity(0.12),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.wifi_off_rounded,
                color: AppTheme.error, size: 14),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Modo autónomo',
                    style: TextStyle(
                        color: AppTheme.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                Text(
                    'Sem ligação ao servidor — comandos guardados localmente',
                    style: TextStyle(
                        color: AppTheme.error, fontSize: 10)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('OFFLINE',
                style: TextStyle(
                    color: AppTheme.error,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }
}

// ── ReconnectedBanner ─────────────────────────────────────────────────────────

class ReconnectedBanner extends StatefulWidget {
  final bool connected;
  const ReconnectedBanner(
      {super.key, required this.connected});

  @override
  State<ReconnectedBanner> createState() =>
      _ReconnectedBannerState();
}

class _ReconnectedBannerState extends State<ReconnectedBanner> {
  bool _show = false;
  bool _wasDisconnected = false;

  @override
  void didUpdateWidget(ReconnectedBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.connected &&
        widget.connected &&
        _wasDisconnected) {
      setState(() => _show = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _show = false);
      });
    }
    if (!widget.connected) _wasDisconnected = true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          vertical: 10, horizontal: 16),
      color: AppTheme.success.withOpacity(0.12),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.wifi_rounded,
                color: AppTheme.success, size: 14),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ligação restabelecida',
                    style: TextStyle(
                        color: AppTheme.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                Text('A sincronizar comandos pendentes...',
                    style: TextStyle(
                        color: AppTheme.success,
                        fontSize: 10)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('ONLINE',
                style: TextStyle(
                    color: AppTheme.success,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }
}