import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase project credentials, loaded from the untracked `.env` file at
/// the project root (see `.env.example`). Call `dotenv.load()` in `main()`
/// before reading these.
class SupabaseConfig {
  SupabaseConfig._();

  static String get url => dotenv.env['SUPABASE_URL'] ?? '';

  static String get anonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
}
