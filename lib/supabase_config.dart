// Both values are supplied at build/run time via --dart-define, never
// hardcoded here -- see dart_define.example.json for the expected keys and
// CLAUDE.md for the local run command. The GitHub Pages deploy workflow
// supplies them the same way, from repo secrets. main.dart checks
// SupabaseConfig.isConfigured before initializing Supabase, so a missing
// value fails with a clear message instead of a confusing runtime error.
class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  /// The deployed web app's URL -- used as the `redirectTo` target for
  /// password-reset emails (see ForgotPasswordPage). Must exactly match an
  /// entry in the Supabase Dashboard under Authentication -> URL
  /// Configuration -> Redirect URLs, or resetPasswordForEmail's link will
  /// fail to redirect back into the app. Not sensitive -- it's just this
  /// app's public URL -- so it's fine to keep hardcoded.
  static const siteUrl = 'https://pbocapiz.github.io/elssm/';
}
