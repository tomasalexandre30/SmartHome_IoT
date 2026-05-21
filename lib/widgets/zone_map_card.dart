import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/smartspace_provider.dart';
import '../services/beacon_service.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modelo interno do mapa
// ─────────────────────────────────────────────────────────────────────────────

/// Posição normalizada (0.0–1.0) de um elemento no mapa
class _MapPoint {
  final double x, y;
  const _MapPoint(this.x, this.y);
}

/// Layout fixo das 3 zonas: posição + tamanho normalizados
class _ZoneLayout {
  final String zoneId;
  final _MapPoint topLeft;
  final _MapPoint bottomRight;
  final String label;

  const _ZoneLayout({
    required this.zoneId,
    required this.topLeft,
    required this.bottomRight,
    required this.label,
  });

  Rect toRect(Size size) => Rect.fromLTRB(
    topLeft.x * size.width,
    topLeft.y * size.height,
    bottomRight.x * size.width,
    bottomRight.y * size.height,
  );
}

/// Posição do beacon/ESP32 dentro de cada zona (normalizado)
const Map<String, _MapPoint> _beaconPositions = {
  'zone_a': _MapPoint(0.78, 0.18),
  'zone_b': _MapPoint(0.78, 0.62),
  'zone_c': _MapPoint(0.22, 0.62),
};

