import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  final String name;
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
    required this.eventEndDate,
    required this.isTheatreEvent,
    required this.onTicketsDataChanged,
  });

  final DateTime eventStartDate;
  final DateTime eventEndDate;
  final bool isTheatreEvent;
  final  ValueChanged<List<Map<String, dynamic>>> onTicketsDataChanged;

  @override
  State<EventPricingPhasesEditor> createState() =>
      _EventPricingPhasesEditorState();
}

class _EventPricingPhasesEditorState extends State<EventPricingPhasesEditor> {
  bool _usePhases = false;
  bool _userEditedPhaseDates = false;

  // Modo Simple
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
    if (oldWidget.eventStartDate != widget.eventStartDate ||
        oldWidget.eventEndDate != widget.eventEndDate) {
      if (!_userEditedPhaseDates) {
        _recalculateDefaultDates();
      } else {
        _clampPhaseDatesToEvent();
      }
      _emitChanges();
    }
    if (oldWidget.isTheatreEvent != widget.isTheatreEvent) {
      if (widget.isTheatreEvent) {
        _isUnlimitedStock = false;
      }
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
    final eventStart = widget.eventStartDate;
    final eventEnd = widget.eventEndDate;

    final totalMinutes = eventStart.difference(now).inMinutes;
    final halfMinutes = totalMinutes > 60 ? (totalMinutes / 2).floor() : 30;
    final preventaEnd = now.add(Duration(minutes: halfMinutes));
    final generalEnd = eventStart.isAfter(preventaEnd)
        ? eventStart
        : preventaEnd.add(const Duration(minutes: 30));

    _phases = [
      PricingPhaseItem(
        name: 'Preventa',
        priceController: TextEditingController(),
        stockController: TextEditingController(text: '50'),
        startDate: now,
        endDate: preventaEnd,
      ),
      PricingPhaseItem(
        name: 'Venta General',
        priceController: TextEditingController(),
        stockController: TextEditingController(text: '100'),
        startDate: preventaEnd,
        endDate: generalEnd,
      ),
      PricingPhaseItem(
        name: 'En Puerta',
        priceController: TextEditingController(),
        stockController: TextEditingController(text: '50'),
        startDate: generalEnd,
        endDate: eventEnd,
      ),
    ];
  }

  void _recalculateDefaultDates() {
    final now = DateTime.now();
    final eventStart = widget.eventStartDate;
    final eventEnd = widget.eventEndDate;

    final totalMinutes = eventStart.difference(now).inMinutes;
    final halfMinutes = totalMinutes > 60 ? (totalMinutes / 2).floor() : 30;
    final preventaEnd = now.add(Duration(minutes: halfMinutes));
    final generalEnd = eventStart.isAfter(preventaEnd)
        ? eventStart
        : preventaEnd.add(const Duration(minutes: 30));

    _phases[0].startDate = now;
    _phases[0].endDate = preventaEnd;

    _phases[1].startDate = preventaEnd;
    _phases[1].endDate = generalEnd;

    _phases[2].startDate = generalEnd;
    _phases[2].endDate = eventEnd;
  }

  void _clampPhaseDatesToEvent() {
    for (final p in _phases) {
      if (p.endDate != null && p.endDate!.isAfter(widget.eventEndDate)) {
        p.endDate = widget.eventEndDate;
      }
      if (p.startDate != null &&
          p.endDate != null &&
          p.startDate!.isAfter(p.endDate!)) {
        p.startDate = p.endDate;
      }
    }
  }

