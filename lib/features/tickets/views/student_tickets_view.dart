// lib/features/tickets/views/student_tickets_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import 'class_tickets_tab.dart';
import 'event_tickets_tab.dart';

class StudentTicketsView extends ConsumerWidget {
  const StudentTicketsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        appBar: AppBar(
          backgroundColor: context.cardBg,
          elevation: 0,
          title: Text(
            'Mis Tickets',
            style: TextStyle(color: context.textOnBg, fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: context.textMuted,
            tabs: const [
              Tab(
                icon: Icon(Icons.event_outlined),
                text: 'Eventos',
              ),
              Tab(
                icon: Icon(Icons.school_outlined),
                text: 'Clases',
              ),
            ],
          ),
        ),
        body: const SafeArea(
          child: TabBarView(
            children: [
              EventTicketsTab(),
              ClassTicketsTab(),
            ],
          ),
        ),
      ),
    );
  }
}