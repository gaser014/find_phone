import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/di/di.dart';
import 'core/utils/memory_optimizer.dart';
import 'presentation/screens/dashboard/main_dashboard_screen.dart';
import 'presentation/screens/setup/password_setup_screen.dart';
import 'presentation/screens/security_logs_screen.dart';
import 'presentation/screens/location_history_screen.dart';
import 'presentation/screens/test_mode/test_mode_screen.dart';
import 'presentation/screens/kiosk_mode/kiosk_on_lock_settings_screen.dart';
import 'services/authentication/i_authentication_service.dart';
import 'services/protection/i_protection_service.dart';
import 'services/test_mode/i_test_mode_service.dart';

/// Main entry point for the Anti-Theft Protection app.
///
/// Requirements:
/// - All: Wire all services together with dependency injection
/// - 9.1: Display main dashboard with protection status
/// - 9.5: Provide clear Arabic labels and RTL support
void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Setup dependency injection
  await setupServiceLocator();

  // Initialize services
  await initializeServices();

  // Configure memory optimization
  final memoryOptimizer = MemoryOptimizer.instance;
  memoryOptimizer.setImageCacheSize(maxImages: 50, maxSizeBytes: 10 * 1024 * 1024);

  // Run the app
  runApp(const AntiTheftApp());
}

/// Main application widget.
class AntiTheftApp extends StatefulWidget {
  const AntiTheftApp({super.key});

  @override
  State<AntiTheftApp> createState() => _AntiTheftAppState();
}

class _AntiTheftAppState extends State<AntiTheftApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Dispose services when app is terminated
    disposeServices();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Handle app lifecycle changes for protection features
    if (state == AppLifecycleState.paused) {
      // App is going to background
      _onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      // App is coming to foreground
      _onAppResumed();
    }
  }

  void _onAppPaused() {
    // Trim memory when going to background
    MemoryOptimizer.instance.trimMemory();
  }

  void _onAppResumed() {
    // Refresh protection status when app resumes
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    // Perform memory cleanup when system reports memory pressure
    MemoryOptimizer.instance.performCleanup();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'حماية من السرقة',
      debugShowCheckedModeBanner: false,
      // RTL support for Arabic
      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const AppInitializer(),
      routes: {
        '/dashboard': (context) => MainDashboardScreen(
              protectionService: sl<IProtectionService>(),
              authenticationService: sl<IAuthenticationService>(),
            ),
        '/security-logs': (context) => const SecurityLogsScreen(),
        '/location-history': (context) => const LocationHistoryScreen(),
        '/test-mode': (context) => TestModeScreen(
              testModeService: sl<ITestModeService>(),
            ),
        '/settings': (context) => const SettingsPlaceholder(),
        '/kiosk-on-lock-settings': (context) => const KioskOnLockSettingsScreen(),
      },
    );
  }
}

/// Widget that handles initial app state and routing.
///
/// Checks if password is set and routes to appropriate screen.
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true;
  bool _isPasswordSet = false;

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    try {
      final authService = sl<IAuthenticationService>();
      final isPasswordSet = await authService.isPasswordSet();

      setState(() {
        _isPasswordSet = isPasswordSet;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('جاري التحميل...'),
            ],
          ),
        ),
      );
    }

    if (!_isPasswordSet) {
      // First run - show password setup
      return PasswordSetupScreen(
        authenticationService: sl<IAuthenticationService>(),
        onPasswordSet: () {
          setState(() {
            _isPasswordSet = true;
          });
        },
      );
    }

    // Password is set - show dashboard
    return MainDashboardScreen(
      protectionService: sl<IProtectionService>(),
      authenticationService: sl<IAuthenticationService>(),
    );
  }
}

/// Placeholder for settings screen.
class SettingsPlaceholder extends StatelessWidget {
  const SettingsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الإعدادات'),
        ),
        body: const Center(
          child: Text('صفحة الإعدادات قيد التطوير'),
        ),
      ),
    );
  }
}