/// Layout das zonas no mapa — planta tipo apartamento simples
const List<_ZoneLayout> _zoneLayouts = [
  _ZoneLayout(
    zoneId: 'zone_a',
    topLeft: _MapPoint(0.37, 0.04),
    bottomRight: _MapPoint(0.96, 0.48),
    label: 'Sala',
  ),
  _ZoneLayout(
    zoneId: 'zone_b',
    topLeft: _MapPoint(0.37, 0.52),
    bottomRight: _MapPoint(0.96, 0.96),
    label: 'Quarto',
  ),
  _ZoneLayout(
    zoneId: 'zone_c',
    topLeft: _MapPoint(0.04, 0.52),
    bottomRight: _MapPoint(0.33, 0.96),
    label: 'Escritório',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Widget principal — ZoneMapCard
// ─────────────────────────────────────────────────────────────────────────────

class ZoneMapCard extends StatefulWidget {
  const ZoneMapCard({super.key});

  @override
  State<ZoneMapCard> createState() => _ZoneMapCardState();
}

class _ZoneMapCardState extends State<ZoneMapCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  String? _selectedZoneId;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ss = context.watch<SmartSpaceProvider>();
    final ble = context.watch<BeaconService>();
    final db = context.read<DatabaseService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────
        Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.map_rounded,
                  color: AppTheme.accent, size: 16),
            ),
            const SizedBox(width: 10),
            const Text(
              'Mapa de Zonas',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            // Legenda compacta
            _LegendChip(color: AppTheme.success, label: 'Ocupada'),
            const SizedBox(width: 8),
            _LegendChip(color: AppTheme.border, label: 'Livre'),
          ],
        ),
        const SizedBox(height: 14),

        // ── Mapa ────────────────────────────────────────────────────
        StreamBuilder<List<OnlineUser>>(
          stream: db.onlineUsersStream(),
          builder: (context, snapshot) {
            final onlineUsers = snapshot.data ?? [];

            return Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceSubtle,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: AspectRatio(
                  aspectRatio: 1.4,
                  child: GestureDetector(
                    onTapDown: (d) =>
                        _handleTap(d.localPosition, context),
                    child: AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (context, _) => CustomPaint(
                        painter: _ZoneMapPainter(
                          zones: ss.zones,
                          beacons: ble.beacons,
                          onlineUsers: onlineUsers,
                          selectedZoneId: _selectedZoneId,
                          pulseValue: _pulseCtrl.value,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // ── Detalhe da zona selecionada ──────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: _selectedZoneId != null
              ? _ZoneDetailPanel(
            zoneId: _selectedZoneId!,
            onClose: () => setState(() => _selectedZoneId = null),
          )
              : const SizedBox(height: 10),
        ),
      ],
    );
  }

  void _handleTap(Offset localPos, BuildContext context) {
    // Obtém o tamanho do widget a partir do RenderBox
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    // O mapa ocupa a área do CustomPaint dentro do AspectRatio.
    // Calculamos a posição normalizada do toque.
    final mapWidth = box.size.width - 32; // padding das margens do card
    final mapHeight = mapWidth / 1.4;

    // Offset do toque relativo ao mapa (ignora header acima)
    // Não precisamos de coordenadas absolutas — usamos localPos diretamente
    // porque o GestureDetector está no mesmo nível do CustomPaint.
    final normX = localPos.dx / mapWidth;
    final normY = localPos.dy / mapHeight;

    for (final layout in _zoneLayouts) {
      if (normX >= layout.topLeft.x &&
          normX <= layout.bottomRight.x &&
          normY >= layout.topLeft.y &&
          normY <= layout.bottomRight.y) {
        setState(() {
          _selectedZoneId =
          _selectedZoneId == layout.zoneId ? null : layout.zoneId;
        });
        return;
      }
    }
    setState(() => _selectedZoneId = null);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CustomPainter
// ─────────────────────────────────────────────────────────────────────────────

class _ZoneMapPainter extends CustomPainter {
  final List<Zone> zones;
  final List<Beacon> beacons;
  final List<OnlineUser> onlineUsers;
  final String? selectedZoneId;
  final double pulseValue; // 0.0–1.0

  _ZoneMapPainter({
    required this.zones,
    required this.beacons,
    required this.onlineUsers,
    required this.selectedZoneId,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawCorridors(canvas, size);

    for (final layout in _zoneLayouts) {
      final zone = zones.firstWhere(
            (z) => z.id == layout.zoneId,
        orElse: () => Zone(
          id: layout.zoneId,
          name: layout.label,
          beaconUuid: '',
          color: AppTheme.border,
          icon: Icons.room_rounded,
        ),
      );
      _drawZone(canvas, size, layout, zone);
    }

    // Beacons ESP32
    for (final layout in _zoneLayouts) {
      final bpNorm = _beaconPositions[layout.zoneId];
      if (bpNorm == null) continue;
      final zone = zones.firstWhere(
            (z) => z.id == layout.zoneId,
        orElse: () => Zone(
          id: layout.zoneId,
          name: layout.label,
          beaconUuid: '',
          color: AppTheme.border,
          icon: Icons.room_rounded,
        ),
      );
      final rect = layout.toRect(size);
      final bx = rect.left + bpNorm.x * rect.width;
      final by = rect.top + bpNorm.y * rect.height;
      _drawBeacon(canvas, Offset(bx, by), zone.esp32Online, pulseValue);
    }

    // Utilizadores
    _drawUsers(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    // Fundo geral (corredor / paredes)
    final bgPaint = Paint()..color = const Color(0xFFEEF0F4);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Grid subtil
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E5EB)
      ..strokeWidth = 0.5;
    const step = 20.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawCorridors(Canvas canvas, Size size) {
    // Área do corredor (espaço entre zonas) — pintamos de branco acinzentado
    // para dar sensação de planta arquitetónica
    final corridorPaint = Paint()..color = const Color(0xFFF5F6F8);

    // Corredor vertical central (entre zone_c e as outras)
    final vCorridor = Rect.fromLTRB(
      _zoneLayouts[2].bottomRight.x * size.width,
      _zoneLayouts[0].topLeft.y * size.height,
      _zoneLayouts[0].topLeft.x * size.width,
      size.height * 0.96,
    );
    canvas.drawRect(vCorridor, corridorPaint);

    // Corredor horizontal (entre zone_a e zone_b)
    final hCorridor = Rect.fromLTRB(
      _zoneLayouts[0].topLeft.x * size.width,
      _zoneLayouts[0].bottomRight.y * size.height,
      _zoneLayouts[0].bottomRight.x * size.width,
      _zoneLayouts[1].topLeft.y * size.height,
    );
    canvas.drawRect(hCorridor, corridorPaint);
  }

  void _drawZone(
      Canvas canvas, Size size, _ZoneLayout layout, Zone zone) {
    final rect = layout.toRect(size);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    final isSelected = selectedZoneId == layout.zoneId;
    final isOccupied = zone.status == ZoneStatus.occupied;

    // ── Preenchimento ───────────────────────────────────────────────
    final Color fillColor = isOccupied
        ? zone.color.withOpacity(isSelected ? 0.18 : 0.10)
        : Colors.white.withOpacity(isSelected ? 0.95 : 0.85);

    canvas.drawRRect(rr, Paint()..color = fillColor);

    // ── Sombra / glow para selecionada ──────────────────────────────
    if (isSelected) {
      canvas.drawRRect(
        rr,
        Paint()
          ..color = zone.color.withOpacity(0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8),
      );
    }

    // ── Borda ───────────────────────────────────────────────────────
    final borderColor = isSelected
        ? zone.color
        : isOccupied
        ? zone.color.withOpacity(0.35)
        : AppTheme.border;
    canvas.drawRRect(
      rr,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.0 : 1.0,
    );

    // ── Pontos de canto (parede) ────────────────────────────────────
    _drawCornerDots(canvas, rect);

    // ── Label da zona ───────────────────────────────────────────────
    final labelSpan = TextSpan(
      text: zone.name,
      style: TextStyle(
        color: isOccupied ? zone.color : AppTheme.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
    final labelPainter = TextPainter(
      text: labelSpan,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: rect.width - 8);

    labelPainter.paint(
      canvas,
      Offset(
        rect.left + 10,
        rect.top + 8,
      ),
    );

    // ── Badge de ocupação ───────────────────────────────────────────
    if (isOccupied) {
      _drawOccupancyBadge(canvas, rect, zone);
    }

    // ── Ícone de luz ativo ──────────────────────────────────────────
    if (zone.lightOn) {
      _drawLightIcon(canvas, rect);
    }

    // ── Sensores (temp / hum) ───────────────────────────────────────
    _drawSensorReadings(canvas, rect, zone);
  }

  void _drawCornerDots(Canvas canvas, Rect rect) {
    final dotPaint = Paint()..color = const Color(0xFFCDD1D9);
    const r = 3.0;
    for (final corner in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      canvas.drawCircle(corner, r, dotPaint);
    }
  }

  void _drawOccupancyBadge(Canvas canvas, Rect rect, Zone zone) {
    final count = zone.occupantCount;
    final label = '$count';

    final bgPaint = Paint()..color = zone.color;
    const badgeR = 11.0;
    final badgeCenter = Offset(rect.right - 14, rect.top + 14);
    canvas.drawCircle(badgeCenter, badgeR, bgPaint);

    final sp = TextSpan(
      text: label,
      style: const TextStyle(
          color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
    );
    final tp = TextPainter(text: sp, textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(
        canvas,
        Offset(
          badgeCenter.dx - tp.width / 2,
          badgeCenter.dy - tp.height / 2,
        ));
  }

  void _drawLightIcon(Canvas canvas, Rect rect) {
    final iconPaint = Paint()
      ..color = AppTheme.warning.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    // Lâmpada simples — círculo + rectângulo base
    const r = 5.0;
    final center = Offset(rect.left + 14, rect.bottom - 12);
    canvas.drawCircle(center, r, iconPaint);
    // Raios
    final rayPaint = Paint()
      ..color = AppTheme.warning.withOpacity(0.45)
      ..strokeWidth = 1.2;
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * math.pi;
      canvas.drawLine(
        center + Offset(math.cos(angle) * (r + 1), math.sin(angle) * (r + 1)),
        center + Offset(math.cos(angle) * (r + 4), math.sin(angle) * (r + 4)),
        rayPaint,
      );
    }
  }

  void _drawSensorReadings(Canvas canvas, Rect rect, Zone zone) {
    final items = <String>[];
    if (zone.temperature != null) {
      items.add('${zone.temperature!.toStringAsFixed(0)}°C');
    }
    if (zone.humidity != null) {
      items.add('${zone.humidity!.toStringAsFixed(0)}%');
    }
    if (items.isEmpty) return;

    final text = items.join('  ');
    final sp = TextSpan(
      text: text,
      style: TextStyle(
        color: AppTheme.textMuted.withOpacity(0.85),
        fontSize: 9,
        fontWeight: FontWeight.w600,
      ),
    );
    final tp = TextPainter(text: sp, textDirection: TextDirection.ltr)
      ..layout(maxWidth: rect.width - 16);
    tp.paint(
      canvas,
      Offset(rect.left + 10, rect.bottom - tp.height - 8),
    );
  }

  void _drawBeacon(
      Canvas canvas, Offset center, bool online, double pulse) {
    // Onda de pulse animada (só quando online)
    if (online) {
      final wave1 = (pulse * 2.0).clamp(0.0, 1.0);
      final wave2 = ((pulse - 0.3) * 2.0).clamp(0.0, 1.0);
      for (final w in [wave1, wave2]) {
        if (w > 0) {
          canvas.drawCircle(
            center,
            8 + w * 14,
            Paint()
              ..color = AppTheme.success.withOpacity(0.18 * (1 - w))
              ..style = PaintingStyle.fill,
          );
        }
      }
    }

    // Corpo do beacon
    final bodyColor = online ? AppTheme.success : AppTheme.error;
    canvas.drawCircle(
      center, 8,
      Paint()..color = bodyColor.withOpacity(0.15),
    );
    canvas.drawCircle(
      center, 8,
      Paint()
        ..color = bodyColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Ícone interno — chip symbol
    final innerPaint = Paint()
      ..color = bodyColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final s = 3.5;
    canvas.drawRect(
      Rect.fromCenter(center: center, width: s * 2, height: s * 2),
      innerPaint,
    );
    // pinouts
    for (final dx in [-s, 0.0, s]) {
      canvas.drawLine(
        Offset(center.dx + dx, center.dy - s),
        Offset(center.dx + dx, center.dy - s - 2.5),
        innerPaint,
      );
      canvas.drawLine(
        Offset(center.dx + dx, center.dy + s),
        Offset(center.dx + dx, center.dy + s + 2.5),
        innerPaint,
      );
    }

    // Label "ESP32"
    final sp = TextSpan(
      text: 'ESP32',
      style: TextStyle(
        color: bodyColor,
        fontSize: 7,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
    );
    final tp = TextPainter(text: sp, textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy + 10));
  }

  void _drawUsers(Canvas canvas, Size size) {
    // Agrupa utilizadores por zona
    final Map<String, List<OnlineUser>> byZone = {};
    for (final user in onlineUsers) {
      if (user.currentZoneId != null) {
        byZone.putIfAbsent(user.currentZoneId!, () => []).add(user);
      }
    }

    for (final layout in _zoneLayouts) {
      final users = byZone[layout.zoneId] ?? [];
      if (users.isEmpty) continue;

      final rect = layout.toRect(size);
      _placeUsers(canvas, rect, users, layout.zoneId);
    }
  }

  void _placeUsers(
      Canvas canvas, Rect rect, List<OnlineUser> users, String zoneId) {
    // Posições relativas dentro da zona, distribuídas no espaço central
    const positions = [
      Offset(0.35, 0.55),
      Offset(0.55, 0.55),
      Offset(0.45, 0.35),
      Offset(0.65, 0.35),
      Offset(0.30, 0.75),
    ];

    for (int i = 0; i < users.length && i < positions.length; i++) {
      final p = positions[i];
      final center = Offset(
        rect.left + p.dx * rect.width,
        rect.top + p.dy * rect.height,
      );
      _drawUserAvatar(canvas, center, users[i]);
    }

    // Se há mais de 5, mostra "+N"
    if (users.length > 5) {
      final extra = users.length - 5;
      final p = positions[4];
      final center = Offset(
        rect.left + p.dx * rect.width + 22,
        rect.top + p.dy * rect.height,
      );
      _drawExtraCount(canvas, center, extra);
    }
  }

  void _drawUserAvatar(Canvas canvas, Offset center, OnlineUser user) {
    final color = user.isAdmin ? AppTheme.accent : AppTheme.success;
    final initial = user.displayName.isNotEmpty
        ? user.displayName[0].toUpperCase()
        : '?';

    // Sombra
    canvas.drawCircle(
      center + const Offset(0, 1.5),
      11,
      Paint()..color = Colors.black.withOpacity(0.12),
    );

    // Fundo
    canvas.drawCircle(center, 11, Paint()..color = Colors.white);
    canvas.drawCircle(center, 11,
        Paint()
          ..color = color.withOpacity(0.2)
          ..style = PaintingStyle.fill);
    canvas.drawCircle(
      center, 11,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // Inicial
    final sp = TextSpan(
      text: initial,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    );
    final tp = TextPainter(text: sp, textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );

    // Coroa para admin
    if (user.isAdmin) {
      _drawAdminCrown(canvas, center, color);
    }
  }

  void _drawAdminCrown(Canvas canvas, Offset center, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    final top = center.dy - 13.5;
    final left = center.dx - 5.0;
    path.moveTo(left, top + 3);
    path.lineTo(left + 2.5, top);
    path.lineTo(left + 5, top + 2.5);
    path.lineTo(left + 7.5, top);
    path.lineTo(left + 10, top + 3);
    path.lineTo(left + 10, top + 5);
    path.lineTo(left, top + 5);
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawExtraCount(Canvas canvas, Offset center, int extra) {
    canvas.drawCircle(center, 10, Paint()..color = AppTheme.textMuted.withOpacity(0.2));
    canvas.drawCircle(
      center, 10,
      Paint()
        ..color = AppTheme.textMuted
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    final sp = TextSpan(
      text: '+$extra',
      style: const TextStyle(
        color: AppTheme.textMuted,
        fontSize: 8,
        fontWeight: FontWeight.w800,
      ),
    );
    final tp = TextPainter(text: sp, textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(_ZoneMapPainter old) =>
      old.pulseValue != pulseValue ||
          old.selectedZoneId != selectedZoneId ||
          old.zones != zones ||
          old.onlineUsers != onlineUsers ||
          old.beacons != beacons;
}

// ─────────────────────────────────────────────────────────────────────────────
// Painel de detalhe da zona selecionada
// ─────────────────────────────────────────────────────────────────────────────

class _ZoneDetailPanel extends StatelessWidget {
  final String zoneId;
  final VoidCallback onClose;

  const _ZoneDetailPanel({required this.zoneId, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final ss = context.watch<SmartSpaceProvider>();
    final db = context.read<DatabaseService>();
    final zone = ss.zoneById(zoneId);
    if (zone == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: zone.color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: zone.color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: zone.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(zone.icon, color: zone.color, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  zone.name,
                  style: TextStyle(
                    color: zone.color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(zone: zone),
                const Spacer(),
                GestureDetector(
                  onTap: onClose,
                  child: Icon(Icons.close_rounded,
                      color: AppTheme.textMuted, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Métricas
            Row(
              children: [
                _DetailMetric(
                  icon: Icons.people_rounded,
                  label: 'Ocupantes',
                  value: '${zone.occupantCount}',
                  color: zone.color,
                ),
                const SizedBox(width: 12),
                if (zone.temperature != null)
                  _DetailMetric(
                    icon: Icons.thermostat_rounded,
                    label: 'Temp.',
                    value: '${zone.temperature!.toStringAsFixed(1)}°C',
                    color: AppTheme.warning,
                  ),
                if (zone.temperature != null) const SizedBox(width: 12),
                if (zone.humidity != null)
                  _DetailMetric(
                    icon: Icons.water_drop_rounded,
                    label: 'Hum.',
                    value: '${zone.humidity!.toStringAsFixed(0)}%',
                    color: AppTheme.accent,
                  ),
                if (zone.humidity != null) const SizedBox(width: 12),
                if (zone.luminosity != null)
                  _DetailMetric(
                    icon: Icons.wb_sunny_rounded,
                    label: 'LDR',
                    value: '${zone.luminosity!.toStringAsFixed(0)}%',
                    color: AppTheme.warning,
                  ),
              ],
            ),

            // Utilizadores presentes
            if (zone.presentUsers.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              StreamBuilder<List<OnlineUser>>(
                stream: db.onlineUsersStream(),
                builder: (context, snapshot) {
                  final all = snapshot.data ?? [];
                  final present = all
                      .where((u) => zone.presentUsers.contains(u.uid))
                      .toList();
                  if (present.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Presentes na zona',
                        style: TextStyle(
                          color: zone.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: present
                            .map((u) => _UserChip(user: u, zoneColor: zone.color))
                            .toList(),
                      ),
                    ],
                  );
                },
              ),
            ],

            // Estado ESP32
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: zone.esp32Online
                        ? AppTheme.success
                        : AppTheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'ESP32 ${zone.esp32Online ? "online" : "offline"}',
                  style: TextStyle(
                    color: zone.esp32Online
                        ? AppTheme.success
                        : AppTheme.error,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  zone.lightOn
                      ? Icons.lightbulb_rounded
                      : Icons.lightbulb_outline_rounded,
                  color: zone.lightOn ? AppTheme.warning : AppTheme.textMuted,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  zone.lightOn
                      ? 'Luz ${(zone.lightIntensity * 100).toInt()}%'
                      : 'Luz desligada',
                  style: TextStyle(
                    color:
                    zone.lightOn ? AppTheme.warning : AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (zone.lightMode == LightMode.auto) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'AUTO',
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          color: color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: color.withOpacity(0.6), width: 1),
        ),
      ),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(
              color: AppTheme.textMuted, fontSize: 10)),
    ],
  );
}

class _StatusPill extends StatelessWidget {
  final Zone zone;
  const _StatusPill({required this.zone});

  @override
  Widget build(BuildContext context) {
    final occupied = zone.status == ZoneStatus.occupied;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: occupied
            ? AppTheme.success.withOpacity(0.1)
            : AppTheme.textMuted.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        occupied ? 'Ocupada' : 'Livre',
        style: TextStyle(
          color: occupied ? AppTheme.success : AppTheme.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _DetailMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textMuted, fontSize: 9)),
      ],
    ),
  );
}

class _UserChip extends StatelessWidget {
  final OnlineUser user;
  final Color zoneColor;
  const _UserChip({required this.user, required this.zoneColor});

  @override
  Widget build(BuildContext context) {
    final color = user.isAdmin ? AppTheme.accent : zoneColor;
    final name = user.displayName.isNotEmpty ? user.displayName : user.uid.substring(0, 6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18, height: 18,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name[0].toUpperCase(),
                style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            name,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
          if (user.isAdmin) ...[
            const SizedBox(width: 4),
            Text('⚡',
                style: TextStyle(fontSize: 9, color: AppTheme.accent)),
          ],
        ],
      ),
    );
  }
}