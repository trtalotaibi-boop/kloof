import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kloof/l10n/app_localizations.dart';
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
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: SingleChildScrollView(
            child: AutofillGroup(
              child: Column(
                children: [
                const SizedBox(height: 70),

                const Icon(Icons.content_cut, size: 90, color: Colors.black),

                const SizedBox(height: 20),

                Text(
                  l10n.loginWelcomeBack,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                Text(
                  l10n.loginSignInContinue,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () {},
                    child: Text(l10n.loginForgotPassword),
                  ),
                ),

                const SizedBox(height: 15),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () async {
                      debugPrint('[LOGIN] onPressed START');
                      try {
                        debugPrint(
                          '[LOGIN] calling signInWithEmailAndPassword...',
                        );
                        await FirebaseAuth.instance.signInWithEmailAndPassword(
                          email: emailController.text.trim(),
                          password: passwordController.text.trim(),
                        );
                        debugPrint(
                          '[LOGIN] signInWithEmailAndPassword returned',
                        );
                        if (!context.mounted) return;

                        final signedInUser = FirebaseAuth.instance.currentUser;
                        if (signedInUser == null) {
                          return;
                        }
                        TextInput.finishAutofillContext(shouldSave: true);

                        final userDoc = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(signedInUser.uid)
                            .get();
                        if (!context.mounted) return;
                        final userData = userDoc.data() ?? <String, dynamic>{};
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
                          : (signedInUser.email ?? l10n.bookingConfirmationLabelBarber);

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
                              content: Text(e.message ?? l10n.loginFailed),
                            ),
                          );
                        }
                      } catch (e, stack) {
                        debugPrint('[LOGIN] Unexpected error: $e');
                        debugPrint('[LOGIN] Stack: $stack');
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
