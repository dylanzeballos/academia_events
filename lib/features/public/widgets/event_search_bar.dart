import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../providers/public_events_provider.dart';

class EventSearchBar extends ConsumerStatefulWidget {
  const EventSearchBar({
    super.key,
    this.hintText = 'Buscar eventos...',
    this.onSubmitted,
    this.autoFocus = false,
  });

  final String hintText;
  final ValueChanged<String>? onSubmitted;
  final bool autoFocus;

  @override
  ConsumerState<EventSearchBar> createState() => _EventSearchBarState();
}

class _EventSearchBarState extends ConsumerState<EventSearchBar> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value, EventFiltersNotifier notifier) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      notifier.setSearchQuery(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(eventFiltersProvider);
    final notifier = ref.read(eventFiltersProvider.notifier);

    return TextField(
      autofocus: widget.autoFocus,
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
        prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 22),
        suffixIcon: filter.searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, color: Colors.grey[500], size: 22),
                onPressed: () => notifier.setSearchQuery(''),
                tooltip: 'Limpiar búsqueda',
              )
            : null,
        filled: true,
        fillColor: context.cardBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide: BorderSide(color: context.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide: BorderSide(color: context.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      onChanged: (value) => _onChanged(value, notifier),
      onSubmitted: widget.onSubmitted,
      textInputAction: TextInputAction.search,
    );
  }
}

class EventSearchBarDesktop extends ConsumerWidget {
  const EventSearchBarDesktop({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      child: const EventSearchBar(hintText: 'Buscar eventos por nombre, lugar, categoría...'),
    );
  }
}