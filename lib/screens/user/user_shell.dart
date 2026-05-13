import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/beacon_service.dart';
import '../../services/smartspace_provider.dart';
import '../../theme/app_theme.dart';
import 'user_dashboard_screen.dart';
import 'user_control_screen.dart';
import 'user_preferences_screen.dart';
import 'user_settings_screen.dart';

class UserShell extends StatefulWidget {
  const UserShell({super.key});

  @override
  State<UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<UserShell> {
  int _index = 0;

  // ✅ Guardamos referência à função listener para poder removê-la
  VoidCallback? _bleListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ble = context.read<BeaconService>();
      final ss  = context.read<SmartSpaceProvider>();

      // ✅ Cria o listener uma única vez e guarda referência
      _bleListener = () => ss.updateZoneFromBeacon(ble.currentZoneId);
      ble.addListener(_bleListener!);
      ble.startScanning();
    });
  }

  @override
  void dispose() {
    // ✅ Remove o listener ao destruir o widget — evita leaks e listeners duplicados
    if (_bleListener != null) {
      final ble = context.read<BeaconService>();
      ble.removeListener(_bleListener!);
      _bleListener = null;
    }
    super.dispose();
  }

  static const _screens = [
    UserDashboardScreen(),
    UserControlScreen(),
    UserPreferencesScreen(),
    UserSettingsScreen(),
  ];

  static const _navItems = [
    BottomNavigationBarItem(
        icon: Icon(Icons.home_rounded), label: 'Início'),
    BottomNavigationBarItem(
        icon: Icon(Icons.tune_rounded), label: 'Controlo'),
    BottomNavigationBarItem(
        icon: Icon(Icons.star_rounded), label: 'Preferências'),
    BottomNavigationBarItem(
        icon: Icon(Icons.settings_rounded), label: 'Definições'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border:
          Border(top: BorderSide(color: AppTheme.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          items: _navItems,
          backgroundColor: AppTheme.surface,
          selectedItemColor: AppTheme.accent,
          unselectedItemColor: AppTheme.textDisabled,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle:
          const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
          const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}