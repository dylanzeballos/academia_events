import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Supabase
import 'package:supabase_flutter/supabase_flutter.dart';

// Core & Providers
import 'core/config/supabase_config.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/storage/preferences.dart';
import 'core/theme/app_theme.dart';
import 'providers/layout_mode_provider.dart';
import 'providers/notification_service_provider.dart';
import 'providers/theme_provider.dart';

/// Permite mostrar avisos in-app cuando llega un push con la app abierta.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// Manejador en segundo plano (app cerrada o minimizada)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint(
    'Notificación push en segundo plano: ${message.notification?.title}',
  );
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

  // 5. Preferencias locales (tema y modo de la app)
  final preferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const AcademiaApp(),
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

    // App abierta: FCM no muestra la notificación del sistema, así que se
    // presenta un aviso flotante dentro de la app.
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // El usuario tocó una notificación con la app en segundo plano.
    FirebaseMessaging.onMessageOpenedApp.listen(_openFromMessage);

    // La app estaba cerrada y se abrió desde una notificación.
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openFromMessage(message);
      });
    });
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title;
    final body = notification?.body;
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 6),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null && title.isNotEmpty)
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              if (body != null && body.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(body),
              ],
            ],
          ),
          action: SnackBarAction(
            label: 'Ver',
            onPressed: () => _openFromMessage(message),
          ),
        ),
      );
  }

  /// Abre la pantalla que corresponde al push: invitaciones o el centro de
  /// avisos. El backend envía `route=my_invitations` en el `data` del push.
  void _openFromMessage(RemoteMessage message) {
    if (Supabase.instance.client.auth.currentUser == null) return;

    final data = message.data;
    final type = data['type']?.toString();
    final route = data['route']?.toString();

    if (type == 'organization_invitation' ||
        route == 'my_invitations' ||
        data['invitation_id'] != null) {
      ref.read(appRouterProvider).go(AppRoutes.myInvitations);
      return;
    }

    _openNotifications();
  }

  void _openNotifications() {
    if (Supabase.instance.client.auth.currentUser == null) return;

    final mode = ref.read(effectiveLayoutModeProvider);
    final route = mode == AppLayoutMode.academy
        ? AppRoutes.academyNotifications
        : AppRoutes.studentNotifications;

    ref.read(appRouterProvider).go(route);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    // Respeta "reducir movimiento" del sistema.
    final reduceMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Academia Events',
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('es', 'BO'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      // Transición nativa entre temas (AnimatedTheme): corta y con la curva
      // enfatizada de Material 3 para que no se sienta lenta.
      themeAnimationDuration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 300),
      themeAnimationCurve: Curves.easeInOutCubicEmphasized,
      routerConfig: router,
    );
  }
}
