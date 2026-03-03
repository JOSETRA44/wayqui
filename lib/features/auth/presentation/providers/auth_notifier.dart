import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';

// ─── Dependency graph (manual DI, sin get_it para simplicidad) ───────────────

final _authDataSourceProvider = Provider(
  (ref) => AuthRemoteDataSourceImpl(ref.watch(supabaseClientProvider)),
  name: 'authDataSource',
);

final _authRepositoryProvider = Provider(
  (ref) => AuthRepositoryImpl(ref.watch(_authDataSourceProvider)),
  name: 'authRepository',
);

final _signInUseCaseProvider = Provider(
  (ref) => SignInUseCase(ref.watch(_authRepositoryProvider)),
  name: 'signInUseCase',
);

final _signOutUseCaseProvider = Provider(
  (ref) => SignOutUseCase(ref.watch(_authRepositoryProvider)),
  name: 'signOutUseCase',
);

// ─── Auth State ───────────────────────────────────────────────────────────────

/// Estado global de autenticación.
/// AsyncValue<UserEntity?>:
///   AsyncLoading → cargando
///   AsyncData(user) → autenticado
///   AsyncData(null) → no autenticado
///   AsyncError → error
final authProvider =
    AsyncNotifierProvider<AuthNotifier, UserEntity?>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<UserEntity?> {
  late SignInUseCase _signIn;
  late SignOutUseCase _signOut;

  @override
  Future<UserEntity?> build() async {
    _signIn = ref.watch(_signInUseCaseProvider);
    _signOut = ref.watch(_signOutUseCaseProvider);

    // Leer usuario actual desde la sesión activa de Supabase
    final repo = ref.watch(_authRepositoryProvider);
    return repo.currentUser;
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _signIn(SignInParams(email: email, password: password)),
    );
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _signOut();
      return null;
    });
  }

  /// Parseo de errores Supabase → mensajes en español para el usuario
  String parseError(Object error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('invalid') || msg.contains('credentials')) {
      return 'Email o contraseña incorrectos';
    }
    if (msg.contains('email not confirmed')) {
      return 'Confirma tu email antes de ingresar';
    }
    if (msg.contains('too many') || msg.contains('rate limit')) {
      return 'Demasiados intentos. Espera un momento';
    }
    if (msg.contains('network') || msg.contains('socket')) {
      return 'Sin conexión. Verifica tu internet';
    }
    return 'Error al iniciar sesión. Intenta de nuevo';
  }
}
