import '../../../../models/user_role.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

class SignInUseCase {
  const SignInUseCase(this.repository);

  final AuthRepository repository;

  Future<AuthSession> call({
    required String email,
    required String password,
    UserRole? role,
  }) {
    return repository.signInWithEmail(
      email: email,
      password: password,
      role: role,
    );
  }
}
