import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kloof/l10n/app_localizations.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/barber_dashboard_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/locale_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final localeFuture = LocalePreferences.loadLocale();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final initialLocale = await localeFuture;

  runApp(KloofApp(initialLocale: initialLocale));
}

class KloofApp extends StatefulWidget {
  final Locale? initialLocale;

  const KloofApp({
    super.key,
    this.initialLocale,
  });

  @override
  State<KloofApp> createState() => _KloofAppState();
}

class _KloofAppState extends State<KloofApp> {
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
  }

  void _setLocale(Locale locale) {
    if (_locale == locale) return;

    setState(() {
      _locale = locale;
    });

    unawaited(LocalePreferences.saveLocale(locale));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: _locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        if (deviceLocale != null) {
          for (final supportedLocale in supportedLocales) {
            if (supportedLocale.languageCode == deviceLocale.languageCode) {
              return supportedLocale;
            }
          }
        }
        return const Locale('en');
      },
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
      ),
      home: AuthenticationWrapper(onLocaleChanged: _setLocale),
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  final ValueChanged<Locale> onLocaleChanged;

  const AuthenticationWrapper({
    super.key,
    required this.onLocaleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;
          return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final userData = userSnapshot.data?.data() ?? <String, dynamic>{};
              final role =
                  (userData['role']?.toString().toLowerCase() ?? 'customer');
              final fullName = userData['fullName']?.toString().trim();
              final barberName = (fullName != null && fullName.isNotEmpty)
                  ? fullName
                  : (user.email ?? 'Barber');

              if (role == 'barber') {
                return BarberDashboardScreen(barberName: barberName);
              }

              return const HomeScreen();
            },
          );
        }

        return WelcomeScreen(onLocaleChanged: onLocaleChanged);
      },
    );
  }
}
