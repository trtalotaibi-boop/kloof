import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kloof/l10n/app_localizations.dart';
import 'package:kloof/theme/kloof_theme.dart';

class RegisterScreen extends StatefulWidget {
  final String selectedRole;

  const RegisterScreen({super.key, required this.selectedRole});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool obscurePassword = true;

  bool obscureConfirmPassword = true;

  final TextEditingController fullNameController = TextEditingController();

  final TextEditingController emailController = TextEditingController();

  final TextEditingController phoneController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  final TextEditingController confirmPasswordController =
      TextEditingController();

  String _localizedAuthError(
    FirebaseAuthException error,
    AppLocalizations l10n,
  ) {
    switch (error.code) {
      case 'invalid-email':
        return l10n.authInvalidEmail;
      case 'email-already-in-use':
        return l10n.authEmailAlreadyInUse;
      case 'weak-password':
        return l10n.authWeakPassword;
      case 'too-many-requests':
        return l10n.authTooManyRequests;
      case 'network-request-failed':
        return l10n.authNetworkError;
      case 'operation-not-allowed':
        return l10n.authOperationNotAllowed;
      default:
        return l10n.authUnexpectedError;
    }
  }

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(),

      backgroundColor: KloofColors.warmOffWhite,

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),

          child: Column(
            children: [
              const SizedBox(height: 20),

              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: KloofColors.cardBackground,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: KloofColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/branding/kloof-app-icon-master.png',
                  fit: BoxFit.cover,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                l10n.registerTitle,

                style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              Text(
                l10n.registerSubtitle,

                style: TextStyle(
                  fontSize: 18,
                  color: KloofColors.secondaryText,
                ),
              ),

              const SizedBox(height: 40),

              TextField(
                controller: fullNameController,

                decoration: InputDecoration(
                  labelText: l10n.registerFullName,

                  prefixIcon: const Icon(Icons.person),
                ),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: emailController,

                decoration: InputDecoration(
                  labelText: l10n.registerEmail,

                  prefixIcon: const Icon(Icons.email),
                ),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.registerPhone,
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: passwordController,

                obscureText: obscurePassword,

                decoration: InputDecoration(
                  labelText: l10n.registerPassword,

                  prefixIcon: const Icon(Icons.lock),

                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),

                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: confirmPasswordController,

                obscureText: obscureConfirmPassword,

                decoration: InputDecoration(
                  labelText: l10n.registerConfirmPassword,

                  prefixIcon: const Icon(Icons.lock_outline),

                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),

                    onPressed: () {
                      setState(() {
                        obscureConfirmPassword = !obscureConfirmPassword;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 35),

              SizedBox(
                width: double.infinity,

                height: 55,

                child: ElevatedButton(
                  onPressed: () async {
                    if (widget.selectedRole.toLowerCase() == 'barber') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.authOperationNotAllowed)),
                      );
                      return;
                    }
                    if (fullNameController.text.trim().isEmpty ||
                        emailController.text.trim().isEmpty ||
                        phoneController.text.trim().isEmpty ||
                        passwordController.text.isEmpty ||
                        confirmPasswordController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.authRequiredFields)),
                      );
                      return;
                    }
                    if (passwordController.text !=
                        confirmPasswordController.text) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.registerPasswordsDoNotMatch),
                        ),
                      );
                      return;
                    }

                    try {
                      debugPrint("START REGISTER");
                      final credential = await FirebaseAuth.instance
                          .createUserWithEmailAndPassword(
                            email: emailController.text.trim(),
                            password: passwordController.text.trim(),
                          );

                      final user = credential.user;
                      if (user != null) {
                        final userDocRef = FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid);
                        final userDoc = await userDocRef.get();

                        if (!userDoc.exists) {
                          await userDocRef.set({
                            'fullName': fullNameController.text.trim(),
                            'email': emailController.text.trim(),
                            'phone': phoneController.text.trim(),
                            'role': 'customer',
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                        }
                      }

                      debugPrint("REGISTER SUCCESS");

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.registerAccountCreated)),
                      );

                      Navigator.pop(context);
                    } on FirebaseAuthException catch (e) {
                      debugPrint("Firebase error: ${e.message}");
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_localizedAuthError(e, l10n))),
                        );
                      }
                    } catch (e, s) {
                      debugPrint("Error: $e\n$s");
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.authUnexpectedError)),
                        );
                      }
                    }
                  },

                  child: Text(
                    l10n.registerAction,

                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
