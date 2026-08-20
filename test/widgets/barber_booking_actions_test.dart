import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kloof/l10n/app_localizations.dart';
import 'package:kloof/widgets/barber_booking_actions.dart';

Widget _testApp(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

Widget _actions({
  required String bookingId,
  required String status,
  required BookingStatusUpdater updater,
}) {
  return BarberBookingActions(
    key: ValueKey('booking-actions-$bookingId'),
    bookingId: bookingId,
    status: status,
    updateStatus: updater,
  );
}

void main() {
  testWidgets('pending booking can be accepted and waits for stream status', (
    tester,
  ) async {
    final requests = <String>[];
    Future<bool> updater(String _, String status) async {
      requests.add(status);
      return true;
    }

    await tester.pumpWidget(
      _testApp(_actions(bookingId: 'one', status: 'pending', updater: updater)),
    );
    await tester.tap(find.byKey(const ValueKey('booking-accept-one')));
    await tester.pump();

    expect(requests, ['accepted']);
    expect(find.text('Booking accepted.'), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-loading-one')), findsOneWidget);

    await tester.pumpWidget(
      _testApp(
        _actions(bookingId: 'one', status: 'accepted', updater: updater),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('booking-loading-one')), findsNothing);
    expect(find.byKey(const ValueKey('booking-complete-one')), findsOneWidget);
  });

  testWidgets('pending booking can be rejected after confirmation', (
    tester,
  ) async {
    final requests = <String>[];
    Future<bool> updater(String _, String status) async {
      requests.add(status);
      return true;
    }

    await tester.pumpWidget(
      _testApp(_actions(bookingId: 'one', status: 'pending', updater: updater)),
    );
    await tester.tap(find.byKey(const ValueKey('booking-reject-one')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(requests, isEmpty);

    await tester.tap(find.text('Confirm rejection'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(requests, ['rejected']);
    expect(find.text('Booking rejected.'), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-loading-one')), findsOneWidget);
  });

  testWidgets('accepted booking can be completed', (tester) async {
    final requests = <String>[];
    Future<bool> updater(String _, String status) async {
      requests.add(status);
      return true;
    }

    await tester.pumpWidget(
      _testApp(
        _actions(bookingId: 'one', status: 'accepted', updater: updater),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('booking-complete-one')));
    await tester.pump();

    expect(requests, ['completed']);
    expect(find.text('Booking completed.'), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-loading-one')), findsOneWidget);
  });

  testWidgets('double tap sends one update for the same booking', (
    tester,
  ) async {
    final result = Completer<bool>();
    var calls = 0;
    Future<bool> updater(String bookingId, String status) {
      calls += 1;
      return result.future;
    }

    await tester.pumpWidget(
      _testApp(_actions(bookingId: 'one', status: 'pending', updater: updater)),
    );
    final accept = find.byKey(const ValueKey('booking-accept-one'));
    await tester.tap(accept);
    await tester.tap(accept);

    expect(calls, 1);
    result.complete(true);
    await tester.pump();
  });

  testWidgets('updating one booking does not disable another booking', (
    tester,
  ) async {
    final firstResult = Completer<bool>();
    final calls = <String>[];
    Future<bool> updater(String bookingId, String _) {
      calls.add(bookingId);
      return bookingId == 'one' ? firstResult.future : Future.value(true);
    }

    await tester.pumpWidget(
      _testApp(
        Column(
          children: [
            _actions(bookingId: 'one', status: 'pending', updater: updater),
            _actions(bookingId: 'two', status: 'pending', updater: updater),
          ],
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('booking-accept-one')));
    await tester.pump();

    expect(find.byKey(const ValueKey('booking-loading-one')), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-accept-two')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('booking-accept-two')));
    await tester.pump();

    expect(calls, ['one', 'two']);
    firstResult.complete(true);
    await tester.pump();
  });

  testWidgets('failure restores actions and shows an error', (tester) async {
    var calls = 0;
    Future<bool> updater(String bookingId, String status) async {
      calls += 1;
      throw Exception('callable failed');
    }

    await tester.pumpWidget(
      _testApp(_actions(bookingId: 'one', status: 'pending', updater: updater)),
    );
    await tester.tap(find.byKey(const ValueKey('booking-accept-one')));
    await tester.pump();

    expect(calls, 1);
    expect(find.byKey(const ValueKey('booking-loading-one')), findsNothing);
    expect(find.byKey(const ValueKey('booking-accept-one')), findsOneWidget);
    expect(
      find.text('Unable to update booking status. Try again.'),
      findsOneWidget,
    );
  });

  test('stream error takes precedence over an empty snapshot', () {
    expect(
      resolveBarberBookingListState(
        connectionState: ConnectionState.active,
        hasError: true,
        hasData: false,
        isEmpty: true,
      ),
      BarberBookingListState.error,
    );
  });
}
