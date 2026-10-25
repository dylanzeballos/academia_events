import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/seat_model.dart';
import '../../../data/models/ticket_type_model.dart';
import '../../../data/services/events_service.dart';
import '../../../providers/events_provider.dart';
import '../../../providers/ticket_provider.dart';
import '../../../shared/widgets/app_feedback.dart';
import 'ticket_qr_screen.dart';

class PurchaseTicketsScreen extends ConsumerStatefulWidget {
  const PurchaseTicketsScreen({
    super.key,
    required this.eventId,
    this.preselectedSeats = const [],
  });

  final String eventId;
  final List<SeatModel> preselectedSeats;

  @override
  ConsumerState<PurchaseTicketsScreen> createState() =>
      _PurchaseTicketsScreenState();
}

class _PurchaseTicketsScreenState extends ConsumerState<PurchaseTicketsScreen> {
  final _formKey = GlobalKey<FormState>();
  TicketTypeModel? _selected;
  int _quantity = 1;
  bool _isBuying = false;

  final List<TextEditingController> _nameControllers = [];
  late List<SeatModel> _selectedSeats;

  @override
  void initState() {
    super.initState();
    _selectedSeats = List.from(widget.preselectedSeats);
    final initialQuantity = _selectedSeats.isNotEmpty
        ? _selectedSeats.length
        : 1;
    _quantity = initialQuantity;
    _syncNameControllers(initialQuantity);
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

  double get _total {
    if (_selectedSeats.isNotEmpty) {
      return _selectedSeats.fold<double>(0.0, (acc, s) => acc + s.price);
    }
    return (_selected?.price ?? 0) * _quantity;
  }

  Future<void> _confirmPurchase() async {
    final selected = _selected;
    if (selected == null) return;

    if (!_formKey.currentState!.validate()) {
      AppFeedback.warning(
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

      // Confirmar la compra definitiva de las butacas en la base de datos
      if (_selectedSeats.isNotEmpty) {
        final seatIds = _selectedSeats.map((s) => s.id).toList();
        await const EventsService().confirmSeatPurchase(
          orderId: result.orderId,
          seatIds: seatIds,
        );
      }

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
    final ticketTypesAsync = ref.watch(
      eventTicketTypesProvider(widget.eventId),
    );
    final bool hasTheatreSeats = _selectedSeats.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar compra')),
      body: ticketTypesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('No se pudieron cargar los precios: $e')),
        data: (types) {
          if (types.isEmpty) {
            return const Center(
              child: Text('Este evento no tiene tickets a la venta'),
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
                  // 1. Resumen de Butacas Reservadas (si viene del teatro)
                  if (hasTheatreSeats) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.event_seat,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Tus butacas seleccionadas',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _selectedSeats.map((s) {
                              return Chip(
                                label: Text(
                                  s.displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                backgroundColor: Colors.white,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 2. Tipo de Entrada
                  // 2. Tipo de Entrada
                  const Text(
                    'Tipo de entrada',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (hasTheatreSeats)
                    // Si ya seleccionó butacas, solo mostramos el tipo asignado sin radio interactivo
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.confirmation_number_outlined,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selected?.name ?? 'Entrada Butaca',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  '${_selected?.price.toStringAsFixed(2) ?? "0.00"} ${_selected?.currency ?? "BOB"} por butaca',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    // Para eventos generales sin butacas, se mantiene la lista de selección
                    Column(
                      children: [
                        for (final type in types)
                          RadioListTile<TicketTypeModel>(
                            value: type,
                            groupValue: _selected,
                            onChanged: type.hasStock
                                ? (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _selected = value;
                                      _onQuantityChanged(1);
                                    });
                                  }
                                : null,
                            title: Text(type.name),
                            subtitle: Text(
                              type.hasStock
                                  ? '${type.price.toStringAsFixed(2)} ${type.currency} · ${type.available} disponibles'
                                  : 'Agotado',
                            ),
                          ),
                      ],
                    ),
                  const Divider(height: 32),

                  // 4. Titulares de cada boleto
                  const Text(
                    'Titulares de las entradas',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ingresa el nombre y apellido de quien portará cada boleto:',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(_quantity, (index) {
                    final seatLabel =
                        hasTheatreSeats && _selectedSeats.length > index
                        ? ' [${_selectedSeats[index].displayName}]'
                        : '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: _nameControllers[index],
                        decoration: InputDecoration(
                          labelText: 'Asistente #${index + 1}$seatLabel',
                          hintText: 'Ej. Carlos Mendoza',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
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
                  const Divider(height: 32),

                  // 5. Total a pagar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_total.toStringAsFixed(2)} ${_selected?.currency ?? 'BOB'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed:
                        ((_selected?.hasStock ?? false) || hasTheatreSeats) &&
                            !_isBuying
                        ? _confirmPurchase
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isBuying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: AppColors.onPrimary,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Confirmar compra',
                            style: TextStyle(fontSize: 16),
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
