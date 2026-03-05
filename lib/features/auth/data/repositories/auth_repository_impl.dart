import '../../domain/entities/sign_up_result.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _ds;
  const AuthRepositoryImpl(this._ds);

  @override
  UserEntity? get currentUser => _ds.currentUser;

  @override
  Stream<UserEntity?> get authStateChanges => _ds.authStateChanges;

  @override
  Future<UserEntity> signIn({required String email, required String password}) =>
      _ds.signIn(email: email, password: password);

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) =>
      _ds.signUp(
        email:       email,
        password:    password,
        fullName:    fullName,
        phoneNumber: phoneNumber,
      );

  @override
  Future<void> resetPassword(String email) => _ds.resetPassword(email);

  @override
  Future<UserEntity> verifyOtp({required String email, required String token}) =>
      _ds.verifyOtp(email: email, token: token);

  @override
  Future<void> resendOtp(String email) => _ds.resendOtp(email);

  @override
  Future<void> signOut() => _ds.signOut();
}
