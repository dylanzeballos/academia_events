import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  static const int maxTitleLength = 70;
  static const int maxDescriptionLength = 600;

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
          maxLength: maxTitleLength,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(color: context.textOnBg),
          decoration: InputDecoration(
            labelText: 'Título del evento *',
            hintText: 'Ej. Social Salsa & Bachata Night',
            labelStyle: TextStyle(color: context.textMuted),
            hintStyle: TextStyle(color: context.textMuted.withValues(alpha: 0.6)),
          ),
          validator: (v) {
            final clean = v?.trim() ?? '';
            if (clean.isEmpty) return 'Ingresa un título';
            if (clean.length < 5) return 'Mínimo 5 caracteres';
            return null;
          },
        ),
        const SizedBox(height: 14),
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
                      child: Text(
                        c.name,
                        style: TextStyle(color: context.textOnBg),
                      ),
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
          maxLines: 4,
          maxLength: maxDescriptionLength,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(color: context.textOnBg),
          decoration: InputDecoration(
            labelText: 'Descripción del Evento *',
            hintText: 'Detalles del programa, artistas invitados, etc.',
            labelStyle: TextStyle(color: context.textMuted),
            hintStyle: TextStyle(color: context.textMuted.withValues(alpha: 0.6)),
          ),
          validator: (v) {
            final clean = v?.trim() ?? '';
            if (clean.isEmpty) return 'Ingresa una descripción';
            if (clean.length < 15) {
              return 'Describe el evento con al menos 15 caracteres';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: contactPhoneController,
          keyboardType: TextInputType.phone,
          maxLength: 15,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
          ],
          style: TextStyle(color: context.textOnBg),
          decoration: InputDecoration(
            labelText: 'Teléfono / WhatsApp de Contacto',
            hintText: 'Ej. 77912345',
            counterText: '',
            labelStyle: TextStyle(color: context.textMuted),
            hintStyle: TextStyle(color: context.textMuted.withValues(alpha: 0.6)),
          ),
          validator: (v) {
            final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
            if (digits.isEmpty) return null; // Opcional
            if (digits.length < 7 || digits.length > 15) {
              return 'Ingresa un número válido (7 a 15 dígitos)';
            }
            return null;
          },
        ),
      ],
    );
  }
}