import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBootstrap {
  SupabaseBootstrap._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static bool _initialized = false;

  static bool get isEnabled =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get isInitialized => _initialized;

  static Future<void> maybeInitialize() async {
    if (!isEnabled || _initialized) {
      return;
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );

    _initialized = true;
  }
}
