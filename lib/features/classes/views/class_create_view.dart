import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/dance_class_provider.dart';
import '../../../shared/widgets/app_button.dart';

class ClassCreateView extends ConsumerStatefulWidget {
  const ClassCreateView({super.key});

  @override
  ConsumerState<ClassCreateView> createState() => _ClassCreateViewState();
}

class _ClassCreateViewState extends ConsumerState<ClassCreateView> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '0');

  final List<_ScheduleEntry> _schedules = [];
  DateTime? _startAt;
  DateTime? _endAt;
  String? _selectedInstructorId;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _capacityCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final schedules = _schedules.map((s) => {
      'day_of_week': s.dayOfWeek,
      'start_time': '${s.startHour.toString().padLeft(2, '0')}:${s.startMinute.toString().padLeft(2, '0')}:00',
      'end_time': '${s.endHour.toString().padLeft(2, '0')}:${s.endMinute.toString().padLeft(2, '0')}:00',
      'instructor_id': _selectedInstructorId,
    }).toList();

    final notifier = ref.read(createClassProvider.notifier);
    final success = await notifier.create(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      capacity: int.tryParse(_capacityCtrl.text),
      price: double.tryParse(_priceCtrl.text) ?? 0,
      instructorId: _selectedInstructorId,
      startAt: _startAt,
      endAt: _endAt,
      schedules: schedules.isNotEmpty ? schedules : null,
    );

    if (success && mounted) {
      ref.invalidate(orgClassesProvider);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clase creada')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(createClassProvider);
    final instructorsAsync = ref.watch(orgInstructorsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Crear Clase')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleCtrl,
                validator: AppValidators.eventTitle,
                decoration: const InputDecoration(labelText: 'Nombre de la clase *'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _capacityCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cupos'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Precio'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Instructor selector
              Text(
                'Instructor',
                style: TextStyle(color: context.textOnBg, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              instructorsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('Error cargando instructores', style: TextStyle(color: Colors.grey)),
                data: (instructors) {
                  return               DropdownButtonFormField<String>(
                    initialValue: _selectedInstructorId,
                    dropdownColor: context.cardBg,
                    style: TextStyle(color: context.textOnBg),
                    decoration: const InputDecoration(hintText: 'Seleccionar instructor'),
                    items: instructors.map((i) {
                      final profile = i['profiles'] as Map<String, dynamic>?;
                      final name = '${profile?['first_name'] ?? ''} ${profile?['last_name'] ?? ''}'.trim();
                      return DropdownMenuItem(
                        value: i['user_id'] as String,
                        child: Text(name.isNotEmpty ? name : 'Sin nombre'),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedInstructorId = v),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Date range
              Text(
                'Período de la clase',
                style: TextStyle(color: context.textOnBg, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DateButton(
                      label: 'Inicio',
                      date: _startAt,
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startAt ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setState(() => _startAt = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateButton(
                      label: 'Fin',
                      date: _endAt,
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _endAt ?? DateTime.now().add(const Duration(days: 90)),
                          firstDate: _startAt ?? DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setState(() => _endAt = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Schedules
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Horarios recurrentes',
                    style: TextStyle(color: context.textOnBg, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  TextButton.icon(
                    onPressed: () => _addSchedule(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Agregar'),
                  ),
                ],
              ),
              if (_schedules.isEmpty)
                Card(
                  color: context.cardBg,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'Sin horarios definidos',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                )
              else
                ...List.generate(_schedules.length, (i) {
                  final s = _schedules[i];
                  return Card(
                    color: context.cardBg,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        s.dayName,
                        style: TextStyle(color: context.textOnBg, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        '${s.startHour.toString().padLeft(2, '0')}:${s.startMinute.toString().padLeft(2, '0')} - ${s.endHour.toString().padLeft(2, '0')}:${s.endMinute.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                        onPressed: () => setState(() => _schedules.removeAt(i)),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 32),

              if (createState.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    createState.error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),

              AppButton(
                label: 'Crear Clase',
                onPressed: _submit,
                isLoading: createState.isLoading,
                icon: Icons.save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addSchedule(BuildContext context) {
    int selectedDay = 1;
    int startHour = 19;
    int startMinute = 0;
    int endHour = 20;
    int endMinute = 30;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Agregar horario', style: TextStyle(color: context.textOnBg)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedDay,
                dropdownColor: context.cardBg,
                style: TextStyle(color: context.textOnBg),
                decoration: const InputDecoration(labelText: 'Día'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Lunes')),
                  DropdownMenuItem(value: 2, child: Text('Martes')),
                  DropdownMenuItem(value: 3, child: Text('Miércoles')),
                  DropdownMenuItem(value: 4, child: Text('Jueves')),
                  DropdownMenuItem(value: 5, child: Text('Viernes')),
                  DropdownMenuItem(value: 6, child: Text('Sábado')),
                  DropdownMenuItem(value: 0, child: Text('Domingo')),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedDay = v);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: startHour,
                      dropdownColor: context.cardBg,
                      style: TextStyle(color: context.textOnBg),
                      decoration: const InputDecoration(labelText: 'Hora inicio'),
                      items: List.generate(24, (i) => DropdownMenuItem(
                        value: i,
                        child: Text(i.toString().padLeft(2, '0')),
                      )),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => startHour = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: startMinute,
                      dropdownColor: context.cardBg,
                      style: TextStyle(color: context.textOnBg),
                      decoration: const InputDecoration(labelText: 'Min'),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('00')),
                        DropdownMenuItem(value: 15, child: Text('15')),
                        DropdownMenuItem(value: 30, child: Text('30')),
                        DropdownMenuItem(value: 45, child: Text('45')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => startMinute = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: endHour,
                      dropdownColor: context.cardBg,
                      style: TextStyle(color: context.textOnBg),
                      decoration: const InputDecoration(labelText: 'Hora fin'),
                      items: List.generate(24, (i) => DropdownMenuItem(
                        value: i,
                        child: Text(i.toString().padLeft(2, '0')),
                      )),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => endHour = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: endMinute,
                      dropdownColor: context.cardBg,
                      style: TextStyle(color: context.textOnBg),
                      decoration: const InputDecoration(labelText: 'Min'),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('00')),
                        DropdownMenuItem(value: 15, child: Text('15')),
                        DropdownMenuItem(value: 30, child: Text('30')),
                        DropdownMenuItem(value: 45, child: Text('45')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => endMinute = v);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _schedules.add(_ScheduleEntry(
                    dayOfWeek: selectedDay,
                    startHour: startHour,
                    startMinute: startMinute,
                    endHour: endHour,
                    endMinute: endMinute,
                  ));
                });
                Navigator.pop(ctx);
              },
              child: const Text('Agregar', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleEntry {
  final int dayOfWeek;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  _ScheduleEntry({
    required this.dayOfWeek,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  String get dayName => switch (dayOfWeek) {
        0 => 'Domingo',
        1 => 'Lunes',
        2 => 'Martes',
        3 => 'Miércoles',
        4 => 'Jueves',
        5 => 'Viernes',
        6 => 'Sábado',
        _ => '',
      };
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.date,
    required this.onPressed,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final dateStr = date != null
        ? '${date!.day.toString().padLeft(2, '0')}/${date!.month.toString().padLeft(2, '0')}/${date!.year}'
        : 'Seleccionar';

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: context.textOnBg,
        side: BorderSide(color: context.divider),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        ),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 2),
          Text(dateStr, style: TextStyle(color: context.textOnBg, fontSize: 14)),
        ],
      ),
    );
  }
}
