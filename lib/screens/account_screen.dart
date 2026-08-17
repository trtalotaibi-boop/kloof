import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kloof/l10n/app_localizations.dart';
import 'package:kloof/theme/kloof_theme.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_links.dart';
import 'welcome_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _isDeleting = false;

  Future<void> _openPrivacyPolicy() async {
    final l10n = AppLocalizations.of(context);
    final uri = Uri.tryParse(kPrivacyPolicyUrl.trim());
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.accountPrivacyUrlUnavailable)),
      );
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.accountPrivacyOpenFailed)));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.accountPrivacyOpenFailed)));
    }
  }

  Future<bool> _confirmDelete() async {
    final l10n = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.accountDeleteTitle),
            content: Text(l10n.accountDeleteConfirmation),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.commonCancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(l10n.accountDeleteAction),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteAccount() async {
    if (_isDeleting || !await _confirmDelete()) return;

    final l10n = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.accountDeleteSignedOut)));
      return;
    }

    setState(() => _isDeleting = true);
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(user.uid);
    final barberRef = firestore.collection('barbers').doc(user.uid);
    final barberPrivateRef = firestore
        .collection('barberPrivate')
        .doc(user.uid);

    DocumentSnapshot<Map<String, dynamic>>? userSnapshot;
    DocumentSnapshot<Map<String, dynamic>>? barberSnapshot;
    DocumentSnapshot<Map<String, dynamic>>? barberPrivateSnapshot;
    List<QueryDocumentSnapshot<Map<String, dynamic>>> pushTokenSnapshots = [];
    var firestoreDataDeleted = false;

    try {
      userSnapshot = await userRef.get();
      barberSnapshot = await barberRef.get();
      barberPrivateSnapshot = await barberPrivateRef.get();
      pushTokenSnapshots = (await userRef.collection('pushTokens').get()).docs;

      final deleteBatch = firestore.batch();
      for (final token in pushTokenSnapshots) {
        deleteBatch.delete(token.reference);
      }
      if (barberSnapshot.exists) deleteBatch.delete(barberRef);
      if (barberPrivateSnapshot.exists) deleteBatch.delete(barberPrivateRef);
      if (userSnapshot.exists) deleteBatch.delete(userRef);
      await deleteBatch.commit();
      firestoreDataDeleted = true;

      await user.delete();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      final restored =
          !firestoreDataDeleted ||
          await _restoreProfileData(
            firestore,
            userSnapshot,
            barberSnapshot,
            barberPrivateSnapshot,
            pushTokenSnapshots,
          );
      if (!mounted) return;

      if (error.code == 'requires-recent-login') {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.accountDeleteRecentLoginTitle),
            content: Text(
              restored
                  ? l10n.accountDeleteRecentLoginMessage
                  : l10n.accountDeleteRestoreFailed,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.accountDeleteGoToSignIn),
              ),
            ],
          ),
        );
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              restored
                  ? l10n.accountDeleteFailed
                  : l10n.accountDeleteRestoreFailed,
            ),
          ),
        );
      }
    } on FirebaseException {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.accountDeleteFailed)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.accountDeleteFailed)));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<bool> _restoreProfileData(
    FirebaseFirestore firestore,
    DocumentSnapshot<Map<String, dynamic>>? userSnapshot,
    DocumentSnapshot<Map<String, dynamic>>? barberSnapshot,
    DocumentSnapshot<Map<String, dynamic>>? barberPrivateSnapshot,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> pushTokenSnapshots,
  ) async {
    try {
      final restoreBatch = firestore.batch();
      final userData = userSnapshot?.data();
      final barberData = barberSnapshot?.data();
      final barberPrivateData = barberPrivateSnapshot?.data();
      if (userSnapshot?.exists == true && userData != null) {
        restoreBatch.set(userSnapshot!.reference, userData);
      }
      if (barberSnapshot?.exists == true && barberData != null) {
        restoreBatch.set(barberSnapshot!.reference, barberData);
      }
      if (barberPrivateSnapshot?.exists == true && barberPrivateData != null) {
        restoreBatch.set(barberPrivateSnapshot!.reference, barberPrivateData);
      }
      for (final token in pushTokenSnapshots) {
        restoreBatch.set(token.reference, token.data());
      }
      await restoreBatch.commit();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: KloofColors.warmOffWhite,
      appBar: AppBar(
        backgroundColor: KloofColors.warmOffWhite,
        foregroundColor: KloofColors.primaryText,
        title: Text(l10n.accountTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.all(20),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(l10n.accountPrivacyPolicy),
                trailing: const Icon(Icons.open_in_new),
                onTap: _openPrivacyPolicy,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                enabled: !_isDeleting,
                leading: _isDeleting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_forever_outlined),
                iconColor: Colors.red,
                textColor: Colors.red,
                title: Text(l10n.accountDeleteAction),
                subtitle: Text(l10n.accountDeletePermanentHint),
                onTap: _isDeleting ? null : _deleteAccount,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
