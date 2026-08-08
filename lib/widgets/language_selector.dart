import 'package:flutter/material.dart';

class LanguageSelector extends StatelessWidget {
  final ValueChanged<Locale> onLocaleChanged;

  const LanguageSelector({
    super.key,
    required this.onLocaleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentLocale = Localizations.localeOf(context);
    final isArabic = currentLocale.languageCode == 'ar';

    return PopupMenuButton<Locale>(
      tooltip: 'Language',
      onSelected: onLocaleChanged,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: Locale('ar'),
          child: Text('العربية'),
        ),
        PopupMenuItem(
          value: Locale('en'),
          child: Text('English'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, size: 20),
            const SizedBox(width: 6),
            Text(isArabic ? 'العربية' : 'English'),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }
}
