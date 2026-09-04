import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';

class EventTicketsEditor extends StatelessWidget {
  const EventTicketsEditor({
    super.key,
    required this.priceController,
    required this.stockController,
    required this.isUnlimitedStock,
    required this.onUnlimitedStockChanged,
  });

  final TextEditingController priceController;
  final TextEditingController stockController;
  final bool isUnlimitedStock;
  final ValueChanged<bool> onUnlimitedStockChanged;

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
          const Text(
            'Entradas y Cupos',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Define el costo de la entrada y el límite de tickets disponibles.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 12),

          // Campo de Precio
          TextFormField(
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Precio de la Entrada (BOB) *',
              hintText: '0 para entrada gratuita',
              prefixText: 'Bs. ',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Ingresa el precio';
              if (double.tryParse(v.trim()) == null) return 'Ingresa un número válido';
              if (double.parse(v.trim()) < 0) return 'El precio no puede ser negativo';
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Switch de Cupos Ilimitados
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cupos ilimitados', style: TextStyle(fontSize: 14)),
            subtitle: const Text(
              'No habrá límite de compra para este evento',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            value: isUnlimitedStock,
            onChanged: onUnlimitedStockChanged,
          ),

          // Campo de Stock / Cupos (solo si no es ilimitado)
          if (!isUnlimitedStock) ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cantidad total de entradas (Stock) *',
                hintText: 'Ej. 100',
                suffixText: 'tickets',
              ),
              validator: (v) {
                if (isUnlimitedStock) return null;
                if (v == null || v.trim().isEmpty) return 'Ingresa la cantidad de tickets';
                final qty = int.tryParse(v.trim());
                if (qty == null || qty <= 0) return 'Debe ser un número mayor a 0';
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }
}