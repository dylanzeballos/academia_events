import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/supabase_config.dart';

/// `true` si la organización tiene una suscripción activa y vigente.
///
/// Usa una RPC `security definer` para que cualquier miembro de la
/// organización pueda consultarlo (no solo owner/admin).
final organizationMembershipProvider = FutureProvider.family<bool, String>((
  ref,
  organizationId,
) async {
  if (organizationId.isEmpty) return false;
  final result = await supabase.rpc(
    'organization_has_active_membership',
    params: {'p_organization_id': organizationId},
  );
  return result == true;
});
