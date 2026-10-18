import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../providers/public_events_provider.dart';

class EventSearchBar extends ConsumerStatefulWidget {
  const EventSearchBar({
    super.key,
    this.hintText = 'Buscar academias, clases o géneros...',
    this.onSubmitted,
    this.autoFocus = false,
    this.compact = false,
  });

  final String hintText;
  final ValueChanged<String>? onSubmitted;
  final bool autoFocus;
  final bool compact;

  @override
  ConsumerState<EventSearchBar> createState() => _EventSearchBarState();
}

class _EventSearchBarState extends ConsumerState<EventSearchBar> {
  Timer? _debounce;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
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
    if (_controller.text != filter.searchQuery) {
      _controller.text = filter.searchQuery;
    }

    return TextField(
      controller: _controller,
      autofocus: widget.autoFocus,
      style: TextStyle(color: context.textOnBg, fontSize: widget.compact ? 12 : 14),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: TextStyle(
          color: context.textMuted,
          fontSize: widget.compact ? 10 : 14,
        ),
        prefixIcon: Icon(
          Icons.search,
          color: context.textMuted,
          size: widget.compact ? 15 : 22,
        ),
        prefixIconConstraints: widget.compact
            ? const BoxConstraints(minWidth: 30, minHeight: 30)
            : null,
        suffixIcon: filter.searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(
                  Icons.clear,
                  color: context.textMuted,
                  size: widget.compact ? 15 : 22,
                ),
                onPressed: () {
                  _debounce?.cancel();
                  _controller.clear();
                  notifier.setSearchQuery('');
                },
                tooltip: 'Limpiar búsqueda',
              )
            : null,
        filled: true,
        fillColor: context.cardBg,
        contentPadding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 8 : 16,
          vertical: widget.compact ? 4 : 12,
        ),
        isDense: widget.compact,
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
      child: const EventSearchBar(
        hintText: 'Buscar eventos por nombre, lugar, categoría...',
      ),
    );
  }
}