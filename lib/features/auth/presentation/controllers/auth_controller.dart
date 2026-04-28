import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/account_status.dart';
import '../../../../models/app_user.dart';
import '../../../../models/user_role.dart';
import '../../data/datasources/firebase_auth_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/registration_request.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/get_current_session.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../domain/usecases/send_phone_otp_usecase.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';
import '../../domain/usecases/verify_phone_otp_usecase.dart';

final authDataSourceProvider = Provider<FirebaseAuthDataSource>(
  (ref) => FirebaseAuthDataSource(),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(authDataSourceProvider)),
);

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession>(AuthController.new);

final usersStreamProvider = StreamProvider<List<AppUser>>(
  (ref) => ref.watch(authRepositoryProvider).watchUsers(),
);

final pendingUsersStreamProvider = StreamProvider<List<AppUser>>(
  (ref) => ref.watch(authRepositoryProvider).watchPendingUsers(),
);

final accountStatusControllerProvider = Provider<AccountStatusController>(
  (ref) => AccountStatusController(ref),
);

class AuthController extends AsyncNotifier<AuthSession> {
  late final GetCurrentSession _getCurrentSession;
  late final SignInUseCase _signIn;
  late final SendPhoneOtpUseCase _sendPhoneOtp;
  late final VerifyPhoneOtpUseCase _verifyPhoneOtp;
  late final RegisterUseCase _register;
  late final SignOutUseCase _signOut;

  @override
  Future<AuthSession> build() async {
    final repository = ref.watch(authRepositoryProvider);
    _getCurrentSession = GetCurrentSession(repository);
    _signIn = SignInUseCase(repository);
    _sendPhoneOtp = SendPhoneOtpUseCase(repository);
    _verifyPhoneOtp = VerifyPhoneOtpUseCase(repository);
    _register = RegisterUseCase(repository);
    _signOut = SignOutUseCase(repository);

    return _getCurrentSession();
  }

  Future<AuthSession?> signInWithEmail({
    required String email,
    required String password,
    UserRole? role,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _signIn(email: email, password: password, role: role),
    );
    return state.valueOrNull;
  }

  Future<AuthSession?> sendPhoneOtp({
    required String phoneNumber,
    required UserRole role,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _sendPhoneOtp(phoneNumber: phoneNumber, role: role),
    );
    return state.valueOrNull;
  }

  Future<AuthSession?> verifyPhoneOtp({
    required String otp,
    required UserRole role,
    required String phoneNumber,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _verifyPhoneOtp(otp: otp, role: role, phoneNumber: phoneNumber),
    );
    return state.valueOrNull;
  }

  Future<AuthSession?> register(RegistrationRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _register(request));
    return state.valueOrNull;
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_signOut.call);
  }
}

class AccountStatusController {
  const AccountStatusController(this.ref);

  final Ref ref;

  Future<void> approveUser(String userId) {
    return ref
        .read(authRepositoryProvider)
        .updateAccountStatus(userId: userId, status: AccountStatus.approved);
  }

  Future<void> rejectUser(String userId, {String? reason}) {
    return ref
        .read(authRepositoryProvider)
        .updateAccountStatus(
          userId: userId,
          status: AccountStatus.rejected,
          rejectionReason: reason,
        );
  }
}
