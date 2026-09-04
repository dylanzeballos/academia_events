import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/paginated_result.dart';
import '../../../../providers/public_events_provider.dart';

class PaginationControls extends ConsumerWidget {
  const PaginationControls({
    super.key,
    required this.paginatedResult,
    this.onPageChanged,
  });

  final PaginatedResult paginatedResult;
  final ValueChanged<int>? onPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (paginatedResult.totalPages <= 1) {
      return const SizedBox.shrink();
    }

    final currentPage = paginatedResult.currentPage;
    final totalPages = paginatedResult.totalPages;
    final notifier = ref.read(eventFiltersProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous page
          IconButton(
            onPressed: paginatedResult.hasPreviousPage
                ? () {
                    notifier.previousPage();
                    onPageChanged?.call(currentPage - 1);
                  }
                : null,
            icon: Icon(Icons.chevron_left, color: context.textOnBg),
            style: IconButton.styleFrom(
              backgroundColor: context.cardBg,
              foregroundColor: context.textOnBg,
            ),
          ),
          const SizedBox(width: 8),

          // Page numbers
          ..._buildPageNumbers(currentPage, totalPages).map((page) {
            if (page == -1) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '...',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              );
            }
            final isCurrent = page == currentPage;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: () {
                  notifier.goToPage(page);
                  onPageChanged?.call(page);
                },
                borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isCurrent ? AppColors.primary : context.cardBg,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                    border: Border.all(
                      color: isCurrent ? AppColors.primary : context.divider,
                    ),
                  ),
                  child: Text(
                    '$page',
                    style: TextStyle(
                      color: isCurrent ? Colors.white : context.textOnBg,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            );
          }),

          const SizedBox(width: 8),

          // Next page
          IconButton(
            onPressed: paginatedResult.hasNextPage
                ? () {
                    notifier.nextPage();
                    onPageChanged?.call(currentPage + 1);
                  }
                : null,
            icon: Icon(Icons.chevron_right, color: context.textOnBg),
            style: IconButton.styleFrom(
              backgroundColor: context.cardBg,
              foregroundColor: context.textOnBg,
            ),
          ),
        ],
      ),
    );
  }

  List<int> _buildPageNumbers(int current, int total) {
    if (total <= 7) {
      return List.generate(total, (i) => i + 1);
    }

    const edgeCount = 2; // Pages to show at start/end
    const middleCount = 3; // Pages to show around current

    final pages = <int>[];

    // First pages
    for (int i = 1; i <= edgeCount && i <= total; i++) {
      pages.add(i);
    }

    // Ellipsis after first pages
    if (current > edgeCount + middleCount) {
      pages.add(-1);
    }

    // Pages around current
    final start = (current - middleCount ~/ 2).clamp(edgeCount + 1, total - middleCount - edgeCount);
    final end = (start + middleCount - 1).clamp(start, total - edgeCount);
    for (int i = start; i <= end; i++) {
      pages.add(i);
    }

    // Ellipsis before last pages
    if (current < total - edgeCount - middleCount + 1) {
      pages.add(-1);
    }

    // Last pages
    for (int i = total - edgeCount + 1; i <= total; i++) {
      pages.add(i);
    }

    return pages;
  }
}