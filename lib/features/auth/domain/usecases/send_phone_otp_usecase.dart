import '../../../../models/user_role.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

class SendPhoneOtpUseCase {
  const SendPhoneOtpUseCase(this.repository);

  final AuthRepository repository;

  Future<AuthSession> call({
    required String phoneNumber,
    required UserRole role,
  }) {
    return repository.sendPhoneOtp(phoneNumber: phoneNumber, role: role);
  }
}
