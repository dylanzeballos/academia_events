// lib/features/tickets/views/student_tickets_view.dart
import 'package:flutter/material.dart';

import '../../../core/utils/theme_extensions.dart';
import 'event_tickets_tab.dart';

/// Tickets de **eventos** del alumno.
///
/// Las entradas de clases ya no viven acá: se muestran en "Mis clases", en el
/// horario semanal (modal con el QR de la próxima sesión).
class StudentTicketsView extends StatelessWidget {
  const StudentTicketsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.cardBg,
        elevation: 0,
        title: Text(
          'Mis tickets',
          style: TextStyle(
            color: context.textOnBg,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: const SafeArea(child: EventTicketsTab()),
    );
  }
}
