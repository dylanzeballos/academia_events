import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'class_pass_model.dart';

/// Tipo de acceso que el alumno tiene para una clase.
///
/// Sale de sus pases (`class_passes.pass_type`) y de las membresías VIP activas
/// de la organización.
enum ClassAccessKind { vip, monthly, sessions, none }

class ClassAccess {
  const ClassAccess({required this.kind, this.sessions = 0});

  final ClassAccessKind kind;
  final int sessions;

  String get label => switch (kind) {
    ClassAccessKind.vip => 'VIP',
    ClassAccessKind.monthly => 'Mensual',
    ClassAccessKind.sessions =>
      sessions <= 1 ? '1 sesión' : '$sessions sesiones',
    ClassAccessKind.none => 'Sin pase',
  };

  IconData get icon => switch (kind) {
    ClassAccessKind.vip => Icons.workspace_premium_rounded,
    ClassAccessKind.monthly => Icons.calendar_month_rounded,
    ClassAccessKind.sessions => Icons.confirmation_number_rounded,
    ClassAccessKind.none => Icons.lock_outline_rounded,
  };

  Color get color => switch (kind) {
    ClassAccessKind.vip => AppColors.warning,
    ClassAccessKind.monthly => AppColors.primary,
    ClassAccessKind.sessions => AppColors.success,
    ClassAccessKind.none => AppColors.error,
  };

  /// Resuelve el mejor acceso para una clase:
  /// VIP > mensual > pase con más sesiones > sin pase.
  static ClassAccess resolve({
    required String classId,
    required String? organizationId,
    required List<ClassPassModel> passes,
    Set<String> vipOrganizationIds = const {},
  }) {
    final classPasses = passes
        .where((p) => p.classId == classId && p.isActive)
        .toList();

    if (classPasses.any((p) => p.isVip) ||
        (organizationId != null &&
            vipOrganizationIds.contains(organizationId))) {
      return const ClassAccess(kind: ClassAccessKind.vip);
    }

    if (classPasses.any((p) => p.isMonthly)) {
      return const ClassAccess(kind: ClassAccessKind.monthly);
    }

    final withSessions = classPasses.where((p) => p.sessionCount > 0).toList();
    if (withSessions.isNotEmpty) {
      final best = withSessions.reduce(
        (a, b) => a.sessionCount >= b.sessionCount ? a : b,
      );
      return ClassAccess(
        kind: ClassAccessKind.sessions,
        sessions: best.sessionCount,
      );
    }

    return const ClassAccess(kind: ClassAccessKind.none);
  }
}
