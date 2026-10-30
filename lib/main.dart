import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Supabase
import 'package:supabase_flutter/supabase_flutter.dart';

// Core & Providers
import 'core/config/supabase_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_transition.dart';
import 'providers/theme_provider.dart';

// Servicios de Notificación
import 'data/repositories/fcm_token_repository.dart';
import 'data/services/notification_service.dart';

// Provider global para el servicio de notificaciones
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final supabase = Supabase.instance.client;
  return NotificationService(FcmTokenRepository(supabase));
});

// Manejador en segundo plano (app cerrada o minimizada)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Notificación push en segundo plano: ${message.notification?.title}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Cargar variables de entorno
  await dotenv.load(fileName: '.env');

  // 2. Inicializar Firebase y registrar handler de segundo plano
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 3. Inicializar localización
  await initializeDateFormatting();
  Intl.defaultLocale = 'es_bo';

  // 4. Inicializar Supabase
  await initSupabase();

  runApp(
    const ProviderScope(
      child: AcademiaApp(),
    ),
  );
}

class AcademiaApp extends ConsumerStatefulWidget {
  const AcademiaApp({super.key});

  @override
  ConsumerState<AcademiaApp> createState() => _AcademiaAppState();
}

class _AcademiaAppState extends ConsumerState<AcademiaApp> {
  @override
  void initState() {
    super.initState();
    _setupNotifications();
  }

  void _setupNotifications() {
    final notificationService = ref.read(notificationServiceProvider);

    // Si ya existe una sesión activa al abrir la app, sincroniza el token
    if (Supabase.instance.client.auth.currentUser != null) {
      notificationService.initNotificationService();
    }

    // Escucha cambios de autenticación (inicios de sesión posteriores)
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        notificationService.initNotificationService();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return RepaintBoundary(
      key: themeRootBoundaryKey,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Academia Events',
        locale: const Locale('es'),
        supportedLocales: const [
          Locale('es'),
          Locale('es', 'BO'),
          Locale('en'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        themeAnimationDuration: const Duration(milliseconds: 450),
        themeAnimationCurve: Curves.easeInOut,
        routerConfig: router,
      ),
    );
  }
}