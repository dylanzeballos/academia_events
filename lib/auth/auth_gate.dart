import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../components/Navegación.dart';
import '../page/auth/login_page.dart';
import '../page/auth/update_password_page.dart';
import 'auth_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.authService});

  final IAuthService? authService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final IAuthService _authService;
  StreamSubscription<AuthState>? _authSub;
  Session? _session;
  bool _isPasswordRecoveryFlow = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService.instance;
    _session = _authService.currentSession;

    _authSub = _authService.onAuthStateChange.listen((state) {
      final previousSession = _session;

      if (!mounted) {
        return;
      }

      setState(() {
        _session = state.session;

        if (state.event == AuthChangeEvent.passwordRecovery) {
          _isPasswordRecoveryFlow = true;
          _message = null;
          return;
        }

        if (state.event == AuthChangeEvent.signedOut) {
          final isManual = _authService.consumeManualSignOutFlag();
          _isPasswordRecoveryFlow = false;
          if (!isManual && previousSession != null) {
            _message = 'Tu sesion expiro. Inicia sesion nuevamente.';
          }
          return;
        }

        if (state.event == AuthChangeEvent.signedIn ||
            state.event == AuthChangeEvent.tokenRefreshed) {
          _isPasswordRecoveryFlow = false;
          _message = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return LoginPage(
        authService: _authService,
        initialMessage: _message,
      );
    }

    if (_isPasswordRecoveryFlow) {
      return UpdatePasswordPage(authService: _authService);
    }

    return const Navegacion();
  }
}