import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'package:kloof/screens/register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  final String selectedRole;
  final bool showBarberPortal;
  final bool showBackButton;

  const WelcomeScreen({
    super.key,
    this.selectedRole = 'customer',
    this.showBarberPortal = true,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: showBackButton
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.black),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 12),
                const SizedBox.shrink(),
                Column(
                  children: [
                    const Icon(
                      Icons.content_cut,
                      size: 100,
                      color: Colors.black,
                    ),

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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Login',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  RegisterScreen(selectedRole: selectedRole),
                            ),
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
                if (showBarberPortal)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WelcomeScreen(
                              selectedRole: 'barber',
                              showBarberPortal: false,
                              showBackButton: true,
                            ),
                          ),
                        );
                      },
                      child: const Text('Barber Portal'),
                    ),
                  )
                else
                  const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
