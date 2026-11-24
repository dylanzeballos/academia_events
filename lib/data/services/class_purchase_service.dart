import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

class ClassPurchaseException implements Exception {
  const ClassPurchaseException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Cotizaciones y configuración de pases de clase (sesiones, mensual y VIP).
///
/// Toda la validación de precios/cupos vive en RPCs de Postgres; este servicio
/// solo las invoca.
class ClassPurchaseService {
  const ClassPurchaseService();

  Future<List<Map<String, dynamic>>> listClassPurchaseSessions(
    String classId, {
    int? limit,
    int offset = 0,
    int? weeks,
  }) async {
    try {
      final result = await supabase.rpc(
        'list_class_purchase_sessions',
        params: {
          'p_class_id': classId,
          'p_limit': limit,
          'p_offset': offset,
          'p_weeks': weeks,
        },
      );
      return (result as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw ClassPurchaseException(_friendlyError(e.message));
    }
  }

  Future<Map<String, dynamic>> quoteClassSessions(
    String enrollmentId,
    List<String> sessionIds,
  ) async {
    try {
      final result = await supabase.rpc(
        'quote_class_sessions',
        params: {'p_enrollment_id': enrollmentId, 'p_session_ids': sessionIds},
      );
      return Map<String, dynamic>.from(result as Map);
    } on PostgrestException catch (e) {
      throw ClassPurchaseException(_friendlyError(e.message));
    }
  }

  Future<Map<String, dynamic>> quoteClassMonthly(String enrollmentId) async {
    try {
      final result = await supabase.rpc(
        'quote_class_monthly',
        params: {'p_enrollment_id': enrollmentId},
      );
      return Map<String, dynamic>.from(result as Map);
    } on PostgrestException catch (e) {
      throw ClassPurchaseException(_friendlyError(e.message));
    }
  }

  Future<Map<String, dynamic>> quoteVipMembership(String organizationId) async {
    try {
      final result = await supabase.rpc(
        'quote_vip_membership',
        params: {'p_organization_id': organizationId},
      );
      return Map<String, dynamic>.from(result as Map);
    } on PostgrestException catch (e) {
      throw ClassPurchaseException(_friendlyError(e.message));
    }
  }

  Future<List<Map<String, dynamic>>> fetchMyVipMemberships() async {
    try {
      final result = await supabase.rpc('fetch_my_vip_memberships');
      return (result as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw ClassPurchaseException(_friendlyError(e.message));
    }
  }

  /// Configuración del plan VIP (lectura pública).
  Future<Map<String, dynamic>?> fetchVipPlan(String organizationId) async {
    try {
      final row = await supabase
          .from('organization_vip_plans')
          .select('''
            id, organization_id, name, description, price_monthly, currency,
            includes_all_classes, is_active,
            organization_vip_plan_categories(dance_category_id)
          ''')
          .eq('organization_id', organizationId)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    } on PostgrestException catch (e) {
      throw ClassPurchaseException(_friendlyError(e.message));
    }
  }

  /// Crea o actualiza el plan VIP (solo owner/admin/manager de la org).
  Future<String> saveVipPlan({
    required String organizationId,
    required String name,
    String? description,
    required double priceMonthly,
    required bool includesAllClasses,
    required List<String> categoryIds,
    bool isActive = true,
  }) async {
    try {
      final row = await supabase
          .from('organization_vip_plans')
          .upsert({
            'organization_id': organizationId,
            'name': name.trim().isEmpty ? 'Pase VIP' : name.trim(),
            'description': description?.trim().isEmpty == true
                ? null
                : description?.trim(),
            'price_monthly': priceMonthly,
            'includes_all_classes': includesAllClasses,
            'is_active': isActive,
          }, onConflict: 'organization_id')
          .select('id')
          .single();
      final planId = row['id'] as String;

      await supabase
          .from('organization_vip_plan_categories')
          .delete()
          .eq('plan_id', planId);

      if (!includesAllClasses && categoryIds.isNotEmpty) {
        await supabase.from('organization_vip_plan_categories').insert([
          for (final categoryId in categoryIds)
            {'plan_id': planId, 'dance_category_id': categoryId},
        ]);
      }
      return planId;
    } on PostgrestException catch (e) {
      throw ClassPurchaseException(_friendlyError(e.message));
    }
  }

  String _friendlyError(String message) {
    final msg = message.toLowerCase();
    if (msg.contains('membresía') || msg.contains('membresia')) {
      return 'Se requiere una membresía activa para publicar.';
    }
    if (msg.contains('pago de publicación')) {
      return 'Se requiere el pago de publicación para publicar.';
    }
    if (msg.contains('permiso') || msg.contains('permission')) {
      return 'No tienes permiso para realizar esta acción.';
    }
    if (msg.contains('no ofrece') || msg.contains('no tiene precio')) {
      return message;
    }
    debugPrint('ClassPurchaseService error: $message');
    return 'No se pudo completar la operación. Intenta de nuevo.';
  }
}
