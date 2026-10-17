// lib/feature/organization/classes/views/class_create_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:academia_events/core/theme/app_colors.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';
import 'package:academia_events/providers/dance_class_provider.dart';

class ClassCreateView extends ConsumerStatefulWidget {
  const ClassCreateView({super.key});

  @override
  ConsumerState<ClassCreateView> createState() => _ClassCreateViewState();
}

class _ClassCreateViewState extends ConsumerState<ClassCreateView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController(text: '0');
  final _capacityController = TextEditingController();

  TimeOfDay _startTime = const TimeOfDay(hour: 19, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 20, minute: 15);

  // 1 = Lun, 2 = Mar, 3 = Mié, 4 = Jue, 5 = Vie, 6 = Sáb, 0 = Dom (Postgres day_of_week)
  final Set<int> _selectedDays = {1, 3, 5};

  static const _daysMap = [
    (1, 'L', 'Lunes'),
    (2, 'M', 'Martes'),
    (3, 'X', 'Miércoles'),
    (4, 'J', 'Jueves'),
    (5, 'V', 'Viernes'),
    (6, 'S', 'Sábado'),
    (0, 'D', 'Domingo'),
  ];

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() => isStart ? _startTime = picked : _endTime = picked);
    }
  }

  void _applyPreset(Set<int> days) {
    setState(() {
      _selectedDays.clear();
      _selectedDays.addAll(days);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createClassProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        title: const Text('Crear Horario de Clase'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                style: TextStyle(color: context.textOnBg),
                decoration: InputDecoration(
                  labelText: 'Título de la clase (ej: Salsa Cubana)',
                  labelStyle: TextStyle(color: context.textMuted),
                  filled: true,
                  fillColor: context.cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.divider),
                  ),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Ingresa el nombre' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _descController,
                maxLines: 2,
                style: TextStyle(color: context.textOnBg),
                decoration: InputDecoration(
                  labelText: 'Descripción (ej: Nivel básico, ropa cómoda)',
                  labelStyle: TextStyle(color: context.textMuted),
                  filled: true,
                  fillColor: context.cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.divider),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              Text(
                'DÍAS EN LOS QUE SE IMPARTE',
                style: TextStyle(
                  color: context.textOnBg,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('L-M-V'),
                    backgroundColor: context.cardBg,
                    side: BorderSide(color: context.divider),
                    onPressed: () => _applyPreset({1, 3, 5}),
                  ),
                  ActionChip(
                    label: const Text('M-J'),
                    backgroundColor: context.cardBg,
                    side: BorderSide(color: context.divider),
                    onPressed: () => _applyPreset({2, 4}),
                  ),
                  ActionChip(
                    label: const Text('Lun a Sáb'),
                    backgroundColor: context.cardBg,
                    side: BorderSide(color: context.divider),
                    onPressed: () => _applyPreset({1, 2, 3, 4, 5, 6}),
                  ),
                  ActionChip(
                    label: const Text('Todos'),
                    backgroundColor: context.cardBg,
                    side: BorderSide(color: context.divider),
                    onPressed: () => _applyPreset({1, 2, 3, 4, 5, 6, 0}),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _daysMap.map((d) {
                  final isSelected = _selectedDays.contains(d.$1);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          if (_selectedDays.length > 1) _selectedDays.remove(d.$1);
                        } else {
                          _selectedDays.add(d.$1);
                        }
                      });
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : context.cardBg,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.transparent : context.divider,
                        ),
                      ),
                      child: Text(
                        d.$2,
                        style: TextStyle(
                          color: isSelected ? Colors.white : context.textMuted,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      tileColor: context.cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: context.divider),
                      ),
                      title: Text(
                        'Hora Inicio',
                        style: TextStyle(color: context.textMuted, fontSize: 12),
                      ),
                      subtitle: Text(
                        _startTime.format(context),
                        style: TextStyle(
                          color: context.textOnBg,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(Icons.access_time, color: AppColors.primary),
                      onTap: () => _pickTime(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ListTile(
                      tileColor: context.cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: context.divider),
                      ),
                      title: Text(
                        'Hora Fin',
                        style: TextStyle(color: context.textMuted, fontSize: 12),
                      ),
                      subtitle: Text(
                        _endTime.format(context),
                        style: TextStyle(
                          color: context.textOnBg,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(Icons.access_time, color: AppColors.primary),
                      onTap: () => _pickTime(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: context.textOnBg),
                      decoration: InputDecoration(
                        labelText: 'Precio (BOB)',
                        labelStyle: TextStyle(color: context.textMuted),
                        filled: true,
                        fillColor: context.cardBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: context.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: context.divider),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _capacityController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: context.textOnBg),
                      decoration: InputDecoration(
                        labelText: 'Cupos (Opcional)',
                        labelStyle: TextStyle(color: context.textMuted),
                        filled: true,
                        fillColor: context.cardBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: context.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: context.divider),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: state.isLoading
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          final ok = await ref
                              .read(createClassProvider.notifier)
                              .createWithDays(
                                title: _titleController.text.trim(),
                                description: _descController.text.trim(),
                                price: double.tryParse(_priceController.text) ?? 0.0,
                                capacity: int.tryParse(_capacityController.text),
                                startTime: _formatTime(_startTime),
                                endTime: _formatTime(_endTime),
                                selectedDays: _selectedDays,
                              );
                          if (ok && context.mounted) Navigator.pop(context);
                        },
                  child: state.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Guardar Horario',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}