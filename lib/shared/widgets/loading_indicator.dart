import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

/// Indicador de carga centrado con el color primario de la app.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 3,
        ),
      ),
    );
  }
}

/// Pantalla completa de carga
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: LoadingIndicator(),
    );
  }
}
