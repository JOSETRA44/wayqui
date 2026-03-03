import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _dataSource;

  const AuthRepositoryImpl(this._dataSource);

  @override
  UserEntity? get currentUser => _dataSource.currentUser;

  @override
  Stream<UserEntity?> get authStateChanges => _dataSource.authStateChanges;

  @override
  Future<UserEntity> signIn({required String email, required String password}) {
    return _dataSource.signIn(email: email, password: password);
  }

  @override
  Future<void> signOut() => _dataSource.signOut();
}
