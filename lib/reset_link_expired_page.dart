import 'package:flutter/material.dart';

import 'forgot_password_page.dart';
import 'theme.dart';
import 'widgets/auth_shell.dart';

/// Shown by AuthGate instead of Login/Home when the initial URL carries an
/// `error`/`error_code` param -- i.e. the user followed a password-reset
/// link that Supabase rejected (expired, or already used) before any
/// session could be created, so no PASSWORD_RECOVERY event ever fires.
class ResetLinkExpiredPage extends StatelessWidget {
  const ResetLinkExpiredPage({super.key, required this.onRequestNewLink});

  /// Called once the user taps through to request a fresh reset link, so
  /// AuthGate can clear the error and stop showing this page.
  final VoidCallback onRequestNewLink;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF0F4),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          child: AuthCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AuthHeader(subtitle: 'RESET LINK PROBLEM'),
                const SizedBox(height: 24),
                const AuthDivider('LINK EXPIRED'),
                const SizedBox(height: 24),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withValues(alpha: 0.1),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    size: 30,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'This link has expired. Password reset links are only '
                  'valid for a short time and can only be used once.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: navyBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      onRequestNewLink();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordPage(),
                        ),
                      );
                    },
                    child: const Text(
                      'Request a New Link',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
