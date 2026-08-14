// The anon key is safe to embed in client code — it identifies the project
// and is constrained by Row Level Security, not a secret credential.
class SupabaseConfig {
  static const url = 'https://yytmagjuxqsecdsjjxls.supabase.co';
  static const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl5dG1hZ2p1eHFzZWNkc2pqeGxzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUyMTU2MTQsImV4cCI6MjEwMDc5MTYxNH0.LBw5YlxUg4PguWf5oaLFwWiHfhk5JUp8v6XvdiKYHm4';

  /// The deployed web app's URL -- used as the `redirectTo` target for
  /// password-reset emails (see ForgotPasswordPage). Must exactly match an
  /// entry in the Supabase Dashboard under Authentication -> URL
  /// Configuration -> Redirect URLs, or resetPasswordForEmail's link will
  /// fail to redirect back into the app.
  static const siteUrl = 'https://pbocapiz.github.io/elssm/';
}
