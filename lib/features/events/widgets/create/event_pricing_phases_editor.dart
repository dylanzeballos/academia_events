// lib/features/events/widgets/create/event_pricing_phases_editor.dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/theme_extensions.dart';

class PricingPhaseItem {
  PricingPhaseItem({
    required this.name,
    required this.priceController,
    required this.stockController,
    this.startDate,
    this.endDate,
  });

  final String name; // Nombre fijo: Preventa, Venta General o En Puerta
  final TextEditingController priceController;
  final TextEditingController stockController;
  DateTime? startDate;
  DateTime? endDate;

  void dispose() {
    priceController.dispose();
    stockController.dispose();
  }
}

class EventPricingPhasesEditor extends StatefulWidget {
  const EventPricingPhasesEditor({
    super.key,
    required this.eventStartDate,
    required this.isTheatreEvent,
    required this.onTicketsDataChanged,
  });

  final DateTime eventStartDate;
  final bool isTheatreEvent;
  final ValueChanged<List<Map<String, dynamic>>> onTicketsDataChanged;
  @override
  State<EventPricingPhasesEditor> createState() =>
      _EventPricingPhasesEditorState();
}

class _EventPricingPhasesEditorState extends State<EventPricingPhasesEditor> {
  bool _usePhases = false;

  // Modo Simple (1 precio único)
  final _singlePriceCtrl = TextEditingController();
  final _singleStockCtrl = TextEditingController(text: '100');
  bool _isUnlimitedStock = false;

  // 3 Fases fijas
  late final List<PricingPhaseItem> _phases;

  @override
  void initState() {
    super.initState();
    _initFixedPhases();
    _emitChanges();
  }

