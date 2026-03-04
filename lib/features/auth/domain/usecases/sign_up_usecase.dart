import '../entities/sign_up_result.dart';
import '../repositories/auth_repository.dart';

class SignUpParams {
  final String  email;
  final String  password;
  final String  fullName;
  final String? phoneNumber;

  const SignUpParams({
    required this.email,
    required this.password,
    required this.fullName,
    this.phoneNumber,
  });
}

class SignUpUseCase {
  final AuthRepository _repo;
  const SignUpUseCase(this._repo);

  Future<SignUpResult> call(SignUpParams p) => _repo.signUp(
        email:       p.email,
        password:    p.password,
        fullName:    p.fullName,
        phoneNumber: p.phoneNumber,
      );
}
