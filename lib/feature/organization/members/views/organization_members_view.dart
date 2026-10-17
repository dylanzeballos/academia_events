import 'package:flutter/material.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';

class OrganizationMembersView extends StatelessWidget {
  const OrganizationMembersView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const Text('Profesores / Miembros'),
        backgroundColor: context.scaffoldBg,
      ),
      body: Center(
        child: Text('Lista de Miembros', style: TextStyle(color: context.textOnBg)),
      ),
    );
  }
}