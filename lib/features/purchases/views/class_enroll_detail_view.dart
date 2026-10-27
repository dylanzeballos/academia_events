// lib/features/purchases/views/class_enroll_detail_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../providers/dance_class_provider.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import 'tabs/regular_pack_tab.dart';
import 'tabs/vip_membership_tab.dart';

class ClassEnrollDetailView extends ConsumerStatefulWidget {
  const ClassEnrollDetailView({super.key, this.classId});

  final String? classId;

  @override
  ConsumerState<ClassEnrollDetailView> createState() => _ClassEnrollDetailViewState();
}

class _ClassEnrollDetailViewState extends ConsumerState<ClassEnrollDetailView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(orgClassesProvider);

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
          'Inscripciones',
          style: TextStyle(color: context.textOnBg, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: context.textMuted,
          tabs: const [
            Tab(text: 'POR SESIONES'),
            Tab(text: 'PASE VIP ILIMITADO'),
          ],
        ),
      ),
      body: classesAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(
          child: Text('Error: $e', style: TextStyle(color: context.textMuted)),
        ),
        data: (classes) {
          if (classes.isEmpty) {
            return Center(
              child: Text(
                'No hay clases disponibles para inscribirse.',
                style: TextStyle(color: context.textMuted),
              ),
            );
          }

          return TabBarView(
            controller: _tabCtrl,
            children: [
              RegularPackTab(classes: classes, initialClassId: widget.classId),
              const VipMembershipTab(),
            ],
          );
        },
      ),
    );
  }
}