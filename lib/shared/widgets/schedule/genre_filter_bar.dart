import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/class_presentation.dart';
import '../../../core/utils/theme_extensions.dart';

/// Selector de ritmo para filtrar una grilla de clases.
///
/// Muestra "Todos" + un chip por ritmo, con su color y cuántas clases tiene.
/// El chip seleccionado funciona también como leyenda de colores.
class GenreFilterBar extends StatelessWidget {
  const GenreFilterBar({
    super.key,
    required this.genres,
    required this.selected,
    required this.onSelected,
    this.countFor,
  });

  /// Ritmos disponibles, ya ordenados.
  final List<String> genres;

  /// `null` = todas las clases.
  final String? selected;

  final ValueChanged<String?> onSelected;

  /// Cantidad de clases por ritmo (opcional).
  final int Function(String genre)? countFor;

  @override
  Widget build(BuildContext context) {
    if (genres.isEmpty) return const SizedBox.shrink();

    final total = countFor == null
        ? null
        : genres.fold<int>(0, (sum, genre) => sum + countFor!(genre));

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: context.cardBg,
        border: Border(bottom: BorderSide(color: context.divider)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _GenreChip(
            label: 'Todos',
            count: total,
            isSelected: selected == null,
            onTap: () => onSelected(null),
          ),
          const SizedBox(width: 6),
          for (final genre in genres) ...[
            _GenreChip(
              label: genre,
              color: genreColor(genre),
              count: countFor?.call(genre),
              isSelected: selected == genre,
              onTap: () => onSelected(genre),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
    this.count,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: count == null
          ? label
          : '$label, ${count == 1 ? '1 clase' : '$count clases'}',
      child: Material(
        color: isSelected
            ? accent.withValues(alpha: 0.14)
            : context.surfaceHeader,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? accent : context.divider,
                width: isSelected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                if (color != null) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? accent : context.textOnBg,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 5),
                  Text(
                    '$count',
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
