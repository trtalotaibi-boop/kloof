import 'package:flutter/material.dart';
import 'package:kloof/l10n/app_localizations.dart';
import 'package:kloof/theme/kloof_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppFeedbackButton extends StatelessWidget {
  const WhatsAppFeedbackButton({super.key});

  static final Uri _feedbackUri = Uri.https('wa.me', '/966563994926', {
    'text': 'مرحبًا، لدي ملاحظة حول تطبيق KLOOF.',
  });

  Future<void> _openWhatsApp(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    try {
      final opened = await launchUrl(
        _feedbackUri,
        mode: LaunchMode.externalApplication,
      );
      if (opened || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.whatsAppFeedbackOpenFailed)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _openWhatsApp(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: KloofColors.primaryBlack,
          side: const BorderSide(color: KloofColors.luxuryGold),
          padding: const EdgeInsetsDirectional.symmetric(vertical: 12),
        ),
        icon: const Icon(Icons.chat_outlined),
        label: Text(l10n.whatsAppFeedbackAction),
      ),
    );
  }
}
