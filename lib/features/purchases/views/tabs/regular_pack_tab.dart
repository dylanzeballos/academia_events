// lib/features/purchases/views/tabs/regular_pack_tab.dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../widget/pack_card.dart';
import '../../widget/summary_row.dart';
import '../qr_payment_view.dart';

class RegularPackTab extends StatefulWidget {
  const RegularPackTab({
    super.key,
    required this.classes,
    required this.initialClassId,
  });

  final List<dynamic> classes;
  final String? initialClassId;

  @override
  State<RegularPackTab> createState() => _RegularPackTabState();
}

class _RegularPackTabState extends State<RegularPackTab> {
  late String _selectedClassId;
  int _selectedPackSessions = 12;

  @override
  void initState() {
    super.initState();
    // Validar si el classId existe en la lista recibida
    dynamic matched;
    for (final c in widget.classes) {
      if (c.id == widget.initialClassId) {
        matched = c;
        break;
      }
    }
    _selectedClassId = matched != null ? matched.id as String : (widget.classes.first.id as String);
  }

  @override
  Widget build(BuildContext context) {
    // Búsqueda segura sin conflicto de tipos en orElse
    dynamic currentClass;
    for (final c in widget.classes) {
      if (c.id == _selectedClassId) {
        currentClass = c;
        break;
      }
    }
    currentClass ??= widget.classes.first;

    final double basePrice = (currentClass.price as num).toDouble();
    final double finalPrice = _selectedPackSessions == 8
        ? (basePrice * 0.8)
        : basePrice;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1. Selecciona tu Clase',
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              border: Border.all(color: context.divider),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedClassId,
                isExpanded: true,
                dropdownColor: context.cardBg,
                style: TextStyle(color: context.textOnBg, fontSize: 14),
                items: widget.classes.map<DropdownMenuItem<String>>((c) {
                  final priceNum = (c.price as num).toInt();
                  return DropdownMenuItem<String>(
                    value: c.id as String,
                    child: Text('${c.title} ($priceNum BOB)'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedClassId = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            '2. Paquete de Sesiones',
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: PackCard(
                  title: '8 Clases',
                  subtitle: '2 veces por semana',
                  price: (basePrice * 0.8).toInt(),
                  isSelected: _selectedPackSessions == 8,
                  onTap: () => setState(() => _selectedPackSessions = 8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PackCard(
                  title: '12 Clases',
                  subtitle: '3 veces por semana',
                  price: basePrice.toInt(),
                  isSelected: _selectedPackSessions == 12,
                  onTap: () => setState(() => _selectedPackSessions = 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Card(
            color: context.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              side: BorderSide(color: context.divider),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SummaryRow(label: 'Clase', value: currentClass.title as String),
                  SummaryRow(label: 'Sesiones', value: '$_selectedPackSessions clases'),
                  SummaryRow(label: 'Vigencia', value: '30 días'),
                  const Divider(height: 20),
                  SummaryRow(label: 'Total', value: '${finalPrice.toInt()} BOB', isBold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          AppButton(
            label: 'Generar QR de Pago',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QrPaymentView(
                    title: currentClass.title as String,
                    details: 'Paquete regular de $_selectedPackSessions sesiones',
                    amount: finalPrice,
                    isVip: false,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}