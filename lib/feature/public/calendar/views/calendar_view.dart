import 'package:flutter/material.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';

class CalendarView extends StatelessWidget {
  const CalendarView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const Text('Horario / Calendario'),
        backgroundColor: context.scaffoldBg,
      ),
      body: Center(
        child: Text('Vista de Calendario', style: TextStyle(color: context.textOnBg)),
      ),
    );
  }
}