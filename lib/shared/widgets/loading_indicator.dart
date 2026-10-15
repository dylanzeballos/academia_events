import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class DancingLoaderApp extends StatelessWidget {
  const DancingLoaderApp({
    super.key,
    this.size = 200,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0E15).withOpacity(0.8),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF416C).withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Animación de pareja bailando con movimiento humano natural
                Lottie.network(
                  'https://assets2.lottiefiles.com/packages/lf20_t1q9y92m.json', 
                  width: size * 0.9,
                  height: size * 0.9,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Indicador de carga limpio
          const SizedBox(
            width: 140,
            child: LinearProgressIndicator(
              color: Color(0xFFFF416C),
              backgroundColor: Colors.white12,
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Cargando aplicación...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 13,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}