import '../entities/sign_up_result.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  UserEntity? get currentUser;
  Stream<UserEntity?> get authStateChanges;

  Future<UserEntity> signIn({
    required String email,
    required String password,
  });

  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  });

  Future<void> resetPassword(String email);

  /// Verifica el OTP de 6 dígitos enviado al email tras el registro.
  Future<UserEntity> verifyOtp({
    required String email,
    required String token,
  });

  /// Reenvía el OTP al email indicado.
  Future<void> resendOtp(String email);

  Future<void> signOut();
}
