import '../entities/user_entity.dart';

abstract class AuthRepository {
  UserEntity? get currentUser;
  Stream<UserEntity?> get authStateChanges;

  Future<UserEntity> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();
}
