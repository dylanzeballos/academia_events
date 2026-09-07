import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/ticket_type_model.dart';
import '../../../providers/ticket_provider.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el nombre para cada una de las entradas')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo completar la compra: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBuying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticketTypesAsync = ref.watch(eventTicketTypesProvider(widget.eventId));

    return Scaffold(
      appBar: AppBar(title: const Text('Comprar entradas')),
      body: ticketTypesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No se pudieron cargar los precios: $e')),
        data: (types) {
          if (types.isEmpty) {
            return const Center(child: Text('Este evento no tiene tickets a la venta'));
          }
          _selected ??= types.first;

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Tipo de entrada', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...types.map((type) => RadioListTile<TicketTypeModel>(
                        value: type,
                        groupValue: _selected,
                        onChanged: type.hasStock
                            ? (value) => setState(() {
                                  _selected = value;
                                  _onQuantityChanged(1);
                                })
                            : null,
                        title: Text(type.name),
                        subtitle: Text(
                          type.hasStock
                              ? '${type.price.toStringAsFixed(2)} ${type.currency} · ${type.available} disponibles'
                              : 'Agotado',
                        ),
                      )),
                  const Divider(height: 32),
                  const Text('Cantidad', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _quantity > 1 ? () => _onQuantityChanged(_quantity - 1) : null,
                      ),
                      Text('$_quantity', style: Theme.of(context).textTheme.headlineSmall),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: (_selected?.hasStock ?? false) &&
                                _quantity < (_selected?.available ?? 0)
                            ? () => _onQuantityChanged(_quantity + 1)
                            : null,
                      ),
                    ],
                  ),
                  const Divider(height: 32),
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
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: _nameControllers[index],
                        decoration: InputDecoration(
                          labelText: 'Asistente #${index + 1}',
                          hintText: 'Ej. Carlos Mendoza',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(
                        '${_total.toStringAsFixed(2)} ${_selected?.currency ?? ''}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: (_selected?.hasStock ?? false) && !_isBuying ? _confirmPurchase : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isBuying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Confirmar compra', style: TextStyle(fontSize: 16)),
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