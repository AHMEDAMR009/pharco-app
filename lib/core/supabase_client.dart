import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase project credentials.
///
/// Pass these at build/run time so they never get committed hard-coded:
///   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=xxxx \
///               --dart-define=GOOGLE_MAPS_API_KEY=xxxx
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
}

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
}

SupabaseClient get supabase => Supabase.instance.client;
