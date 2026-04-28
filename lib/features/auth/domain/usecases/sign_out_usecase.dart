import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

class SignOutUseCase {
  const SignOutUseCase(this.repository);

  final AuthRepository repository;

  Future<AuthSession> call() => repository.signOut();
}
