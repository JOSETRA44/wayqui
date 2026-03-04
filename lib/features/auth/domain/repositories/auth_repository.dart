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

  Future<void> signOut();
}
