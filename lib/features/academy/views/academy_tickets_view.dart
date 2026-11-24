// lib/features/academy/views/academy_tickets_view.dart
import 'package:flutter/material.dart';

import '../../../core/utils/theme_extensions.dart';

class AcademyTicketsView extends StatelessWidget {
  const AcademyTicketsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.cardBg,
        elevation: 0,
        title: Text(
          'Tickets',
          style: TextStyle(color: context.textOnBg, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.confirmation_number_outlined, size: 64, color: context.textMuted),
            const SizedBox(height: 16),
            Text(
              'Gestión de Tickets',
              style: TextStyle(color: context.textOnBg, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Próximamente podrás gestionar\nventas de tickets para eventos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}