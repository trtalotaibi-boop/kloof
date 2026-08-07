import 'package:flutter/material.dart';
import 'package:kloof/l10n/app_localizations.dart';
import 'package:kloof/widgets/language_selector.dart';
import 'login_screen.dart';
import 'package:kloof/screens/register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  final String selectedRole;
  final bool showBarberPortal;
  final bool showBackButton;
  final ValueChanged<Locale>? onLocaleChanged;

  const WelcomeScreen({
    super.key,
    this.selectedRole = 'customer',
    this.showBarberPortal = true,
    this.showBackButton = false,
    this.onLocaleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
              actions: [
                if (onLocaleChanged != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 12),
                    child: LanguageSelector(
                      onLocaleChanged: onLocaleChanged!,
                    ),
                  ),
              ],
            )
          : null,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: onLocaleChanged == null
                      ? const SizedBox(height: 40)
                      : LanguageSelector(
                          onLocaleChanged: onLocaleChanged!,
                        ),
                ),
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

                    Text(
                      l10n.welcomeTagline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, color: Colors.grey),
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
                              builder: (context) => LoginScreen(
                                onLocaleChanged: onLocaleChanged,
                              ),
                            ),
                          );
                        },
                        child: Text(
                          l10n.welcomeLogin,
                          style: const TextStyle(fontSize: 18),
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
                        child: Text(
                          l10n.welcomeCreateAccount,
                          style: const TextStyle(fontSize: 18),
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
                            builder: (context) => WelcomeScreen(
                              selectedRole: 'barber',
                              showBarberPortal: false,
                              showBackButton: true,
                              onLocaleChanged: onLocaleChanged,
                            ),
                          ),
                        );
                      },
                      child: Text(l10n.welcomeBarberPortal),
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
