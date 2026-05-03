import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/beacon_service.dart';
import '../../services/smartspace_provider.dart';
import '../../theme/app_theme.dart';
import 'admin_dashboard_screen.dart';
import 'admin_zones_screen.dart';
import 'admin_history_screen.dart';
import '../settings_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ble = context.read<BeaconService>();
      final ss  = context.read<SmartSpaceProvider>();
      ble.addListener(() => ss.updateZoneFromBeacon(ble.currentZoneId));
      ble.startScanning();
    });
  }

  static const _screens = [
    AdminDashboardScreen(),
    AdminZonesScreen(),
    AdminHistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.meeting_room_rounded),
              label: 'Zonas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              label: 'Histórico',
            ),
            BottomNavigationBarItem(
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