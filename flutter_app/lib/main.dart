import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Russian locale for DateFormat
  await initializeDateFormatting('ru', null);

  bool supabaseOk = false;
  try {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
      // On web use implicit flow to avoid flutter_secure_storage deadlock
      authOptions: FlutterAuthClientOptions(
        authFlowType: kIsWeb ? AuthFlowType.implicit : AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('Supabase init timed out'),
    );
    supabaseOk = true;
  } catch (e) {
    debugPrint('[PlayPass] Supabase init error: $e');
  }

  if (supabaseOk && !kIsWeb) {
    await NotificationService().init();
  }

  if (!supabaseOk) {
    runApp(const _ErrorApp());
    return;
  }

  runApp(const ProviderScope(child: PlayPassApp()));
}

/// Показывается если Supabase недоступен
class _ErrorApp extends StatelessWidget {
  const _ErrorApp();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, color: AppTheme.primary, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Нет подключения',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Не удалось подключиться к серверу.\nПроверьте интернет и перезагрузите страницу.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => main(),
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PlayPassApp extends ConsumerWidget {
  const PlayPassApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'PlayPass',
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru'),
      scrollBehavior: const _AppScrollBehavior(),
    );
  }
}

/// Enable mouse drag + trackpad scrolling on Flutter web
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}
