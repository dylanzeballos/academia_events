import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

/// Servicio de bajo nivel para Supabase Storage.
/// Solo sabe subir/firmar URLs, no tiene lógica de negocio.
class StorageService {
  const StorageService();

  static const _avatarBucket = 'profile-avatars';

  /// Sube [bytes] como avatar del usuario [userId].
  /// Devuelve el path relativo dentro del bucket.
  Future<String> uploadAvatar(
    String userId,
    Uint8List bytes, {
    required String extension,
  }) async {
    final cleanExt = extension.toLowerCase().replaceAll('.', '');
    final path = '$userId/avatar.$cleanExt';
    final contentType = cleanExt == 'png' ? 'image/png' : 'image/jpeg';

    try {
      await supabase.storage.from(_avatarBucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: contentType,
              cacheControl: '3600',
            ),
          );
    } on StorageException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('bucket') && msg.contains('not')) {
        throw const StorageException(
          'Bucket profile-avatars no encontrado. Ejecuta las migraciones.',
        );
      }
      if (msg.contains('permission') ||
          msg.contains('not allowed') ||
          msg.contains('row-level security')) {
        throw const StorageException(
          'Sin permisos para subir imagen. Revisa policies de storage.',
        );
      }
      rethrow;
    }

    return path;
  }

  /// Genera una URL firmada válida por 1 hora.
  /// Si [path] ya es una URL completa la devuelve tal cual.
  /// [bucket] permite especificar un bucket distinto al de avatars.
  Future<String?> signedUrl(String? path, {String? bucket}) async {
    if (path == null || path.trim().isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;

    return supabase.storage
        .from(bucket ?? _avatarBucket)
        .createSignedUrl(path, 60 * 60);
  }

  /// URL pública permanente para buckets públicos.
  String? publicUrl(String? path, {String? bucket}) {
    if (path == null || path.trim().isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;

    return supabase.storage.from(bucket ?? _avatarBucket).getPublicUrl(path);
  }

  /// Extrae el path de una URL firmada antigua guardada en BD.
  /// Ej: https://xxx.supabase.co/storage/v1/object/sign/bucket/a/b.jpg?token=...
  /// devuelve "a/b.jpg". Devuelve null si no es una URL firmada.
  static String? extractPathFromSignedUrl(String url) {
    final marker = '/object/sign/';
    final idx = url.indexOf(marker);
    if (idx == -1) return null;

    var rest = url.substring(idx + marker.length);
    final queryIdx = rest.indexOf('?');
    if (queryIdx != -1) rest = rest.substring(0, queryIdx);

    // Descartar el primer segmento (nombre del bucket).
    final segments = rest.split('/');
    if (segments.length < 2) return null;
    return segments.sublist(1).join('/');
  }
}