  void _emitChanges() {
    final List<Map<String, dynamic>> result = [];

    if (!_usePhases) {
      final price = double.tryParse(_singlePriceCtrl.text.trim()) ?? 0.0;
      final stock = (!widget.isTheatreEvent && _isUnlimitedStock)
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
        'sales_end_at': widget.eventEndDate.toIso8601String(),
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
    final minDate = phase.startDate ?? DateTime.now();
    final maxDate = widget.eventEndDate;

    final safeInitial = (phase.endDate != null &&
            !phase.endDate!.isBefore(minDate) &&
            !phase.endDate!.isAfter(maxDate))
        ? phase.endDate!
        : maxDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: DateTime(minDate.year, minDate.month, minDate.day),
      lastDate: DateTime(maxDate.year, maxDate.month, maxDate.day),
    );

    if (picked != null) {
      setState(() {
        _userEditedPhaseDates = true;
        var chosenEnd = DateTime(picked.year, picked.month, picked.day, 23, 59);
        if (chosenEnd.isAfter(maxDate)) {
          chosenEnd = maxDate;
        }
        phase.endDate = chosenEnd;

        // Encadena las fases siguientes sin permitir incoherencias cronológicas
        for (int i = index + 1; i < _phases.length; i++) {
          _phases[i].startDate = _phases[i - 1].endDate;
          if (_phases[i].endDate != null &&
              _phases[i].endDate!.isBefore(_phases[i].startDate!)) {
            _phases[i].endDate = _phases[i].startDate;
          }
        }
      });
      _emitChanges();
    }
  }

  String? _validatePrice(String? v) {
    if (v == null || v.trim().isEmpty) return 'Obligatorio';
    final parsed = double.tryParse(v.trim());
    if (parsed == null) return 'Inválido';
    if (parsed < 0) return '≥ 0';
    if (parsed > 50000) return 'Máx 50.000';
    return null;
  }

  String? _validateStock(String? v) {
    if (v == null || v.trim().isEmpty) return 'Obligatorio';
    final parsed = int.tryParse(v.trim());
    if (parsed == null || parsed <= 0) return 'Mín 1';
    if (parsed > 100000) return 'Máx 100.000';
    return null;
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
                      widget.isTheatreEvent
                          ? 'Configura el precio por fase (el aforo lo define el teatro)'
                          : 'Habilitar 3 etapas: Preventa, Venta General y En Puerta',
                      style: TextStyle(color: context.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _usePhases,
                activeTrackColor: AppColors.primary,
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
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: TextStyle(color: context.textOnBg),
              decoration: const InputDecoration(
                labelText: 'Precio de la Entrada (BOB) *',
                hintText: '0 para entrada gratuita',
                prefixText: 'Bs. ',
              ),
              validator: _validatePrice,
              onChanged: (_) => _emitChanges(),
            ),
            if (!widget.isTheatreEvent) ...[
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
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(color: context.textOnBg),
                  decoration: const InputDecoration(
                    labelText: 'Stock total de entradas *',
                    hintText: 'Ej. 100',
                    suffixText: 'tickets',
                  ),
                  validator: _validateStock,
                  onChanged: (_) => _emitChanges(),
                ),
            ],
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _phases.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final p = _phases[index];
                final isLastPhase = index == _phases.length - 1;

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
                          SizedBox(
                            width: 135,
                            child: TextFormField(
                              controller: p.priceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}'),
                                ),
                              ],
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                color: context.textOnBg,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Precio *',
                                hintText: '0.00',
                                prefixText: 'Bs. ',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 8,
                                ),
                              ),
                              validator: _validatePrice,
                              onChanged: (_) => _emitChanges(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: isLastPhase
                                  ? null
                                  : () => _pickPhaseEndDate(index),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 2,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isLastPhase
                                          ? Icons.event_available
                                          : Icons.calendar_month_outlined,
                                      size: 16,
                                      color: isLastPhase
                                          ? context.textMuted
                                          : AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        isLastPhase
                                            ? 'Hasta el fin del evento'
                                            : (p.endDate != null
                                                ? 'Hasta: ${p.endDate!.day}/${p.endDate!.month}/${p.endDate!.year}'
                                                : 'Definir fin'),
                                        style: TextStyle(
                                          color: isLastPhase
                                              ? context.textMuted
                                              : context.textOnBg,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (!widget.isTheatreEvent) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 115,
                              child: TextFormField(
                                controller: p.stockController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  color: context.textMuted,
                                  fontSize: 12,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Cupos *',
                                  suffixText: 'tickets',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 6,
                                    horizontal: 8,
                                  ),
                                ),
                                validator: _validateStock,
                                onChanged: (_) => _emitChanges(),
                              ),
                            ),
                          ],
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