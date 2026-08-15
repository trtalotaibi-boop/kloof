import 'package:cloud_firestore/cloud_firestore.dart';

class BarberProfileStore {
  final FirebaseFirestore firestore;

  const BarberProfileStore(this.firestore);

  Future<DocumentReference<Map<String, dynamic>>> ensureCanonicalProfile({
    required String uid,
    String? fallbackName,
  }) async {
    final canonicalRef = firestore.collection('barbers').doc(uid);
    final canonical = await canonicalRef.get();
    if (canonical.exists) return canonicalRef;

    final name = fallbackName?.trim();
    await canonicalRef.set({
      'uid': uid,
      'ownerUid': uid,
      if (name != null && name.isNotEmpty) ...{'fullName': name, 'name': name},
      'profileImage': '',
      'imageUrl': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return canonicalRef;
  }
}
