// lib/feature/public/tickets/views/purchase_tickets_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:academia_events/core/theme/app_colors.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';
import 'package:academia_events/data/models/ticket_type_model.dart';
import 'package:academia_events/providers/ticket_provider.dart';
import 'package:academia_events/shared/widgets/app_feedback.dart';
import 'ticket_qr_screen.dart';

class PurchaseTicketsScreen extends ConsumerStatefulWidget {
  const PurchaseTicketsScreen({super.key, required this.eventId});
  final String eventId;

  @override
  ConsumerState<PurchaseTicketsScreen> createState() => _PurchaseTicketsScreenState();
}

class _PurchaseTicketsScreenState extends ConsumerState<PurchaseTicketsScreen> {
  final _formKey = GlobalKey<FormState>();
  TicketTypeModel? _selected;
  int _quantity = 1;
  bool _isBuying = false;

  final List<TextEditingController> _nameControllers = [];

  @override
  void initState() {
    super.initState();
    _syncNameControllers(1);
  }

  @override
  void dispose() {
    for (final c in _nameControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncNameControllers(int targetCount) {
    while (_nameControllers.length < targetCount) {
      _nameControllers.add(TextEditingController());
    }
    while (_nameControllers.length > targetCount) {
      _nameControllers.removeLast().dispose();
    }
  }

  void _onQuantityChanged(int newQuantity) {
    setState(() {
      _quantity = newQuantity;
      _syncNameControllers(newQuantity);
    });
  }

  double get _total => (_selected?.price ?? 0) * _quantity;

  Future<void> _confirmPurchase() async {
    final selected = _selected;
    if (selected == null) return;

    if (!_formKey.currentState!.validate()) {
      AppFeedback.error(
        context,
        'Ingresa el nombre para cada una de las entradas.',
      );
      return;
    }

    final attendeeNames = _nameControllers.map((c) => c.text.trim()).toList();

    setState(() => _isBuying = true);
    try {
      final repo = ref.read(ticketRepositoryProvider);
      final result = await repo.purchaseEventTickets(
        ticketTypeId: selected.id,
        quantity: _quantity,
        attendeeNames: attendeeNames,
      );
      if (!mounted) return;
      ref.invalidate(eventTicketTypesProvider(widget.eventId));
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => TicketQrScreen(result: result)),
      );
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _isBuying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticketTypesAsync = ref.watch(eventTicketTypesProvider(widget.eventId));

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const Text('Comprar entradas'),
        backgroundColor: context.scaffoldBg,
      ),
      body: ticketTypesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Text(
            'No se pudieron cargar los precios: $e',
            style: TextStyle(color: context.textMuted),
          ),
        ),
        data: (types) {
          if (types.isEmpty) {
            return Center(
              child: Text(
                'Este evento no tiene tickets a la venta',
                style: TextStyle(color: context.textMuted),
              ),
            );
          }
          _selected ??= types.first;

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tipo de entrada',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Card(
                    color: context.cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: context.divider),
                    ),
                    child: Column(
                      children: [
                        for (final type in types)
                          RadioListTile<TicketTypeModel>(
                            value: type,
                            groupValue: _selected,
                            activeColor: AppColors.primary,
                            enabled: type.hasStock,
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selected = value;
                                _onQuantityChanged(1);
                              });
                            },
                            title: Text(
                              type.name,
                              style: TextStyle(
                                color: context.textOnBg,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              type.hasStock
                                  ? '${type.price.toStringAsFixed(2)} ${type.currency} · ${type.available} disponibles'
                                  : 'Agotado',
                              style: TextStyle(
                                color: type.hasStock ? context.textMuted : AppColors.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  Divider(height: 32, color: context.divider),
                  Text(
                    'Cantidad',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        color: AppColors.primary,
                        onPressed: _quantity > 1 ? () => _onQuantityChanged(_quantity - 1) : null,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$_quantity',
                        style: TextStyle(
                          color: context.textOnBg,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        color: AppColors.primary,
                        onPressed: (_selected?.hasStock ?? false) &&
                                _quantity < (_selected?.available ?? 0)
                            ? () => _onQuantityChanged(_quantity + 1)
                            : null,
                      ),
                    ],
                  ),

                  Divider(height: 32, color: context.divider),
                  Text(
                    'Titulares de las entradas',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ingresa el nombre y apellido de quien portará cada boleto:',
                    style: TextStyle(color: context.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(_quantity, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: _nameControllers[index],
                        style: TextStyle(color: context.textOnBg),
                        decoration: InputDecoration(
                          labelText: 'Asistente #${index + 1}',
                          labelStyle: TextStyle(color: context.textMuted),
                          hintText: 'Ej. Carlos Mendoza',
                          prefixIcon: const Icon(Icons.person_outline),
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Escribe el nombre del asistente #${index + 1}';
                          }
                          return null;
                        },
                      ),
                    );
                  }),

                  Divider(height: 32, color: context.divider),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          color: context.textOnBg,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_total.toStringAsFixed(2)} ${_selected?.currency ?? ''}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: (_selected?.hasStock ?? false) && !_isBuying ? _confirmPurchase : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isBuying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Confirmar compra',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}