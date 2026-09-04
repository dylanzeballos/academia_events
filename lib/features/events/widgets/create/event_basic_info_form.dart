import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          decoration: const InputDecoration(
            labelText: 'Título del evento *',
            hintText: 'Ej. Social Salsa & Bachata Night',
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
            decoration: const InputDecoration(labelText: 'Tipo de Evento *'),
            items: categories
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                .toList(),
            onChanged: onCategoryChanged,
            validator: (v) => v == null ? 'Selecciona una categoría' : null,
          ),
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: descriptionController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Descripción del Evento *',
            hintText: 'Detalles del programa, código de vestimenta, etc.',
          ),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Ingresa una descripción' : null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: contactPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono Contacto',
                  hintText: 'Ej. 77912345',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Aforo Total',
                  hintText: 'Ej. 150',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}