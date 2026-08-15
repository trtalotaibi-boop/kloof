import 'package:flutter/material.dart';
import 'package:kloof/l10n/app_localizations.dart';
import 'package:kloof/theme/kloof_theme.dart';
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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: KloofColors.deepBlack,
      appBar: showBackButton
          ? AppBar(
              backgroundColor: KloofColors.deepBlack,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 12),
                const SizedBox.shrink(),
                Column(
                  children: [
                    Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        color: KloofColors.cardBackground,
                        border: Border.all(color: KloofColors.border),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/branding/kloof-app-icon-master.png',
                        fit: BoxFit.cover,
                      ),
                    ),

                    const SizedBox(height: 30),

                    Text(
                      'KLOOF',
                      style: const TextStyle(
                        fontSize: 42,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 5,
                      ),
                    ),

                    const SizedBox(height: 15),

                    Text(
                      l10n.welcomeTagline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        color: KloofColors.softGold,
                      ),
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: KloofColors.luxuryGold,
                          foregroundColor: KloofColors.deepBlack,
                        ),
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
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: KloofColors.luxuryGold),
                        ),
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
                    padding: const EdgeInsetsDirectional.only(bottom: 12),
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
                      style: TextButton.styleFrom(
                        foregroundColor: KloofColors.softGold,
                      ),
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
