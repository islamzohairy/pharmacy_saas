import 'package:supabase_flutter/supabase_flutter.dart';

/// Build-time configuration injected via `--dart-define`.
///
/// No credentials are committed to the repository — these stay empty until
/// PLANS/03 provides real values. The anon key is public-by-design (RLS
/// protects the data); the service key must never be compiled into the app.
abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

/// Initializes the Supabase client when credentials are provided.
///
/// P0 ships with no backend flows — this is configuration wiring only.
/// No-op while `SUPABASE_URL`/`SUPABASE_ANON_KEY` are absent.
abstract final class SupabaseBootstrap {
  static Future<void> initializeIfConfigured() async {
    if (!AppConfig.isSupabaseConfigured) return;
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  }
}
