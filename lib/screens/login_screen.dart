import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 70),

                const Icon(Icons.content_cut, size: 90, color: Colors.black),

                const SizedBox(height: 20),

                const Text(
                  "Welcome Back",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                const Text(
                  "Sign in to continue",
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),

                const SizedBox(height: 45),

                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    hintText: "Email",
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
                  decoration: InputDecoration(
                    hintText: "Password",
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
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text("Forgot Password?"),
                  ),
                ),

                const SizedBox(height: 15),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () async {
                      debugPrint('[LOGIN] onPressed START');
                      final ctx = context;
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
                        print('Login success');

                        if (!mounted) return;

                        final signedInUser = FirebaseAuth.instance.currentUser;
                        if (signedInUser == null) {
                          return;
                        }

                        final userDoc = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(signedInUser.uid)
                            .get();
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
                            : (signedInUser.email ?? 'Barber');

                        if (role == 'barber') {
                          debugPrint(
                            '[LOGIN] navigating to BarberDashboardScreen',
                          );
                          // ignore: use_build_context_synchronously
                          Navigator.pushReplacement(
                            ctx,
                            MaterialPageRoute(
                              builder: (_) =>
                                  BarberDashboardScreen(barberName: fullName),
                            ),
                          );
                        } else {
                          debugPrint('[LOGIN] navigating to HomeScreen');
                          // ignore: use_build_context_synchronously
                          Navigator.pushReplacement(
                            ctx,
                            MaterialPageRoute(
                              builder: (_) => const HomeScreen(),
                            ),
                          );
                        }
                      } on FirebaseAuthException catch (e) {
                        debugPrint(
                          '[LOGIN] FirebaseAuthException: ${e.code} - ${e.message}',
                        );
                        print('Login error: ${e.code} - ${e.message}');
                        if (mounted) {
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(e.message ?? "Login failed"),
                            ),
                          );
                        }
                      } catch (e, stack) {
                        debugPrint('[LOGIN] Unexpected error: $e');
                        debugPrint('[LOGIN] Stack: $stack');
                      }
                      debugPrint('[LOGIN] onPressed END');
                    },
                    child: const Text("Login", style: TextStyle(fontSize: 18)),
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
