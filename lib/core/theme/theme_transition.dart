import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_provider.dart';

/// Cambia entre modo claro y oscuro.
///
/// La transición la resuelve `MaterialApp` con su animación nativa
/// (`themeAnimationDuration` + `AnimatedTheme`): colores interpolados por el
/// engine, sin capturas de pantalla ni overlays que congelen la UI.
void toggleTheme(WidgetRef ref) {
  ref.read(themeModeProvider.notifier).toggle();
}

class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final isDark = switch (mode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };

    return IconButton(
      tooltip: isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
      onPressed: () => toggleTheme(ref),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) => RotationTransition(
          turns: Tween<double>(begin: 0.8, end: 1).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          key: ValueKey<bool>(isDark),
          color: color,
        ),
      ),
    );
  }
}
