import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/theme_extensions.dart';
import '../../../shared/widgets/loading_indicator.dart';

// Provider temporal de inscripciones/tickets de clases
final studentClassTicketsProvider = FutureProvider<List<dynamic>>((ref) async {
  // TODO: Conectar con ticketsRepository.fetchUserClassTickets()
  return [];
});

class ClassTicketsTab extends ConsumerWidget {
  const ClassTicketsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(studentClassTicketsProvider);

    return ticketsAsync.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tickets) {
        if (tickets.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.collections_bookmark_outlined,
                  size: 64,
                  color: Colors.grey[600],
                ),
                const SizedBox(height: 16),
                Text(
                  'Sin inscripciones a clases',
                  style: TextStyle(
                    color: context.textOnBg,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Inscríbete a tus clases preferidas para verlas aquí.',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(studentClassTicketsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tickets.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final classTicket = tickets[index];
              return Card(
                color: context.cardBg,
                child: ListTile(
                  title: Text('Inscripción #${classTicket.id}'),
                  subtitle: const Text('Pase de clase activo'),
                  trailing: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                  onTap: () {
                    // TODO: Mostrar Detalle de la Inscripción a Clase
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}