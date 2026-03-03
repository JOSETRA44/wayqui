import 'package:flutter/foundation.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final SignInUseCase _signIn;
  final SignOutUseCase _signOut;

  AuthStatus _status;
  UserEntity? _user;
  String? _errorMessage;

  AuthProvider({
    required SignInUseCase signInUseCase,
    required SignOutUseCase signOutUseCase,
    UserEntity? initialUser,
  })  : _signIn = signInUseCase,
        _signOut = signOutUseCase,
        _user = initialUser,
        _status = initialUser != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated;

  AuthStatus get status => _status;
  UserEntity? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> signIn({required String email, required String password}) async {
    _update(AuthStatus.loading);
    try {
      _user = await _signIn(SignInParams(email: email, password: password));
      _errorMessage = null;
      _update(AuthStatus.authenticated);
    } catch (e) {
      _errorMessage = _parseError(e);
      _update(AuthStatus.error);
    }
  }

  Future<void> signOut() async {
    _update(AuthStatus.loading);
    try {
      await _signOut();
      _user = null;
      _errorMessage = null;
      _update(AuthStatus.unauthenticated);
    } catch (e) {
      _errorMessage = _parseError(e);
      _update(AuthStatus.error);
    }
  }

  void clearError() {
    _errorMessage = null;
    _status =
        _user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    notifyListeners();
  }

  void _update(AuthStatus status) {
    _status = status;
    notifyListeners();
  }

  String _parseError(Object error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('invalid') || msg.contains('credentials')) {
      return 'Email o contraseña incorrectos';
    }
    if (msg.contains('email not confirmed')) {
      return 'Confirma tu email antes de iniciar sesión';
    }
    if (msg.contains('too many requests') || msg.contains('rate limit')) {
      return 'Demasiados intentos. Espera un momento';
    }
    if (msg.contains('network') || msg.contains('socket')) {
      return 'Sin conexión. Verifica tu internet';
    }
    return 'Error al iniciar sesión. Intenta de nuevo';
  }
}
