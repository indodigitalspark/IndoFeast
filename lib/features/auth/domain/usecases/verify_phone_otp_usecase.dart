import '../../../../models/user_role.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

class VerifyPhoneOtpUseCase {
  const VerifyPhoneOtpUseCase(this.repository);

  final AuthRepository repository;

  Future<AuthSession> call({
    required String otp,
    required UserRole role,
    required String phoneNumber,
  }) {
    return repository.verifyPhoneOtp(
      otp: otp,
      role: role,
      phoneNumber: phoneNumber,
    );
  }
}
