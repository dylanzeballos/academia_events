// lib/features/academy/views/academy_teachers_view.dart
import 'package:flutter/material.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../organization/views/organization_members_view.dart';

class AcademyTeachersView extends StatelessWidget {
  const AcademyTeachersView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textOnBg, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Equipo y Profesores',
          style: TextStyle(
            color: context.textOnBg,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: const OrganizationMembersView(),
    );
  }
}