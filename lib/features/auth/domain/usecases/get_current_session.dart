import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

class GetCurrentSession {
  const GetCurrentSession(this.repository);

  final AuthRepository repository;

  Future<AuthSession> call() => repository.getCurrentSession();
}
