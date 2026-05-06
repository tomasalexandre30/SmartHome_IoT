import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/beacon_service.dart';
import '../../services/smartspace_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';
import 'admin_dashboard_screen.dart';
import 'admin_zones_screen.dart';
import 'admin_history_screen.dart';
import 'admin_settings_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  int _lastSeenLogCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ble = context.read<BeaconService>();
      final ss  = context.read<SmartSpaceProvider>();
      ble.addListener(() => ss.updateZoneFromBeacon(ble.currentZoneId));
      ble.startScanning();

      // Inicializa o contador com os logs atuais
      _lastSeenLogCount = _alertCount(ss.logs);
    });
  }

  static final _screens = [
    const AdminDashboardScreen(),
    const AdminZonesScreen(),
    AdminHistoryScreen(),
    const AdminSettingsScreen(),
  ];

  int _alertCount(List<LogEvent> logs) => logs
      .where((e) =>
  e.type == LogEventType.alert ||
      e.type == LogEventType.connectionLost)
      .length;

  @override
  Widget build(BuildContext context) {
    final ss = context.watch<SmartSpaceProvider>();
    final totalAlerts = _alertCount(ss.logs);

    // Quantos alertas novos desde a última vez que abriu o Histórico
    final unseenAlerts = (totalAlerts - _lastSeenLogCount).clamp(0, 99);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) {
            setState(() => _index = i);
            // Quando abre o Histórico, marca todos como vistos
            if (i == 2) {
              setState(() => _lastSeenLogCount = totalAlerts);
            }
          },
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.meeting_room_rounded),
              label: 'Zonas',
            ),
            BottomNavigationBarItem(
              icon: _BadgeIcon(
                icon: Icons.history_rounded,
                count: unseenAlerts,
                active: _index == 2,
              ),
              label: 'Histórico',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'Definições',
            ),
          ],
          backgroundColor: AppTheme.surface,
          selectedItemColor: AppTheme.accent,
          unselectedItemColor: AppTheme.textDisabled,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ── Badge Icon ─────────────────────────────────────────────────────────────────

class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool active;

  const _BadgeIcon({
    required this.icon,
    required this.count,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: active ? AppTheme.accent : AppTheme.textDisabled),
        if (count > 0)
          Positioned(
            top: -4,
            right: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.error,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.surface, width: 1.5),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}