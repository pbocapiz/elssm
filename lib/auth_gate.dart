import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_page.dart';
import 'login_page.dart';
import 'reset_link_expired_page.dart';
import 'update_password_page.dart';

/// Shows [HomePage] when a Supabase session already exists (including one
/// restored from local storage after a refresh) and [LoginPage] otherwise,
/// reacting live to sign-in/sign-out events.
///
/// Also owns the password-reset landing flow: this app has no URL-path
/// router, so instead of a distinct `/update-password` route, AuthGate
/// watches for the PASSWORD_RECOVERY auth event (fired by supabase_flutter
/// itself once it detects a recovery session in the redirect URL on web)
/// and swaps in [UpdatePasswordPage] in place of Login/Home. A link that's
/// expired or already used never creates a session, so it never fires that
/// event -- that case is instead detected once at startup from the
/// `error`/`error_code` query params Supabase appends to the redirect URL.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _authSubscription;
  bool _showingPasswordRecovery = false;
  bool _passwordJustUpdated = false;
  String? _linkErrorCode;

  @override
  void initState() {
    super.initState();
    _linkErrorCode = _readLinkErrorFromUrl();

    final auth = Supabase.instance.client.auth;
    _authSubscription = auth.onAuthStateChange.listen((state) {
      if (!mounted) return;
      if (state.event == AuthChangeEvent.passwordRecovery) {
        setState(() {
          _showingPasswordRecovery = true;
          _linkErrorCode = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  /// Reads the `error`/`error_code` query params Supabase appends to the
  /// redirect URL for an expired or already-used recovery link (this is
  /// reading the *error* shape of the redirect, not a session -- the
  /// session itself is still handled entirely by supabase_flutter, per the
  /// no-manual-token-parsing rule). Web only: on other platforms there's no
  /// browser address bar for Supabase to append these to.
  String? _readLinkErrorFromUrl() {
    if (!kIsWeb) return null;
    final params = Uri.base.queryParameters;
    return params['error_code'] ?? params['error'];
  }

  void _handlePasswordUpdated() {
    setState(() {
      _showingPasswordRecovery = false;
      _passwordJustUpdated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_linkErrorCode != null) {
      return ResetLinkExpiredPage(
        onRequestNewLink: () => setState(() => _linkErrorCode = null),
      );
    }

    if (_showingPasswordRecovery) {
      return UpdatePasswordPage(onDone: _handlePasswordUpdated);
    }

    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        auth.currentSession,
      ),
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? auth.currentSession;
        if (session != null) return const HomePage();

        // Consume the "password updated" flag once: capture it for this
        // build, then reset it so the message doesn't reappear on a later,
        // unrelated rebuild of LoginPage.
        final showPasswordUpdatedMessage = _passwordJustUpdated;
        if (showPasswordUpdatedMessage) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _passwordJustUpdated = false);
          });
        }
        return LoginPage(
          showPasswordUpdatedMessage: showPasswordUpdatedMessage,
        );
      },
    );
  }
}
