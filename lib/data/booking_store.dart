import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/booking_slot.dart';

class SlotAlreadyBookedException implements Exception {}

class BarberUnavailableException implements Exception {}

class BookingStore {
  final FirebaseFirestore firestore;

  const BookingStore(this.firestore);

  Future<DocumentReference<Map<String, dynamic>>> createBooking({
    required BookingSlot slot,
    required Map<String, dynamic> booking,
  }) async {
    final barberRef = firestore.collection('barbers').doc(slot.barberId);
    final lockRef = firestore.collection('bookingSlots').doc(slot.id);
    final bookingRef = firestore.collection('bookings').doc();

    await firestore.runTransaction((transaction) async {
      final barber = await transaction.get(barberRef);
      if (!barber.exists || barber.data()?['isOnline'] != true) {
        throw BarberUnavailableException();
      }

      final lock = await transaction.get(lockRef);
      if (lock.exists) throw SlotAlreadyBookedException();

      transaction.set(lockRef, {
        'slotId': slot.id,
        'barberId': slot.barberId,
        'slotStart': Timestamp.fromDate(slot.normalizedStart),
        'bookingId': bookingRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(bookingRef, {
        ...booking,
        'slotId': slot.id,
        'slotStart': Timestamp.fromDate(slot.normalizedStart),
        'bookingDate': Timestamp.fromDate(
          DateTime(slot.start.year, slot.start.month, slot.start.day),
        ),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    return bookingRef;
  }

  Future<bool> updateBookingStatus(String bookingId, String status) async {
    final bookingRef = firestore.collection('bookings').doc(bookingId);
    final requestedStatus = status.toLowerCase();

    return firestore.runTransaction<bool>((transaction) async {
      final booking = await transaction.get(bookingRef);
      if (!booking.exists) return false;

      final currentStatus = (booking.data()?['status']?.toString() ?? 'pending')
          .toLowerCase();
      final isAllowed =
          (currentStatus == 'pending' &&
              (requestedStatus == 'accepted' ||
                  requestedStatus == 'rejected')) ||
          (currentStatus == 'accepted' && requestedStatus == 'completed');
      if (!isAllowed) return false;

      final slotId = booking.data()?['slotId']?.toString();
      DocumentReference<Map<String, dynamic>>? lockRef;
      DocumentSnapshot<Map<String, dynamic>>? lock;
      if (requestedStatus == 'rejected' &&
          slotId != null &&
          slotId.isNotEmpty) {
        lockRef = firestore.collection('bookingSlots').doc(slotId);
        lock = await transaction.get(lockRef);
      }

      transaction.update(bookingRef, {'status': requestedStatus});
      if (lockRef != null && lock?.data()?['bookingId'] == bookingId) {
        transaction.delete(lockRef);
      }
      return true;
    });
  }
}
