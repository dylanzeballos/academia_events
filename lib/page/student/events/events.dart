import 'package:flutter/material.dart';

class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(title: const Text('Inicio')),
      body: const Center(
        child: Text(
          'Hola, soy la vista de Inicio / Dashboard',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),  
    );
  }
}