// lib/features/events/widgets/create/event_basic_info_form.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../providers/categories_provider.dart';

class EventBasicInfoForm extends ConsumerWidget {
  const EventBasicInfoForm({
    super.key,
    required this.titleController,
    required this.descriptionController,
    required this.contactPhoneController,
    required this.capacityController,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController contactPhoneController;
  final TextEditingController capacityController;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategoryChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventCategoriesAsync = ref.watch(eventCategoriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: titleController,
          style: TextStyle(color: context.textOnBg),
          decoration: InputDecoration(
            labelText: 'Título del evento *',
            hintText: 'Ej. Social Salsa & Bachata Night',
            labelStyle: TextStyle(color: context.textMuted),
            hintStyle: TextStyle(color: context.textMuted.withValues(alpha: 0.6)),
          ),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Ingresa un título' : null,
        ),
        const SizedBox(height: 16),
        eventCategoriesAsync.when(
          data: (categories) => DropdownButtonFormField<String>(
            initialValue: selectedCategoryId,
            dropdownColor: context.cardBg,
            style: TextStyle(color: context.textOnBg),
            decoration: InputDecoration(
              labelText: 'Tipo de Evento *',
              labelStyle: TextStyle(color: context.textMuted),
            ),
            items: categories
                .map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name, style: TextStyle(color: context.textOnBg)),
                    ))
                .toList(),
            onChanged: onCategoryChanged,
            validator: (v) => v == null ? 'Selecciona una categoría' : null,
          ),
          loading: () => const LinearProgressIndicator(color: AppColors.primary),
          error: (_, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: descriptionController,
          maxLines: 3,
          style: TextStyle(color: context.textOnBg),
          decoration: InputDecoration(
            labelText: 'Descripción del Evento *',
            hintText: 'Detalles del programa, código de vestimenta, etc.',
            labelStyle: TextStyle(color: context.textMuted),
            hintStyle: TextStyle(color: context.textMuted.withValues(alpha: 0.6)),
          ),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Ingresa una descripción' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: contactPhoneController,
          keyboardType: TextInputType.phone,
          style: TextStyle(color: context.textOnBg),
          decoration: InputDecoration(
            labelText: 'Teléfono Contacto',
            hintText: 'Ej. 77912345',
            labelStyle: TextStyle(color: context.textMuted),
            hintStyle: TextStyle(color: context.textMuted.withValues(alpha: 0.6)),
          ),
        ),
      ],
    );
  }
}