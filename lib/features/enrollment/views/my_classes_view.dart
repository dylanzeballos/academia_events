// lib/features/enrollment/views/my_classes_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/class_access.dart';
import '../../../providers/checkin_provider.dart';
import '../../../providers/class_enrollment_provider.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/schedule/schedule_grid_body.dart';
import '../../tickets/widgets/class_pass_purchase_sheet.dart';
import '../widgets/class_access_sheet.dart';
import 'explore_classes_view.dart';

/// "Mis clases" como horario semanal: solo las clases con un pase activo, con
/// una marca del tipo de acceso (VIP, mensual o pase de N sesiones) en cada
/// clase. Las clases anotadas sin pase o sin sesiones quedan en una sección
/// aparte para comprarlas o quitarlas del horario.
///
/// Al tocar una clase se abre el modal de acceso con el QR de la próxima
/// sesión (las entradas de clases ya no viven en la pestaña de tickets).
class MyClassesView extends ConsumerWidget {
  const MyClassesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(myClassesOverviewProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.cardBg,
        elevation: 0,
        title: Text(
          'Mis clases',
          style: TextStyle(
            color: context.textOnBg,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: Icon(Icons.refresh_rounded, color: context.textMuted),
            onPressed: () {
              ref.invalidate(myEnrollmentsProvider);
              ref.invalidate(myClassPassesProvider);
              ref.invalidate(myClassesOverviewProvider);
            },
          ),
        ],
      ),
      body: overviewAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => AppErrorState(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(myClassesOverviewProvider),
        ),
        data: (overview) {
          if (overview.isEmpty) {
            return _EmptyState(onExplore: () => _openExplore(context));
          }

          return SafeArea(
            top: false,
            child: Column(
              children: [
                if (overview.pending.isNotEmpty)
                  _PendingSection(
                    items: overview.pending,
                    onBuy: (item) => _openPurchase(context, ref, item),
                    onRemove: (item) => _remove(context, ref, item),
                  ),
                if (overview.entries.isNotEmpty)
                  Expanded(
                    child: ScheduleGridBody(
                      entries: overview.entries,
                      showOrganization: true,
                      accessFor: (classId) => overview.accessByClass[classId],
                      onOpenClass: (classId) {
                        final enrollmentId =
                            overview.enrollmentByClass[classId];
                        final danceClass = overview.entries
                            .where((e) => e.danceClass.id == classId)
                            .firstOrNull
                            ?.danceClass;
                        if (enrollmentId == null || danceClass == null) return;
                        ClassAccessSheet.show(
                          context,
                          danceClass: danceClass,
                          access:
                              overview.accessByClass[classId] ??
                              const ClassAccess(kind: ClassAccessKind.none),
                          enrollmentId: enrollmentId,
                        );
                      },
                    ),
                  )
                else
                  const Expanded(child: _PendingOnlyState()),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Explorar clases',
        onPressed: () => _openExplore(context),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.explore_outlined),
        label: const Text('Explorar'),
      ),
    );
  }

  void _openExplore(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ExploreClassesView()));
  }

  Future<void> _openPurchase(
    BuildContext context,
    WidgetRef ref,
    PendingMyClass item,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusLarge),
        ),
      ),
      builder: (_) => ClassPassPurchaseSheet(enrollment: item.enrollment),
    );
    _refresh(ref);
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    PendingMyClass item,
  ) async {
    final confirmed = await showAppConfirm(
      context,
      title: 'Quitar de mi horario',
      message:
          '¿Quitar "${item.danceClass.title}" de tu horario? '
          'Podés volver a anotarte cuando quieras.',
      confirmLabel: 'Quitar',
      isDangerous: true,
    );
    if (!confirmed || !context.mounted) return;

    final success = await ref
        .read(enrollmentActionProvider.notifier)
        .cancel(item.enrollment.id);
    if (!context.mounted) return;

    _refresh(ref);
    if (success) {
      AppFeedback.success(context, 'Clase quitada de tu horario.');
    } else {
      AppFeedback.error(
        context,
        ref.read(enrollmentActionProvider).error ??
            'No se pudo quitar la clase.',
      );
    }
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(myEnrollmentsProvider);
    ref.invalidate(myClassPassesProvider);
    ref.invalidate(myClassesOverviewProvider);
  }
}

class _PendingSection extends StatelessWidget {
  const _PendingSection({
    required this.items,
    required this.onBuy,
    required this.onRemove,
  });

  final List<PendingMyClass> items;
  final ValueChanged<PendingMyClass> onBuy;
  final ValueChanged<PendingMyClass> onRemove;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 230),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(color: context.divider),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.pending_actions_rounded,
                  size: 16,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 6),
                Text(
                  'Clases fuera de tu horario',
                  style: TextStyle(
                    color: context.textOnBg,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Compra un pase para verlas en el horario.',
              style: TextStyle(color: context.textMuted, fontSize: 11.5),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: items.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: context.divider.withValues(alpha: 0.6),
                ),
                itemBuilder: (_, index) {
                  final item = items[index];
                  return _PendingRow(
                    item: item,
                    onBuy: item.canBuy ? () => onBuy(item) : null,
                    onRemove: () => onRemove(item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({
    required this.item,
    required this.onBuy,
    required this.onRemove,
  });

  final PendingMyClass item;
  final VoidCallback? onBuy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                item.hasSessions
                    ? Icons.lock_outline_rounded
                    : Icons.event_busy,
                size: 18,
                color: item.hasSessions ? AppColors.warning : context.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.danceClass.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.textOnBg,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.reason,
                      style: TextStyle(
                        color: context.textMuted,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (onBuy != null)
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: onBuy,
                  child: const Text('Comprar pase'),
                ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: onRemove,
                icon: const Icon(Icons.remove_circle_outline, size: 15),
                label: const Text('Quitar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingOnlyState extends StatelessWidget {
  const _PendingOnlyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          'Tu horario se arma con las clases que tienen un pase activo. '
          'Compra el pase de una clase pendiente para verla acá.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.textMuted,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.school_rounded,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Todavía no tenés clases en tu horario',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textOnBg,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                'Explorá una academia, elegí tu clase y comprá un pase. '
                'Cuando el pago se confirme, la clase aparece en tu horario.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size(0, AppSizes.buttonHeight),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              onPressed: onExplore,
              icon: const Icon(Icons.explore_outlined, size: 18),
              label: const Text('Explorar clases'),
            ),
          ],
        ),
      ),
    );
  }
}
