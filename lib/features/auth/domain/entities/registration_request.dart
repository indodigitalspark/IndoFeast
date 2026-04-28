import '../../../../models/user_role.dart';

class RegistrationRequest {
  const RegistrationRequest({
    required this.displayName,
    required this.email,
    required this.phoneNumber,
    required this.password,
    required this.role,
    required this.otp,
    this.documentBytes,
    this.documentName,
    this.businessName,
    this.vehicleLabel,
  });

  final String displayName;
  final String email;
  final String phoneNumber;
  final String password;
  final UserRole role;
  final String otp;
  final List<int>? documentBytes;
  final String? documentName;
  final String? businessName;
  final String? vehicleLabel;
}
