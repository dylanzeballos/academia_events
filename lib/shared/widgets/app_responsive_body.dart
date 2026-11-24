import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Contenido centrado con ancho máximo para móvil, tablet y web.
class AppResponsiveBody extends StatelessWidget {
  const AppResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = 820,
    this.padding = const EdgeInsets.all(AppSizes.paddingMedium),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
