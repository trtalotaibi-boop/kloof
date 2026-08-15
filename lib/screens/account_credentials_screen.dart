import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kloof/l10n/app_localizations.dart';

class AccountCredentialsScreen extends StatefulWidget {
  const AccountCredentialsScreen({super.key});

  @override
  State<AccountCredentialsScreen> createState() =>
      _AccountCredentialsScreenState();
}

class _AccountCredentialsScreenState extends State<AccountCredentialsScreen> {
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = FirebaseAuth.instance.currentUser?.email ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _localizedAuthError(
    FirebaseAuthException error,
    AppLocalizations l10n,
  ) {
    switch (error.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return l10n.accountCredentialsWrongCurrentPassword;
      case 'email-already-in-use':
        return l10n.accountCredentialsEmailInUse;
      case 'invalid-email':
        return l10n.accountCredentialsInvalidEmail;
      case 'weak-password':
        return l10n.accountCredentialsWeakPassword;
      case 'requires-recent-login':
        return l10n.accountCredentialsRecentLoginRequired;
      case 'too-many-requests':
        return l10n.accountCredentialsTooManyRequests;
      default:
        return error.message ?? l10n.accountCredentialsUpdateFailed;
    }
  }

  Future<void> _saveCredentials() async {
    if (_isSaving) return;
    final l10n = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final currentEmail = user?.email;
    if (user == null || currentEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.accountCredentialsSignedOut)),
      );
      return;
    }

    final requestedEmail = _emailController.text.trim();
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final changesEmail = requestedEmail != currentEmail;
    final changesPassword = newPassword.isNotEmpty;

    if (!changesEmail && !changesPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.accountCredentialsNoChanges)),
      );
      return;
    }
    if (currentPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.accountCredentialsCurrentPasswordRequired)),
      );
      return;
    }
    if (changesPassword && newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.registerPasswordsDoNotMatch)),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final credential = EmailAuthProvider.credential(
        email: currentEmail,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      if (changesPassword) {
        await user.updatePassword(newPassword);
      }
      if (changesEmail) {
        await user.verifyBeforeUpdateEmail(requestedEmail);
      }

      if (!mounted) return;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      final message = changesEmail
          ? (changesPassword
                ? l10n.accountCredentialsPasswordUpdatedEmailVerificationSent
                : l10n.accountCredentialsEmailVerificationSent)
          : l10n.accountCredentialsPasswordUpdated;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_localizedAuthError(error, l10n))),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text(l10n.accountCredentialsTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.registerEmail,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _currentPasswordController,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.accountCredentialsCurrentPassword,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.accountCredentialsNewPassword,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.accountCredentialsConfirmNewPassword,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.accountCredentialsPrivacyNotice,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveCredentials,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsetsDirectional.symmetric(vertical: 14),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(l10n.accountCredentialsSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
