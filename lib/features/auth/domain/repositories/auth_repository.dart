import '../../../../models/account_status.dart';
import '../../../../models/app_user.dart';
import '../../../../models/user_role.dart';
import '../entities/auth_session.dart';
import '../entities/registration_request.dart';

abstract class AuthRepository {
  Future<AuthSession> getCurrentSession();
  Future<AuthSession> signInWithEmail({
    required String email,
    required String password,
    UserRole? role,
  });
  Future<AuthSession> sendPhoneOtp({
    required String phoneNumber,
    required UserRole role,
  });
  Future<AuthSession> verifyPhoneOtp({
    required String otp,
    required UserRole role,
    required String phoneNumber,
  });
  Future<AuthSession> register(RegistrationRequest request);
  Future<AuthSession> signOut();
  Stream<List<AppUser>> watchUsers();
  Stream<List<AppUser>> watchPendingUsers();
  Future<void> updateAccountStatus({
    required String userId,
    required AccountStatus status,
    String? rejectionReason,
  });
}
