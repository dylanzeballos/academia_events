import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import 'class_tickets_tab.dart';
import 'event_tickets_tab.dart';

class StudentTicketsView extends ConsumerWidget {
  const StudentTicketsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis Tickets'),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            tabs: [
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
        body: const TabBarView(
          children: [
            EventTicketsTab(),
            ClassTicketsTab(),
          ],
        ),
      ),
    );
  }
}