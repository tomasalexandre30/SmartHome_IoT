import 'dart:async';
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
import 'services/database_service.dart';
import 'services/notification_service.dart';           // ← NOVO
import 'widgets/in_app_notification_overlay.dart';     // ← NOVO
import 'screens/login_screen.dart';
import 'screens/user/user_shell.dart';
import 'screens/admin/admin_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  await Firebase.initializeApp();
  await _requestPermissions();

  // ── NOVO: carrega a preferência de notificações antes do runApp ───────────
  await NotificationService.instance.loadPreferences();

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
        ChangeNotifierProvider(create: (_) => DatabaseService()),
        ChangeNotifierProvider(create: (_) => SmartSpaceProvider()),
        ChangeNotifierProvider(create: (_) {
          final ble = BeaconService();
          ble.registerBeacons(DefaultData.beacons());
          return ble;
        }),
        // ── NOVO: expõe o NotificationService como provider ──────────────
        ChangeNotifierProvider<NotificationService>.value(
          value: NotificationService.instance,
        ),
      ],
      child: MaterialApp(
        title: 'SmartSpace',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        // ── NOVO: envolve toda a app com o overlay de notificações ───────
        builder: (context, child) => InAppNotificationOverlay(
          child: child ?? const SizedBox.shrink(),
        ),
        home: const _AuthGate(),
      ),
    );
  }
}

// ── Auth Gate ──────────────────────────────────────────────────────────────────

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _showMessage = false;
  bool _wasDeleted = false;
  bool _wasLoggedIn = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();

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

        final isLoggedIn = snapshot.hasData;

        if (_wasLoggedIn && !isLoggedIn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _wasDeleted = auth.accountDeleted;
                _showMessage = true;
              });
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) setState(() => _showMessage = false);
              });
            }
          });
        }
        _wasLoggedIn = isLoggedIn;

        if (isLoggedIn) return const _RoleGate();

        return Stack(
          children: [
            const LoginScreen(),
            if (_showMessage)
              Positioned(
                top: 0, left: 0, right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: AnimatedOpacity(
                      opacity: _showMessage ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _wasDeleted
                              ? AppTheme.error.withOpacity(0.95)
                              : AppTheme.success.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: (_wasDeleted
                                  ? AppTheme.error
                                  : AppTheme.success)
                                  .withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _wasDeleted
                                  ? Icons.delete_forever_rounded
                                  : Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _wasDeleted
                                    ? 'Conta apagada permanentemente'
                                    : 'Sessão terminada com sucesso',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Role Gate ──────────────────────────────────────────────────────────────────

class _RoleGate extends StatefulWidget {
  const _RoleGate();

  @override
  State<_RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<_RoleGate> with WidgetsBindingObserver {
  bool _loading = true;
  String? _uid;

  Timer? _esp32HeartbeatTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    _esp32HeartbeatTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startEsp32Timer() {
    _esp32HeartbeatTimer?.cancel();
    _esp32HeartbeatTimer = Timer.periodic(
      const Duration(seconds: 10),
          (_) {
        if (!mounted) return;
        context.read<SmartSpaceProvider>().reevaluateEsp32Status();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final db = context.read<DatabaseService>();
    final ss = context.read<SmartSpaceProvider>();
    final auth = context.read<AuthService>();
    if (_uid == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        db.initialize(_uid!).then((_) {
          ss.attachDatabase(db, _uid!, auth.appUser);
        });
        _startEsp32Timer();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _esp32HeartbeatTimer?.cancel();
        ss.clearZoneOnLogout().then((_) {
          db.updateUserPresence(_uid!, false);
        });
        break;
    }
  }

  Future<void> _load() async {
    final auth = context.read<AuthService>();
    await auth.loadUserProfile();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _uid = uid;
      final db = context.read<DatabaseService>();
      final ss = context.read<SmartSpaceProvider>();
      await db.initialize(uid);
      ss.attachDatabase(db, uid, auth.appUser);

      // ── NOVO: regista o nome do próprio utilizador no cache ──────────────
      if (auth.appUser?.displayName != null) {
        ss.registerUserName(uid, auth.appUser!.displayName);
      }
    }

    if (mounted) {
      setState(() => _loading = false);
      _startEsp32Timer();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }
    final auth = context.read<AuthService>();
    return auth.isAdmin ? const AdminShell() : const UserShell();
  }
}