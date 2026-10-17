import 'package:flutter/material.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';

class OrganizationClassesView extends StatelessWidget {
  const OrganizationClassesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const Text('Gestión de Clases'),
        backgroundColor: context.scaffoldBg,
      ),
      body: Center(
        child: Text('Gestión de Clases de la Academia', style: TextStyle(color: context.textOnBg)),
      ),
    );
  }
}