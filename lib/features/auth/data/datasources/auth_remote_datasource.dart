import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/user_entity.dart';

abstract class AuthRemoteDataSource {
  UserEntity? get currentUser;
  Stream<UserEntity?> get authStateChanges;

  Future<UserEntity> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();
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
  Stream<UserEntity?> get authStateChanges {
    return _client.auth.onAuthStateChange.map((event) {
      final user = event.session?.user;
      return user != null ? _toEntity(user) : null;
    });
  }

  @override
  Future<UserEntity> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) throw const AuthException('No se pudo autenticar');
    return _toEntity(user);
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  UserEntity _toEntity(User user) => UserEntity(
        id: user.id,
        email: user.email ?? '',
        displayName: user.userMetadata?['full_name'] as String?,
        avatarUrl: user.userMetadata?['avatar_url'] as String?,
        createdAt: DateTime.parse(user.createdAt),
      );
}
