import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/fcm_token_model.dart';

class FcmTokenRepository {
  final SupabaseClient _supabase;

  FcmTokenRepository(this._supabase);

  Future<void> upsertToken(UserFcmTokenModel tokenModel) async {
    await _supabase.from('user_fcm_tokens').upsert(
      tokenModel.toJson(),
      onConflict: 'fcm_token',
    );
  }

  Future<void> deleteToken(String fcmToken) async {
    await _supabase
        .from('user_fcm_tokens')
        .delete()
        .eq('fcm_token', fcmToken);
  }
}