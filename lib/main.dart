import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'models/models.dart';
import 'services/beacon_service.dart';
import 'services/smartspace_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/control_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const SmartSpaceApp());
}

class SmartSpaceApp extends StatelessWidget {
  const SmartSpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final ss = SmartSpaceProvider();
          return ss;
        }),
        ChangeNotifierProvider(create: (_) {
          final ble = BeaconService();
          // Register the 3 default beacons
          ble.registerBeacons(DefaultData.beacons());
          return ble;
        }),
      ],
      child: MaterialApp(
        title: 'SmartSpace',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const _Root(),
      ),
    );
  }
}

// ── Root with bottom nav ───────────────────────────────────────────────────────

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  int _index = 0;

  // Listen to BLE zone changes and update SmartSpaceProvider
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ble = context.read<BeaconService>();
      final ss  = context.read<SmartSpaceProvider>();
      ble.addListener(() => ss.updateZoneFromBeacon(ble.currentZoneId));
    });
  }

  static const _screens = [
    DashboardScreen(),
    ControlScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  static const _navItems = [
    BottomNavigationBarItem(icon: Icon(Icons.home_rounded),        label: 'Início'),
    BottomNavigationBarItem(icon: Icon(Icons.tune_rounded),        label: 'Controlo'),
    BottomNavigationBarItem(icon: Icon(Icons.history_rounded),     label: 'Histórico'),
    BottomNavigationBarItem(icon: Icon(Icons.settings_rounded),    label: 'Definições'),
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
          items: _navItems,
          backgroundColor: AppTheme.surface,
          selectedItemColor: AppTheme.accent,
          unselectedItemColor: AppTheme.textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
        ),
      ),
    );
  }
}
