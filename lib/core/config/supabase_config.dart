import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Instancia global del cliente Supabase para uso en los servicios.
SupabaseClient get supabase => Supabase.instance.client;

/// Inicializa Supabase una sola vez desde main().
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_PUBLIC_KEY']!,
  );
}
