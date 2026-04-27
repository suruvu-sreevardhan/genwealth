// lib/main.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'screens/opening_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[Startup] FlutterError: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[Startup] Platform error: $error');
    debugPrintStack(stackTrace: stack);
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFFF8FAFC),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline,
                color: Color(0xFFDC2626),
                size: 42,
              ),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong while opening the app.',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                details.exceptionAsString(),
                style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
              ),
            ],
          ),
        ),
      ),
    );
  };

  await runZonedGuarded(() async {
    debugPrint('[Startup] main() entered');
    debugPrint('[Startup] Flutter binding initialized');

    try {
      debugPrint('[Startup] Loading .env');
      await dotenv.load(fileName: '.env').timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('[Startup] .env load timeout, using defaults');
        },
      );
      debugPrint('[Startup] .env loaded');
    } catch (e) {
      // .env missing or unreadable - app continues with fallback URL.
      debugPrint('Warning: could not load .env - $e');
    }

    debugPrint('[Startup] runApp()');
    runApp(const FinApp());
  }, (error, stack) {
    debugPrint('[Startup] Uncaught zone error: $error');
    debugPrintStack(stackTrace: stack);
  });
}

class FinApp extends StatelessWidget {
  const FinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..restoreSession(),
      child: MaterialApp(
        title: 'Smart Budget - AI Financial Tracker',
        theme: AppTheme.light,
        darkTheme: AppTheme.darkTheme,
        themeMode: kIsWeb ? ThemeMode.system : ThemeMode.light,
        home: const RootScreen(),
      ),
    );
  }
}

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    debugPrint(
        '[Startup] RootScreen build | isRestoring=${auth.isRestoring} isLoggedIn=${auth.isLoggedIn}');

    if (auth.isRestoring) {
      return const OpeningScreen();
    }

    return auth.isLoggedIn ? const HomeScreen() : const OpeningScreen();
  }
}
