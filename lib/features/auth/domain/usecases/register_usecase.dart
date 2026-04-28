import '../entities/auth_session.dart';
import '../entities/registration_request.dart';
import '../repositories/auth_repository.dart';

class RegisterUseCase {
  const RegisterUseCase(this.repository);

  final AuthRepository repository;

  Future<AuthSession> call(RegistrationRequest request) {
    return repository.register(request);
  }
}
