import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/theme.dart';
import 'app/router/app_router.dart';
import 'features/auth/services/line_auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LineAuthService.initialize();
  runApp(const ProviderScope(child: PingPayApp()));
}

class PingPayApp extends ConsumerWidget {
  const PingPayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
