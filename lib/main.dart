import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/supabase_config.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/auth/login_screen.dart';
import 'presentation/providers/app_providers.dart';
import 'presentation/shell/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize native push notification service & Android channels
  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Notification service initialization warning: $e');
  }

  // Initialize Supabase configuration with safe fallback for offline/development
  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint('Supabase initialization warning: $e');
  }

  runApp(
    const ProviderScope(
      child: BenchmarkMmsApp(),
    ),
  );
}

class BenchmarkMmsApp extends StatelessWidget {
  const BenchmarkMmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('>>> RENDERING BENCHMARK MMS APP');
    return MaterialApp(
      title: 'demo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('>>> RENDERING AUTH GATE');
    final authState = ref.watch(authNotifierProvider);
    debugPrint('>>> AUTH STATE: ${authState.status}');

    switch (authState.status) {
      case AuthStatus.authenticated:
        return const HomeShell();
      case AuthStatus.loading:
      case AuthStatus.initial:
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}
