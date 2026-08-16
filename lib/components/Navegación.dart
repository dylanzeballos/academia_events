import 'package:flutter/material.dart';
import '../page/Home.dart';
import '../page/Profile.dart';

class Navegacion extends StatefulWidget {
  const Navegacion({super.key});

  @override
  State<Navegacion> createState() => _NavegacionState();
}

class _NavegacionState extends State<Navegacion> {
  int _selectedIndex = 0;

  // Lista de pantallas asociadas a cada pestaña del menú
  final List<Widget> _pages = [
    const HomePage(), // Tu pantalla de horarios
    const Center(child: Text('Instructores', style: TextStyle(color: Colors.white))),
    const Center(child: Text('Mis Clases', style: TextStyle(color: Colors.white))),
    const ProfilePage(), // Tu pantalla de perfil
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A), // Fondo general oscuro
      body: _pages[_selectedIndex],
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20, top: 8),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B2F), // Fondo oscuro del contenedor flotante
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: Colors.transparent,
                indicatorColor: const Color(0xFFC000FF), // Color morado de la cápsula activa
                indicatorShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    );
                  }
                  return const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  );
                }),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const IconThemeData(color: Colors.white, size: 22);
                  }
                  return const IconThemeData(color: Colors.grey, size: 22);
                }),
              ),
              child: NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.calendar_month),
                    label: 'HORARIO',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.groups),
                    label: 'INSTRUCTORES',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.collections_bookmark),
                    label: 'MIS CLASES',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person),
                    label: 'PERFIL',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}