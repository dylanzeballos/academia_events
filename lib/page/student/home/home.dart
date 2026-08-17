import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Día seleccionado actualmente (por defecto Lunes)
  String diaSeleccionado = 'Lunes';

  final List<String> diasSemana = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado'
  ];

  // Datos simulados de clases/horarios
  final List<Map<String, String>> horariosClases = [
    {
      'hora': '18:00 - 19:30',
      'clase': 'Salsa Casino (Nivel Básico)',
      'instructor': 'Profe Carlos',
      'academia': 'Ritmo & Sabor',
      'nivel': 'Principiante',
    },
    {
      'hora': '19:30 - 21:00',
      'clase': 'Bachata Sensual',
      'instructor': 'Profe María',
      'academia': 'Ritmo & Sabor',
      'nivel': 'Intermedio',
    },
    {
      'hora': '21:00 - 22:30',
      'clase': 'Kizomba & Style',
      'instructor': 'Profe Andrés',
      'academia': 'Dance Studio',
      'nivel': 'Avanzado',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Horario de Clases',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- SECTOR DE FILTRO POR DÍAS DE LA SEMANA ---
          Container(
            color: Colors.indigo,
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: diasSemana.length,
              itemBuilder: (context, index) {
                final dia = diasSemana[index];
                final esSeleccionado = dia == diaSeleccionado;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      diaSeleccionado = dia;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: esSeleccionado ? Colors.white : Colors.indigo[400],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      dia,
                      style: TextStyle(
                        color:
                            esSeleccionado ? Colors.indigo : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // --- TÍTULO SECCIÓN ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Clases para el $diaSeleccionado',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '${horariosClases.length} disponibles',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),

          // --- LISTA DE HORARIOS Y CLASES ---
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: horariosClases.length,
              itemBuilder: (context, index) {
                final clase = horariosClases[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Columna izquierda: Hora
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.access_time,
                                  color: Colors.indigo, size: 20),
                              const SizedBox(height: 4),
                              Text(
                                clase['hora']!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Columna derecha: Detalles de la clase
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                clase['clase']!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${clase['academia']} • ${clase['instructor']}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.amber[100],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  clase['nivel']!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}