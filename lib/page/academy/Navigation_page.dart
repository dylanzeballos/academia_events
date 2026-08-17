import 'package:flutter/material.dart';

// Importación de cada vista
import 'dashboard/dashboard_page.dart';
import 'classes/class_list_page.dart';
import 'teachers/teacher_list_page.dart';
import 'tickets/ticket_control_page.dart';
import 'events/social_list_page.dart';

class AcademyNavigationPage extends StatefulWidget {
  const AcademyNavigationPage({super.key});

  @override
  State<AcademyNavigationPage> createState() => _AcademyNavigationPageState();
}

class _AcademyNavigationPageState extends State<AcademyNavigationPage> {
  int _currentIndex = 0;

  // Lista de las 5 páginas vinculadas a cada icono
  final List<Widget> _pages = const [
    DashboardPage(),
    ClassListPage(),
    TeacherListPage(),
    TicketControlPage(),
    SocialListPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Clases',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Profesores',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.confirmation_number_outlined),
            activeIcon: Icon(Icons.confirmation_number),
            label: 'Tickets',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.nightlife_outlined),
            activeIcon: Icon(Icons.nightlife),
            label: 'Sociales',
          ),
        ],
      ),
    );
  }
}