import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_provider.dart';

/// Key del [RepaintBoundary] raíz, usado para capturar la pantalla actual
/// antes de cambiar de tema.
final GlobalKey themeRootBoundaryKey = GlobalKey();

/// Cambia entre tema claro y oscuro con un "revelado" circular que nace desde
/// [origin] (por ejemplo, el centro del botón pulsado).
///
/// Si la captura de pantalla no está disponible (p. ej. algunas plataformas),
/// cambia el tema igualmente y la animación base del tema se encarga.
Future<void> animateThemeToggle(
  BuildContext context,
  WidgetRef ref, {
  required Offset origin,
  Duration duration = const Duration(milliseconds: 520),
}) async {
  // 1. Capturar la pantalla actual (tema anterior).
  Uint8List? screenshot;
  try {
    final boundary = themeRootBoundaryKey.currentContext?.findRenderObject();
    if (boundary is RenderRepaintBoundary) {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      screenshot = data?.buffer.asUint8List();
      image.dispose();
    }
  } catch (_) {
    screenshot = null;
  }

  // 2. Cambiar el tema.
  final current = ref.read(themeModeProvider);
  ref
      .read(themeModeProvider.notifier)
      .set(current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  if (screenshot == null || !context.mounted) return;

  // 3. Superponer la captura anterior y retirarla con un círculo creciente.
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  final size = MediaQuery.sizeOf(context);
  final maxRadius = _maxRadiusFrom(origin, size);

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ThemeRevealOverlay(
      imageBytes: screenshot!,
      origin: origin,
      maxRadius: maxRadius,
      duration: duration,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

double _maxRadiusFrom(Offset origin, Size size) {
  final dx = math.max(origin.dx, size.width - origin.dx);
  final dy = math.max(origin.dy, size.height - origin.dy);
  return math.sqrt(dx * dx + dy * dy);
}

/// Botón de cambio de tema reutilizable (con revelado circular). Se puede
/// colocar en cualquier AppBar o barra de acciones.
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Builder(
      builder: (buttonContext) => IconButton(
        tooltip: isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
        icon: Icon(
          isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          color: color,
        ),
        onPressed: () {
          final box = buttonContext.findRenderObject() as RenderBox?;
          final origin = box != null
              ? box.localToGlobal(box.size.center(Offset.zero))
              : MediaQuery.sizeOf(context).center(Offset.zero);
          animateThemeToggle(context, ref, origin: origin);
        },
      ),
    );
  }
}

class _ThemeRevealOverlay extends StatefulWidget {
  const _ThemeRevealOverlay({
    required this.imageBytes,
    required this.origin,
    required this.maxRadius,
    required this.duration,
    required this.onDone,
  });

  final Uint8List imageBytes;
  final Offset origin;
  final double maxRadius;
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_ThemeRevealOverlay> createState() => _ThemeRevealOverlayState();
}

class _ThemeRevealOverlayState extends State<_ThemeRevealOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      });
    ui.decodeImageFromList(widget.imageBytes, (image) {
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _image = image);
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final size = MediaQuery.sizeOf(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (image == null) return const SizedBox.shrink();
          final t = Curves.easeInOutCubic.transform(_controller.value);
          return ClipPath(
            clipper: _InverseCircleClipper(
              center: widget.origin,
              radius: widget.maxRadius * t,
            ),
            child: RawImage(
              image: image,
              width: size.width,
              height: size.height,
              fit: BoxFit.cover,
            ),
          );
        },
      ),
    );
  }
}

/// Deja visible todo excepto un círculo creciente (el "revelado").
class _InverseCircleClipper extends CustomClipper<Path> {
  _InverseCircleClipper({required this.center, required this.radius});

  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final circle = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    return Path.combine(PathOperation.difference, full, circle);
  }

  @override
  bool shouldReclip(covariant _InverseCircleClipper oldClipper) =>
      oldClipper.radius != radius || oldClipper.center != center;
}