  @override
  void didUpdateWidget(covariant EventPricingPhasesEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventStartDate != widget.eventStartDate) {
      _recalculateDefaultDates();
      _emitChanges();
    }
  }

  @override
  void dispose() {
    _singlePriceCtrl.dispose();
    _singleStockCtrl.dispose();
    for (final p in _phases) {
      p.dispose();
    }
    super.dispose();
  }

  void _initFixedPhases() {
    final now = DateTime.now();
    final eventDay = widget.eventStartDate;

    final totalDays = eventDay.difference(now).inDays;
    final halfDays = totalDays > 1 ? (totalDays / 2).floor() : 1;
    final preventaEnd = now.add(Duration(days: halfDays));

    _phases = [
      PricingPhaseItem(
        name: 'Preventa',
        priceController:
            TextEditingController(), // Vacío para que pongan su precio
        stockController: TextEditingController(text: '50'),
        startDate: now,
        endDate: preventaEnd,
      ),
      PricingPhaseItem(
        name: 'Venta General',
        priceController:
            TextEditingController(), // Vacío para que pongan su precio
        stockController: TextEditingController(text: '100'),
        startDate: preventaEnd,
        endDate: eventDay.subtract(const Duration(hours: 4)),
      ),
      PricingPhaseItem(
        name: 'En Puerta',
        priceController:
            TextEditingController(), // Vacío para que pongan su precio
        stockController: TextEditingController(text: '50'),
        startDate: eventDay.subtract(const Duration(hours: 4)),
        endDate: eventDay.add(const Duration(hours: 8)),
      ),
    ];
  }

  void _recalculateDefaultDates() {
    final now = DateTime.now();
    final eventDay = widget.eventStartDate;

    final totalDays = eventDay.difference(now).inDays;
    final halfDays = totalDays > 1 ? (totalDays / 2).floor() : 1;
    final preventaEnd = now.add(Duration(days: halfDays));

    _phases[0].startDate = now;
    _phases[0].endDate = preventaEnd;

    _phases[1].startDate = preventaEnd;
    _phases[1].endDate = eventDay.subtract(const Duration(hours: 4));

    _phases[2].startDate = eventDay.subtract(const Duration(hours: 4));
    _phases[2].endDate = eventDay.add(const Duration(hours: 8));
  }

  void _emitChanges() {
    final List<Map<String, dynamic>> result = [];

    if (!_usePhases) {
      final price = double.tryParse(_singlePriceCtrl.text.trim()) ?? 0.0;
      final stock = _isUnlimitedStock
          ? 999999
          : (int.tryParse(_singleStockCtrl.text.trim()) ?? 100);

      result.add({
        'name': widget.isTheatreEvent ? 'Butaca Numerada' : 'Entrada General',
        'description': widget.isTheatreEvent
            ? 'Asiento numerado'
            : 'Acceso general',
        'price': price,
        'quantity': stock,
        'currency': 'BOB',
        'is_active': true,
        'sales_start_at': DateTime.now().toIso8601String(),
        'sales_end_at': widget.eventStartDate
            .add(const Duration(hours: 12))
            .toIso8601String(),
      });
    } else {
      for (final phase in _phases) {
        final price = double.tryParse(phase.priceController.text.trim()) ?? 0.0;
        final stock = int.tryParse(phase.stockController.text.trim()) ?? 50;

        result.add({
          'name': phase.name,
          'description': 'Tarifa ${phase.name}',
          'price': price,
          'quantity': stock,
          'currency': 'BOB',
          'is_active': true,
          'sales_start_at': phase.startDate?.toIso8601String(),
          'sales_end_at': phase.endDate?.toIso8601String(),
        });
      }
    }

    widget.onTicketsDataChanged(result);
  }

  Future<void> _pickPhaseEndDate(int index) async {
    final phase = _phases[index];
    final picked = await showDatePicker(
      context: context,
      initialDate: phase.endDate ?? widget.eventStartDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: widget.eventStartDate.add(const Duration(days: 2)),
    );

    if (picked != null) {
      setState(() {
        phase.endDate = DateTime(picked.year, picked.month, picked.day, 23, 59);
        // Encadena el inicio de la siguiente fase consecutiva
        if (index + 1 < _phases.length) {
          _phases[index + 1].startDate = phase.endDate;
        }
      });
      _emitChanges();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: context.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Precios y Fases de Venta',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Habilitar 3 etapas: Preventa, Venta General y En Puerta',
                      style: TextStyle(color: context.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _usePhases,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() => _usePhases = val);
                  _emitChanges();
                },
              ),
            ],
          ),
          const Divider(height: 20),

          if (!_usePhases) ...[
            TextFormField(
              controller: _singlePriceCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(color: context.textOnBg),
              decoration: const InputDecoration(
                labelText: 'Precio de la Entrada *',
                hintText: 'Ingresa el precio',
                prefixText: 'Bs. ',
              ),
              onChanged: (_) => _emitChanges(),
            ),
            const SizedBox(height: 10),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Cupos ilimitados',
                style: TextStyle(fontSize: 14),
              ),
              value: _isUnlimitedStock,
              onChanged: (val) {
                setState(() => _isUnlimitedStock = val);
                _emitChanges();
              },
            ),
            if (!_isUnlimitedStock)
              TextFormField(
                controller: _singleStockCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: context.textOnBg),
                decoration: const InputDecoration(
                  labelText: 'Stock total de entradas *',
                  hintText: 'Ej. 100',
                  suffixText: 'tickets',
                ),
                onChanged: (_) => _emitChanges(),
              ),
          ] else ...[
            // Las 3 fases fijas
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _phases.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final p = _phases[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.scaffoldBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: context.divider.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Nombre fijo (Badge)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              p.name,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Precio configurable
                          SizedBox(
                            width: 130,
                            child: TextFormField(
                              controller: p.priceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                color: context.textOnBg,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Precio',
                                hintText: '0.00',
                                prefixText: 'Bs. ',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 8,
                                ),
                              ),
                              onChanged: (_) => _emitChanges(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // Selector de fecha límite
                          InkWell(
                            onTap: () => _pickPhaseEndDate(index),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 2,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_month_outlined,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    p.endDate != null
                                        ? 'Válido hasta: ${p.endDate!.day}/${p.endDate!.month}/${p.endDate!.year}'
                                        : 'Definir fin',
                                    style: TextStyle(
                                      color: context.textOnBg,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Cantidad de tickets configurable
                          SizedBox(
                            width: 110,
                            child: TextFormField(
                              controller: p.stockController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                color: context.textMuted,
                                fontSize: 12,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Cupos',
                                suffixText: 'tickets',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 6,
                                  horizontal: 8,
                                ),
                              ),
                              onChanged: (_) => _emitChanges(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
