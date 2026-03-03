import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SignInParams {
  final String email;
  final String password;

  const SignInParams({required this.email, required this.password});
}

class SignInUseCase {
  final AuthRepository _repository;

  const SignInUseCase(this._repository);

  Future<UserEntity> call(SignInParams params) {
    return _repository.signIn(
      email: params.email,
      password: params.password,
    );
  }
}
