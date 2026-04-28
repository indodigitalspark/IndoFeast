import '../../../../models/account_status.dart';
import '../../../../models/app_user.dart';
import '../../../../models/user_role.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/registration_request.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/firebase_auth_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this.dataSource);

  final FirebaseAuthDataSource dataSource;

  @override
  Future<AuthSession> getCurrentSession() => dataSource.getCurrentSession();

  @override
  Future<AuthSession> signInWithEmail({
    required String email,
    required String password,
    UserRole? role,
  }) {
    return dataSource.signIn(email: email, password: password, role: role);
  }

  @override
  Future<AuthSession> sendPhoneOtp({
    required String phoneNumber,
    required UserRole role,
  }) {
    return dataSource.sendPhoneOtp(phoneNumber: phoneNumber, role: role);
  }

  @override
  Future<AuthSession> verifyPhoneOtp({
    required String otp,
    required UserRole role,
    required String phoneNumber,
  }) {
    return dataSource.verifyPhoneOtp(
      otp: otp,
      role: role,
      phoneNumber: phoneNumber,
    );
  }

  @override
  Future<AuthSession> register(RegistrationRequest request) {
    return dataSource.register(request);
  }

  @override
  Future<AuthSession> signOut() => dataSource.signOut();

  @override
  Stream<List<AppUser>> watchUsers() => dataSource.watchUsers();

  @override
  Stream<List<AppUser>> watchPendingUsers() => dataSource.watchPendingUsers();

  @override
  Future<void> updateAccountStatus({
    required String userId,
    required AccountStatus status,
    String? rejectionReason,
  }) {
    return dataSource.updateAccountStatus(
      userId: userId,
      status: status,
      rejectionReason: rejectionReason,
    );
  }
}
