import 'package:flutter/material.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';

class TicketsView extends StatelessWidget {
  const TicketsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const Text('Mis Tickets'),
        backgroundColor: context.scaffoldBg,
      ),
      body: Center(
        child: Text('Vista de Tickets', style: TextStyle(color: context.textOnBg)),
      ),
    );
  }
}