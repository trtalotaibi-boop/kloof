import 'package:flutter_test/flutter_test.dart';
import 'package:kloof/auth/customer_auth_policy.dart';

void main() {
  group('Saudi mobile normalization', () {
    test('normalizes every supported format to +966', () {
      expect(normalizeSaudiMobileNumber('0501234567'), '+966501234567');
      expect(normalizeSaudiMobileNumber('501234567'), '+966501234567');
      expect(normalizeSaudiMobileNumber('+966501234567'), '+966501234567');
      expect(normalizeSaudiMobileNumber(' 0501234567 '), '+966501234567');
    });

    test('rejects invalid or unsupported numbers', () {
      expect(normalizeSaudiMobileNumber(''), isNull);
      expect(normalizeSaudiMobileNumber('050123456'), isNull);
      expect(normalizeSaudiMobileNumber('05012345678'), isNull);
      expect(normalizeSaudiMobileNumber('966501234567'), isNull);
      expect(normalizeSaudiMobileNumber('+966401234567'), isNull);
      expect(normalizeSaudiMobileNumber('050 123 4567'), isNull);
      expect(normalizeSaudiMobileNumber('abc'), isNull);
    });
  });

  group('welcome authentication isolation', () {
    test('customer uses phone authentication', () {
      expect(usesCustomerPhoneAuthentication('customer'), isTrue);
    });

    test('barber does not use customer phone authentication', () {
      expect(usesCustomerPhoneAuthentication('barber'), isFalse);
    });
  });

  group('authenticated routing', () {
    test('routes a customer with a valid profile to customer home', () {
      expect(
        resolveAuthenticatedDestination(
          profileExists: true,
          role: 'customer',
          hasPhoneNumber: true,
        ),
        AuthenticatedDestination.customerHome,
      );
    });

    test('does not enter home before a phone customer profile exists', () {
      expect(
        resolveAuthenticatedDestination(
          profileExists: false,
          role: null,
          hasPhoneNumber: true,
        ),
        AuthenticatedDestination.completeCustomerProfile,
      );
    });

    test('blocks a profile-less non-phone authentication session', () {
      expect(
        resolveAuthenticatedDestination(
          profileExists: false,
          role: null,
          hasPhoneNumber: false,
        ),
        AuthenticatedDestination.blocked,
      );
    });

    test('does not route an email-only customer session to home', () {
      expect(
        resolveAuthenticatedDestination(
          profileExists: true,
          role: 'customer',
          hasPhoneNumber: false,
        ),
        AuthenticatedDestination.blocked,
      );
    });

    test('keeps an existing barber profile on the barber dashboard', () {
      expect(
        resolveAuthenticatedDestination(
          profileExists: true,
          role: 'barber',
          hasPhoneNumber: false,
        ),
        AuthenticatedDestination.barberDashboard,
      );
    });

    test(
      'blocks a phone-authenticated barber profile from customer routing',
      () {
        expect(
          resolveAuthenticatedDestination(
            profileExists: true,
            role: 'barber',
            hasPhoneNumber: true,
          ),
          AuthenticatedDestination.blocked,
        );
      },
    );

    test('rejects a non-customer role from the customer sign-in flow', () {
      expect(
        resolveCustomerSignInDestination(profileExists: true, role: 'barber'),
        CustomerSignInDestination.blocked,
      );
      expect(
        resolveCustomerSignInDestination(profileExists: true, role: 'admin'),
        CustomerSignInDestination.blocked,
      );
    });
  });
}
