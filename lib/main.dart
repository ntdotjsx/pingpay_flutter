import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/theme.dart';
import 'core/services/shorebird_service.dart';
import 'core/services/notification_service.dart';
import 'core/realtime/realtime_providers.dart';
import 'app/router/app_router.dart';
import 'features/auth/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('th_TH', null);
  await initializeDateFormatting('th', null);

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase.initializeApp skipped or failed: $e');
  }

  runApp(const ProviderScope(child: PingPayApp()));
}

class PingPayApp extends ConsumerStatefulWidget {
  const PingPayApp({super.key});

  @override
  ConsumerState<PingPayApp> createState() => _PingPayAppState();
}

class _PingPayAppState extends ConsumerState<PingPayApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Seamless background OTA patch check with Shorebird
    Future.microtask(() {
      ref.read(shorebirdServiceProvider).checkForUpdatesInBackground();
      ref.read(notificationServiceProvider).initialize();
      ref.read(realtimeControllerProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When user leaves the app, swipes to home, or locks screen
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      ref.read(authStateProvider.notifier).lockApp();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(realtimeControllerProvider).onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'PingPay',
      debugShowCheckedModeBanner: false,
      theme: LightTheme.theme,
      darkTheme: DarkTheme.theme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
