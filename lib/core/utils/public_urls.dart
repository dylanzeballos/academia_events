import '../../core/config/supabase_config.dart';

/// URL pública del logo de una organización.
///
/// El bucket `organization-logos` es público, así que alcanza con resolver la
/// ruta guardada en `organizations.logo_url`. Si ya viene como URL, se devuelve
/// tal cual.
String? organizationLogoUrl(String? path) {
  if (path == null) return null;
  final clean = path.trim();
  if (clean.isEmpty) return null;
  if (clean.startsWith('http://') || clean.startsWith('https://')) {
    return clean;
  }
  return supabase.storage.from('organization-logos').getPublicUrl(clean);
}
