import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/services_screen.dart';
import 'screens/tracking_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/register_screen.dart';
import 'screens/patient_login_screen.dart';
import 'widgets/connectivity_gate.dart';
import 'services/api_client.dart';
import 'services/app_messenger.dart';
import 'services/notification_service.dart';
import 'services/registration_service.dart';
import 'services/session_service.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Firebase — gracefully skipped if google-services.json is a
  // placeholder (NotificationService handles the same fallback internally).
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('[main] Firebase.initializeApp skipped: $e');
  }

  await Permission.notification.request();
  await ApiClient.instance.restoreSession();
  await NotificationService.instance.init();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const ResQmoveApp());
}

class ResQmoveApp extends StatelessWidget {
  const ResQmoveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ResQmove',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      scaffoldMessengerKey: AppMessenger.scaffoldMessengerKey,
      builder: (context, child) =>
          ConnectivityGate(child: child ?? const SizedBox.shrink()),
      home: const _AppBootstrap(),
    );
  }
}

/// Shows quick registration on first launch, then the main tab shell.
class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  bool? _registered;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ok = await RegistrationService.instance.isRegistered();
    if (ok) {
      unawaited(SessionService.instance.syncPatientFromRegistration());
    }
    if (mounted) setState(() => _registered = ok);
  }

  @override
  Widget build(BuildContext context) {
    if (_registered == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_registered == false) {
      return RegisterScreen(
        onRegistered: () => setState(() => _registered = true),
        onRequestSignIn: () async {
          final ok = await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              builder: (_) => const PatientLoginScreen(),
            ),
          );
          if (ok == true && mounted) setState(() => _registered = true);
        },
      );
    }
    return const MainShell();
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    ServicesScreen(),
    TrackingScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  ENHANCED BOTTOM NAV
// ─────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 36,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              index: 0,
              current: currentIndex,
              onTap: onTap,
            ),
            _NavItem(
              icon: Icons.medical_services_rounded,
              label: 'Services',
              index: 1,
              current: currentIndex,
              onTap: onTap,
            ),
            _NavItem(
              icon: Icons.location_on_rounded,
              label: 'Track',
              index: 2,
              current: currentIndex,
              onTap: onTap,
            ),
            _NavItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              index: 3,
              current: currentIndex,
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: active ? 22 : 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [Color(0xFFFF1A35), Color(0xFFD0021B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: active ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: AppTheme.crimson.withOpacity(0.42),
                      blurRadius: 18,
                      offset: const Offset(0, 6))
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                key: ValueKey('$label-$active'),
                color: active ? Colors.white : AppTheme.textLight,
                size: 22,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
