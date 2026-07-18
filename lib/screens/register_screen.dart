import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'barber_dashboard_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0),

      backgroundColor: Colors.white,

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),

          child: Column(
            children: [
              const SizedBox(height: 20),

              const Icon(Icons.content_cut, size: 90),

              const SizedBox(height: 20),

              const Text(
                "Create Account",

                style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              const Text(
                "Create your KLOOF account",

                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),

              const SizedBox(height: 40),

              TextField(
                controller: fullNameController,

                decoration: const InputDecoration(
                  labelText: "Full Name",

                  border: OutlineInputBorder(),

                  prefixIcon: Icon(Icons.person),
                ),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: emailController,

                decoration: const InputDecoration(
                  labelText: "Email",

                  border: OutlineInputBorder(),

                  prefixIcon: Icon(Icons.email),
                ),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: passwordController,

                obscureText: obscurePassword,

                decoration: InputDecoration(
                  labelText: "Password",

                  border: const OutlineInputBorder(),

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
                  labelText: "Confirm Password",

                  border: const OutlineInputBorder(),

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
                    if (passwordController.text !=
                        confirmPasswordController.text) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Passwords do not match")),
                      );
                      return;
                    }

                    final ctx = context;
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
                            'role': widget.selectedRole,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                        }
                      }

                      debugPrint("REGISTER SUCCESS");

                      if (!mounted) return;

                      final registeredName = fullNameController.text.trim();
                      final barberName = registeredName.isNotEmpty
                          ? registeredName
                          : (user?.email ?? 'Barber');

                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text("Account created successfully!"),
                        ),
                      );

                      if (widget.selectedRole == 'barber') {
                        // ignore: use_build_context_synchronously
                        Navigator.pushReplacement(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) =>
                                BarberDashboardScreen(barberName: barberName),
                          ),
                        );
                      } else {
                        // ignore: use_build_context_synchronously
                        Navigator.pop(ctx);
                      }
                    } on FirebaseAuthException catch (e) {
                      debugPrint("Firebase error: ${e.message}");
                      if (mounted) {
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(e.message ?? "Something went wrong"),
                          ),
                        );
                      }
                    } catch (e, s) {
                      debugPrint("Error: $e\n$s");
                    }
                  },

                  child: const Text(
                    "Create Account",

                    style: TextStyle(fontSize: 18),
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
