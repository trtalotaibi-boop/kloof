import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kloof/l10n/app_localizations.dart';
import 'package:kloof/theme/kloof_theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  String _localizedNotificationMessage(
    String rawMessage,
    AppLocalizations l10n,
  ) {
    final normalized = rawMessage.trim();
    if (normalized.isEmpty || normalized == '-') {
      return l10n.notificationsGenericMessage;
    }

    const messageKeys = <String, String>{
      'Your booking request has been submitted.': 'submitted',
      'New booking request.': 'newRequest',
      'Your booking has been accepted.': 'accepted',
      'Your booking has been rejected.': 'rejected',
      'Your appointment has been completed.': 'completed',
    };

    final mapped = messageKeys[normalized];
    if (mapped == null) {
      final containsArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(normalized);
      return containsArabic ? normalized : l10n.notificationsGenericMessage;
    }

    switch (mapped) {
      case 'submitted':
        return l10n.notificationMessageBookingSubmitted;
      case 'newRequest':
        return l10n.notificationMessageNewBookingRequest;
      case 'accepted':
        return l10n.notificationMessageBookingAccepted;
      case 'rejected':
        return l10n.notificationMessageBookingRejected;
      case 'completed':
        return l10n.notificationMessageAppointmentCompleted;
      default:
        return rawMessage;
    }
  }

  DateTime _createdAt(DocumentSnapshot<Map<String, dynamic>> document) {
    final value = document.data()?['createdAt'];
    return value is Timestamp
        ? value.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _markAsRead(
    BuildContext context,
    String notificationId,
    String currentUserId,
  ) async {
    final l10n = AppLocalizations.of(context);
    final reference = FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId);
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(reference);
        if (snapshot.data()?['recipientId'] != currentUserId) return;
        transaction.update(reference, {'isRead': true});
      });
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.notificationsMarkReadFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: KloofColors.warmOffWhite,
      appBar: AppBar(
        backgroundColor: KloofColors.warmOffWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: KloofColors.primaryText),
        title: Text(
          l10n.notificationsTitle,
          style: const TextStyle(color: KloofColors.primaryText),
        ),
      ),
      body: currentUser == null
          ? Center(
              child: Text(
                l10n.notificationsEmpty,
                style: const TextStyle(
                  color: KloofColors.secondaryText,
                  fontSize: 15,
                ),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('recipientId', isEqualTo: currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(
                          l10n.notificationsLoading,
                          style: const TextStyle(
                            color: KloofColors.secondaryText,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      l10n.notificationsLoadFailed,
                      style: const TextStyle(
                        color: KloofColors.secondaryText,
                        fontSize: 15,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.notificationsEmpty,
                      style: const TextStyle(
                        color: KloofColors.secondaryText,
                        fontSize: 15,
                      ),
                    ),
                  );
                }

                final notifications = [...snapshot.data!.docs]
                  ..sort((a, b) => _createdAt(b).compareTo(_createdAt(a)));

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final doc = notifications[index];
                    final data = doc.data();
                    final message = data['message']?.toString() ?? '-';
                    final localizedMessage = _localizedNotificationMessage(
                      message,
                      l10n,
                    );
                    final isRead = data['isRead'] == true;

                    return Card(
                      margin: const EdgeInsetsDirectional.only(bottom: 10),
                      color: isRead
                          ? KloofColors.cardBackground
                          : KloofColors.softGold.withValues(alpha: 0.18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        onTap: isRead
                            ? null
                            : () =>
                                  _markAsRead(context, doc.id, currentUser.uid),
                        leading: Icon(
                          Icons.notifications_none,
                          color: isRead
                              ? KloofColors.mutedText
                              : KloofColors.luxuryGold,
                        ),
                        title: Text(
                          localizedMessage,
                          style: TextStyle(
                            color: KloofColors.primaryText,
                            fontWeight: isRead
                                ? FontWeight.w400
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
