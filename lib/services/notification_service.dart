import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modelo de uma notificação in-app
class AppNotification {
  final String id;
  final String title;
  final String message;
  final AppNotificationType type;
  final DateTime timestamp;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

enum AppNotificationType { zoneEntry, zoneExit, alert }

/// Serviço singleton que gere notificações in-app.
///
/// Uso:
///   NotificationService.instance.show(AppNotification(...))
///   NotificationService.instance.notificationsEnabled  → bool
///   NotificationService.instance.setEnabled(true/false)
class NotificationService extends ChangeNotifier {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  // Stream que o overlay escuta para mostrar banners
  final StreamController<AppNotification> _controller =
  StreamController<AppNotification>.broadcast();
  Stream<AppNotification> get stream => _controller.stream;

  bool _enabled = true;
  bool get notificationsEnabled => _enabled;

  static const _prefKey = 'notifications_enabled';

  /// Carrega a preferência guardada
  Future<void> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefKey) ?? true;
      notifyListeners();
    } catch (_) {}
  }

  /// Liga/desliga notificações e persiste a preferência
  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (_) {}
  }

  /// Dispara uma notificação (apenas se estiverem ativas)
  void show(AppNotification notification) {
    if (!_enabled) return;
    if (_controller.isClosed) return;
    _controller.add(notification);
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}