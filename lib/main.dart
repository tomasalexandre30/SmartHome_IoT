import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme/app_theme.dart';
import 'models/models.dart';
import 'services/beacon_service.dart';
import 'services/smartspace_provider.dart';
import 'services/auth_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/control_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  await Firebase.initializeApp();
  await _requestPermissions();
  runApp(const SmartSpaceApp());
}

Future<void> _requestPermissions() async {
  await [
    Permission.bluetooth,
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.locationWhenInUse,
  ].request();
}

class SmartSpaceApp extends StatelessWidget {
  const SmartSpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => SmartSpaceProvider()),
        ChangeNotifierProvider(create: (_) {
          final ble = BeaconService();
          ble.registerBeacons(DefaultData.beacons());
          return ble;
        }),
      ],
      child: MaterialApp(
        title: 'SmartSpace',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const _AuthGate(),
      ),
    );
  }
}

// Decide automaticamente se mostra Login ou App
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            ),
          );
        }

        if (snapshot.hasData) {
          return const _Root();
        }

        return const LoginScreen();
      },
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
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
    DashboardScreen(),
    ControlScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  static const _navItems = [
    BottomNavigationBarItem(icon: Icon(Icons.home_rounded),     label: 'Início'),
    BottomNavigationBarItem(icon: Icon(Icons.tune_rounded),     label: 'Controlo'),
    BottomNavigationBarItem(icon: Icon(Icons.history_rounded),  label: 'Histórico'),
    BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Definições'),
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
          unselectedItemColor: AppTheme.textDisabled,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}