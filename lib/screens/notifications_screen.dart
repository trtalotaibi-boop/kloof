import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Future<void> _markAsRead(String notificationId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: currentUser == null
          ? const Center(
              child: Text(
                'No notifications.',
                style: TextStyle(color: Colors.black54, fontSize: 15),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('recipientId', isEqualTo: currentUser.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No notifications.',
                      style: TextStyle(color: Colors.black54, fontSize: 15),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data();
                    final message = data['message']?.toString() ?? '-';
                    final isRead = data['isRead'] == true;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: isRead ? Colors.white : Colors.grey.shade100,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        onTap: isRead ? null : () => _markAsRead(doc.id),
                        leading: Icon(
                          Icons.notifications_none,
                          color: isRead ? Colors.black45 : Colors.black,
                        ),
                        title: Text(
                          message,
                          style: TextStyle(
                            color: Colors.black,
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
