import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kloof/l10n/app_localizations.dart';
import 'package:kloof/theme/kloof_theme.dart';

import 'home_screen.dart';
import 'barber_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;

  String _localizedAuthError(
    FirebaseAuthException error,
    AppLocalizations l10n,
  ) {
    switch (error.code) {
      case 'invalid-email':
        return l10n.authInvalidEmail;
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return l10n.authInvalidCredentials;
      case 'too-many-requests':
        return l10n.authTooManyRequests;
      case 'network-request-failed':
        return l10n.authNetworkError;
      case 'user-disabled':
        return l10n.authUserDisabled;
      case 'operation-not-allowed':
        return l10n.authOperationNotAllowed;
      default:
        return l10n.authUnexpectedError;
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = emailController.text.trim();
    final l10n = AppLocalizations.of(context);
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.loginEmailRequiredForReset)));
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.loginPasswordResetSent)));
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_localizedAuthError(error, l10n))));
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(),
      backgroundColor: KloofColors.warmOffWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: SingleChildScrollView(
            child: AutofillGroup(
              child: Column(
                children: [
                  const SizedBox(height: 70),

                  const _KloofMark(size: 92),

                  const SizedBox(height: 20),

                  Text(
                    l10n.loginWelcomeBack,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    l10n.loginSignInContinue,
                    style: TextStyle(
                      color: KloofColors.secondaryText,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 45),

                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                    autocorrect: false,
                    decoration: InputDecoration(
                      hintText: l10n.loginEmail,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                  ),

                  const SizedBox(height: 20),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(
                      hintText: l10n.loginPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: _sendPasswordReset,
                      child: Text(l10n.loginForgotPassword),
                    ),
                  ),

                  const SizedBox(height: 15),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () async {
                        final email = emailController.text.trim();
                        final password = passwordController.text.trim();
                        if (email.isEmpty || password.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.authRequiredFields)),
                          );
                          return;
                        }
                        debugPrint('[LOGIN] onPressed START');
                        try {
                          debugPrint(
                            '[LOGIN] calling signInWithEmailAndPassword...',
                          );
                          await FirebaseAuth.instance
                              .signInWithEmailAndPassword(
                                email: email,
                                password: password,
                              );
                          debugPrint(
                            '[LOGIN] signInWithEmailAndPassword returned',
                          );
                          if (!context.mounted) return;

                          final signedInUser =
                              FirebaseAuth.instance.currentUser;
                          if (signedInUser == null) {
                            return;
                          }
                          TextInput.finishAutofillContext(shouldSave: true);

                          final userDoc = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(signedInUser.uid)
                              .get();
                          if (!context.mounted) return;
                          final userData =
                              userDoc.data() ?? <String, dynamic>{};
                          final role =
                              (userData['role']?.toString().toLowerCase() ??
                              'customer');
                          final fullName =
                              userData['fullName']
                                      ?.toString()
                                      .trim()
                                      .isNotEmpty ==
                                  true
                              ? userData['fullName'].toString().trim()
                              : (signedInUser.email ??
                                    l10n.bookingConfirmationLabelBarber);

                          if (role == 'barber') {
                            debugPrint(
                              '[LOGIN] navigating to BarberDashboardScreen',
                            );
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    BarberDashboardScreen(barberName: fullName),
                              ),
                            );
                          } else {
                            debugPrint('[LOGIN] navigating to HomeScreen');
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HomeScreen(),
                              ),
                            );
                          }
                        } on FirebaseAuthException catch (e) {
                          debugPrint(
                            '[LOGIN] FirebaseAuthException: ${e.code} - ${e.message}',
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(_localizedAuthError(e, l10n)),
                              ),
                            );
                          }
                        } catch (e, stack) {
                          debugPrint('[LOGIN] Unexpected error: $e');
                          debugPrint('[LOGIN] Stack: $stack');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.authUnexpectedError)),
                            );
                          }
                        }
                        debugPrint('[LOGIN] onPressed END');
                      },
                      child: Text(
                        l10n.loginAction,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KloofMark extends StatelessWidget {
  final double size;

  const _KloofMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: KloofColors.cardBackground,
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(color: KloofColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/branding/kloof-app-icon-master.png',
        fit: BoxFit.cover,
      ),
    );
  }
}
