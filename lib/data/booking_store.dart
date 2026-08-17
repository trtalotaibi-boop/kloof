import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SlotAlreadyBookedException implements Exception {}

class BarberUnavailableException implements Exception {}

class BookingStore {
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  BookingStore(this.firestore, {FirebaseFunctions? functions})
    : functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'me-central2');

  Future<String> createBooking({
    required String barberId,
    required String service,
    required DateTime slotStart,
  }) async {
    try {
      final callable = functions.httpsCallable('createBooking');
      final result = await callable.call(<String, dynamic>{
        'barberId': barberId,
        'service': service,
        'slotStartMillis': slotStart.millisecondsSinceEpoch,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      return data['bookingId']?.toString() ?? '';
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'already-exists') {
        throw SlotAlreadyBookedException();
      }
      if (error.code == 'failed-precondition' || error.code == 'not-found') {
        throw BarberUnavailableException();
      }
      rethrow;
    }
  }

  Future<bool> updateBookingStatus(String bookingId, String status) async {
    final callable = functions.httpsCallable('updateBookingStatus');
    final result = await callable.call(<String, dynamic>{
      'bookingId': bookingId,
      'status': status.toLowerCase(),
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['updated'] == true;
  }
}
