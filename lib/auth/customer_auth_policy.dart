enum AuthenticatedDestination {
  customerHome,
  barberDashboard,
  completeCustomerProfile,
  blocked,
}

enum CustomerSignInDestination { customerHome, completeProfile, blocked }

bool usesCustomerPhoneAuthentication(String selectedRole) {
  return selectedRole.trim().toLowerCase() == 'customer';
}

String? normalizeSaudiMobileNumber(String input) {
  final value = input.trim();

  if (RegExp(r'^05\d{8}$').hasMatch(value)) {
    return '+966${value.substring(1)}';
  }
  if (RegExp(r'^5\d{8}$').hasMatch(value)) {
    return '+966$value';
  }
  if (RegExp(r'^\+9665\d{8}$').hasMatch(value)) {
    return value;
  }

  return null;
}

AuthenticatedDestination resolveAuthenticatedDestination({
  required bool profileExists,
  required String? role,
  required bool hasPhoneNumber,
}) {
  if (!profileExists) {
    return hasPhoneNumber
        ? AuthenticatedDestination.completeCustomerProfile
        : AuthenticatedDestination.blocked;
  }

  switch (role?.trim().toLowerCase()) {
    case 'customer':
      return hasPhoneNumber
          ? AuthenticatedDestination.customerHome
          : AuthenticatedDestination.blocked;
    case 'barber':
      return hasPhoneNumber
          ? AuthenticatedDestination.blocked
          : AuthenticatedDestination.barberDashboard;
    default:
      return AuthenticatedDestination.blocked;
  }
}

CustomerSignInDestination resolveCustomerSignInDestination({
  required bool profileExists,
  required String? role,
}) {
  if (!profileExists) {
    return CustomerSignInDestination.completeProfile;
  }

  return role?.trim().toLowerCase() == 'customer'
      ? CustomerSignInDestination.customerHome
      : CustomerSignInDestination.blocked;
}
