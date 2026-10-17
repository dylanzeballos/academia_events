import 'package:flutter/material.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';

class StudentClassesView extends StatelessWidget {
  const StudentClassesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const Text('Mis Clases'),
        backgroundColor: context.scaffoldBg,
      ),
      body: Center(
        child: Text('Vista de Clases', style: TextStyle(color: context.textOnBg)),
      ),
    );
  }
}