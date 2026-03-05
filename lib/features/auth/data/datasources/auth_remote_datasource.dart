import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/sign_up_result.dart';
import '../../domain/entities/user_entity.dart';

abstract class AuthRemoteDataSource {
  UserEntity? get currentUser;
  Stream<UserEntity?> get authStateChanges;

  Future<UserEntity> signIn({required String email, required String password});

  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  });

  Future<void>       resetPassword(String email);
  Future<UserEntity> verifyOtp({required String email, required String token});
  Future<void>       resendOtp(String email);
  Future<void>       signOut();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient _client;
  const AuthRemoteDataSourceImpl(this._client);

  @override
  UserEntity? get currentUser {
    final user = _client.auth.currentUser;
    return user != null ? _toEntity(user) : null;
  }

  @override
  Stream<UserEntity?> get authStateChanges =>
      _client.auth.onAuthStateChange.map((e) {
        final user = e.session?.user;
        return user != null ? _toEntity(user) : null;
      });

  @override
  Future<UserEntity> signIn({
    required String email,
    required String password,
  }) async {
    final res = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = res.user;
    if (user == null) throw const AuthException('No se pudo autenticar');
    return _toEntity(user);
  }

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          'phone_number': phoneNumber,
      },
    );
    return SignUpResult(
      user: res.user != null ? _toEntity(res.user!) : null,
      emailConfirmationRequired: res.session == null,
    );
  }

  @override
  Future<void> resetPassword(String email) =>
      _client.auth.resetPasswordForEmail(email);

  @override
  Future<UserEntity> verifyOtp({
    required String email,
    required String token,
  }) async {
    final res = await _client.auth.verifyOTP(
      type:  OtpType.signup,
      email: email,
      token: token,
    );
    final user = res.user;
    if (user == null) throw const AuthException('Código inválido o expirado');
    return _toEntity(user);
  }

  @override
  Future<void> resendOtp(String email) =>
      _client.auth.resend(type: OtpType.signup, email: email);

  @override
  Future<void> signOut() => _client.auth.signOut();

  UserEntity _toEntity(User user) => UserEntity(
        id:          user.id,
        email:       user.email ?? '',
        displayName: user.userMetadata?['full_name'] as String?,
        avatarUrl:   user.userMetadata?['avatar_url'] as String?,
        phoneNumber: user.userMetadata?['phone_number'] as String?,
        createdAt:   DateTime.parse(user.createdAt),
      );
}
