import 'dart:async';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

/// Envolve a app inteira e mostra banners deslizantes no topo.
///
/// Uso em main.dart:
///   child: InAppNotificationOverlay(child: _AuthGate())
class InAppNotificationOverlay extends StatefulWidget {
  final Widget child;
  const InAppNotificationOverlay({super.key, required this.child});

  @override
  State<InAppNotificationOverlay> createState() =>
      _InAppNotificationOverlayState();
}

class _InAppNotificationOverlayState extends State<InAppNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  StreamSubscription<AppNotification>? _sub;
  AppNotification? _current;
  Timer? _dismissTimer;

  // Fila para notificações que chegam enquanto outra está visível
  final List<AppNotification> _queue = [];
  bool _showing = false;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: const Interval(0.0, 0.5)),
    );

    _sub = NotificationService.instance.stream.listen(_onNotification);
  }

  void _onNotification(AppNotification n) {
    if (_showing) {
      _queue.add(n);
      return;
    }
    _showNotification(n);
  }

  void _showNotification(AppNotification n) {
    if (!mounted) return;
    setState(() {
      _current = n;
      _showing = true;
    });
    _animCtrl.forward(from: 0);
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(seconds: 4), _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _animCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _showing = false;
        _current = null;
      });
      // Próxima na fila
      if (_queue.isNotEmpty) {
        final next = _queue.removeAt(0);
        Future.delayed(const Duration(milliseconds: 120), () {
          if (mounted) _showNotification(next);
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _dismissTimer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_current != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: GestureDetector(
                    onVerticalDragEnd: (d) {
                      if (d.primaryVelocity != null && d.primaryVelocity! < 0) {
                        _dismiss();
                      }
                    },
                    onTap: _dismiss,
                    child: _NotificationBanner(notification: _current!),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Banner visual ──────────────────────────────────────────────────────────────

class _NotificationBanner extends StatelessWidget {
  final AppNotification notification;
  const _NotificationBanner({required this.notification});

  @override
  Widget build(BuildContext context) {
    final config = _bannerConfig(notification.type);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: config.borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: config.accentColor.withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Ícone
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: config.accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(config.icon, color: config.accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          // Texto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  notification.title,
                  style: TextStyle(
                    color: config.accentColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notification.message,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Dismiss hint
          Icon(Icons.close_rounded, color: config.accentColor.withOpacity(0.5), size: 16),
        ],
      ),
    );
  }

  _BannerConfig _bannerConfig(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.zoneEntry:
        return _BannerConfig(
          icon: Icons.door_front_door_rounded,
          accentColor: AppTheme.success,
          bgColor: AppTheme.successLight,
          borderColor: AppTheme.successBorder,
        );
      case AppNotificationType.zoneExit:
        return _BannerConfig(
          icon: Icons.door_back_door_rounded,
          accentColor: AppTheme.textSecondary,
          bgColor: AppTheme.surfaceSubtle,
          borderColor: AppTheme.border,
        );
      case AppNotificationType.alert:
        return _BannerConfig(
          icon: Icons.warning_amber_rounded,
          accentColor: AppTheme.warning,
          bgColor: AppTheme.warningLight,
          borderColor: AppTheme.warningBorder,
        );
    }
  }
}

class _BannerConfig {
  final IconData icon;
  final Color accentColor, bgColor, borderColor;
  const _BannerConfig({
    required this.icon,
    required this.accentColor,
    required this.bgColor,
    required this.borderColor,
  });
}