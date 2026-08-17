import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/config/supabase_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inicializar datos de localización para DateFormat con locale 'es'
  await initializeDateFormatting();
  Intl.defaultLocale = 'es_bo';

  // 2. Variables de entorno
  await dotenv.load(fileName: '.env');

  // 3. Una sola inicialización de Supabase para toda la app
  await initSupabase();

  runApp(
    // 4. ProviderScope envuelve todo → un solo árbol de providers
    const ProviderScope(
      child: AcademiaApp(),
    ),
  );
}

class AcademiaApp extends ConsumerWidget {
  const AcademiaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Academia Events',
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
