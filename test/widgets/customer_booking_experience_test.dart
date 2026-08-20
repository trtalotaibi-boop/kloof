import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kloof/data/booking_store.dart';
import 'package:kloof/l10n/app_localizations.dart';
import 'package:kloof/screens/booking_confirmation_screen.dart';
import 'package:kloof/screens/booking_screen.dart';
import 'package:kloof/screens/my_bookings_screen.dart';

Widget _testApp(Widget home) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

Map<String, dynamic> _authoritativeBooking() {
  return <String, dynamic>{
    'barberName': 'Authoritative Barber',
    'service': 'Authoritative Service',
    'servicePrice': 75,
    'slotStart': Timestamp.fromDate(DateTime.utc(2026, 8, 20, 17)),
    'bookingDate': Timestamp.fromDate(DateTime.utc(2026, 8, 19, 21)),
    'createdAt': Timestamp.fromDate(DateTime.utc(2026, 8, 1)),
    'status': 'pending',
  };
}

class _MyBookingsDestination extends StatelessWidget {
  const _MyBookingsDestination();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text('MY_BOOKINGS_DESTINATION'));
  }
}

void main() {
  test('booking result passes its authoritative bookingId to confirmation', () {
    const result = BookingCreationResult(
      bookingId: 'authoritative-booking-id',
      reused: true,
    );

    final confirmation = bookingConfirmationFor(result);

    expect(confirmation.bookingId, 'authoritative-booking-id');
  });

  testWidgets('confirmation shows loading before the booking arrives', (
    tester,
  ) async {
    final controller = StreamController<Map<String, dynamic>?>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      _testApp(
        BookingConfirmationScreen(
          bookingId: 'booking-one',
          bookingStream: (_) => controller.stream,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Booking Request Received'), findsNothing);
  });

  testWidgets('confirmation shows a clear Firestore error', (tester) async {
    await tester.pumpWidget(
      _testApp(
        BookingConfirmationScreen(
          bookingId: 'booking-one',
          bookingStream: (_) =>
              Stream<Map<String, dynamic>?>.error(StateError('read failed')),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Unable to load booking details. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Booking Request Received'), findsNothing);
  });

  testWidgets('confirmation distinguishes a missing booking', (tester) async {
    await tester.pumpWidget(
      _testApp(
        BookingConfirmationScreen(
          bookingId: 'missing',
          bookingStream: (_) => Stream.value(null),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Booking could not be found.'), findsOneWidget);
    expect(find.text('Booking Request Received'), findsNothing);
  });

  testWidgets('confirmation renders authoritative booking data', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testApp(
        BookingConfirmationScreen(
          bookingId: 'booking-one',
          bookingStream: (_) => Stream.value(_authoritativeBooking()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Authoritative Barber'), findsOneWidget);
    expect(find.text('Authoritative Service'), findsOneWidget);
    expect(find.text('75 SAR'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data?.contains('8:00') ?? false) &&
            (widget.data?.contains('PM') ?? false),
      ),
      findsOneWidget,
    );
    expect(find.text('Pending'), findsOneWidget);
  });

  testWidgets('confirmation keeps navigation to My Bookings', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testApp(
        BookingConfirmationScreen(
          bookingId: 'booking-one',
          bookingStream: (_) => Stream.value(_authoritativeBooking()),
          myBookingsBuilder: (_) => const _MyBookingsDestination(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('MY_BOOKINGS_DESTINATION'), findsOneWidget);
  });

  testWidgets('My Bookings displays the authoritative service price', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        MyBookingsScreen(
          customerId: 'customer-one',
          bookingsStream: (_) => Stream.value([_authoritativeBooking()]),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Price: 75 SAR'), findsOneWidget);
    expect(find.text('Authoritative Barber'), findsOneWidget);
  });
}
