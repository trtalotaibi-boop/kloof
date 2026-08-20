import 'package:flutter_test/flutter_test.dart';
import 'package:kloof/screens/edit_barber_profile_screen.dart';

void main() {
  group('barber coordinate validation', () {
    test('accepts a valid coordinate pair and both boundary pairs', () {
      final location = validateBarberCoordinates('21.4225', '39.8262');
      expect(location.isValid, isTrue);
      expect(location.latitude, 21.4225);
      expect(location.longitude, 39.8262);

      expect(validateBarberCoordinates('-90', '-180').isValid, isTrue);
      expect(validateBarberCoordinates('90', '180').isValid, isTrue);
    });

    test('accepts two empty fields to remove a saved location', () {
      final location = validateBarberCoordinates('', '');
      expect(location.isValid, isTrue);
      expect(location.latitude, isNull);
      expect(location.longitude, isNull);
    });

    test('requires latitude and longitude together', () {
      expect(
        validateBarberCoordinates('21.4225', '').error,
        BarberLocationValidationError.pairRequired,
      );
      expect(
        validateBarberCoordinates('', '39.8262').error,
        BarberLocationValidationError.pairRequired,
      );
    });

    test('rejects invalid and out-of-range latitude', () {
      for (final latitude in ['invalid', 'NaN', '-90.1', '90.1']) {
        expect(
          validateBarberCoordinates(latitude, '39.8262').error,
          BarberLocationValidationError.invalidLatitude,
        );
      }
    });

    test('rejects invalid and out-of-range longitude', () {
      for (final longitude in ['invalid', 'NaN', '-180.1', '180.1']) {
        expect(
          validateBarberCoordinates('21.4225', longitude).error,
          BarberLocationValidationError.invalidLongitude,
        );
      }
    });
  });
}
