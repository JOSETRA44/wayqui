import '../repositories/auth_repository.dart';

class ResetPasswordUseCase {
  final AuthRepository _repo;
  const ResetPasswordUseCase(this._repo);

  Future<void> call(String email) => _repo.resetPassword(email);
}
