import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterScreen extends StatefulWidget {

  const RegisterScreen({super.key});

  @override

  State<RegisterScreen> createState() => _RegisterScreenState();

}

class _RegisterScreenState extends State<RegisterScreen> {

  bool obscurePassword = true;

  bool obscureConfirmPassword = true;

  final TextEditingController fullNameController = TextEditingController();

  final TextEditingController emailController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  final TextEditingController confirmPasswordController =

      TextEditingController();

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        backgroundColor: Colors.white,

        elevation: 0,

      ),

      backgroundColor: Colors.white,

      body: SafeArea(

        child: SingleChildScrollView(

          padding: const EdgeInsets.all(30),

          child: Column(

            children: [

              const SizedBox(height: 20),

              const Icon(

                Icons.content_cut,

                size: 90,

              ),

              const SizedBox(height: 20),

              const Text(

                "Create Account",

                style: TextStyle(

                  fontSize: 34,

                  fontWeight: FontWeight.bold,

                ),

              ),

              const SizedBox(height: 10),

              const Text(

                "Create your KLOOF account",

                style: TextStyle(

                  fontSize: 18,

                  color: Colors.grey,

                ),

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

                        obscureConfirmPassword =

                            !obscureConfirmPassword;

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
  if (passwordController.text != confirmPasswordController.text) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Passwords do not match"),
      ),
    );
    return;
  }

  try {
    debugPrint("START REGISTER");
    await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
    );
    debugPrint("REGISTER SUCCESS");

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Account created successfully!"),
      ),
    );

    Navigator.pop(context);
  } on FirebaseAuthException catch (e) {
    print("CODE: ${e.code}");
    print("MESSAGE: ${e.message}");
    print("EXCEPTION: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.message ?? "Something went wrong"),
      ),
    );
  } catch (e, s) {
    print(e);
    print(s);
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