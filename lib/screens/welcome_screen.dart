import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'package:kloof/screens/register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  final String selectedRole;

  const WelcomeScreen({super.key, required this.selectedRole});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.content_cut, size: 100, color: Colors.black),

                const SizedBox(height: 30),

                const Text(
                  'KLOOF',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),

                const SizedBox(height: 15),

                const Text(
                  'Book your barber in seconds.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),

                const SizedBox(height: 50),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (route) => route.isFirst,
                      );
                    },
                    child: const Text('Login', style: TextStyle(fontSize: 18)),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              RegisterScreen(selectedRole: selectedRole),
                        ),
                        (route) => route.isFirst,
                      );
                    },
                    child: const Text(
                      'Create Account',
                      style: TextStyle(fontSize: 18),
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
