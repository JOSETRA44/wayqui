import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/reset_password_usecase.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';
import '../../domain/usecases/sign_up_usecase.dart';

// ─── Dependency graph ─────────────────────────────────────────────────────────

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
);
final _signUpUseCaseProvider = Provider(
  (ref) => SignUpUseCase(ref.watch(_authRepositoryProvider)),
);
final _signOutUseCaseProvider = Provider(
  (ref) => SignOutUseCase(ref.watch(_authRepositoryProvider)),
);
final _resetPasswordUseCaseProvider = Provider(
  (ref) => ResetPasswordUseCase(ref.watch(_authRepositoryProvider)),
);

// ─── Auth State ───────────────────────────────────────────────────────────────

/// `AsyncValue<UserEntity?>`:
///   AsyncLoading      → operación en curso
///   AsyncData(user)   → autenticado
///   AsyncData(null)   → no autenticado / registro pendiente de confirmación
///   AsyncError(e)     → error
final authProvider =
    AsyncNotifierProvider<AuthNotifier, UserEntity?>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<UserEntity?> {
  @override
  Future<UserEntity?> build() async {
    final repo = ref.read(_authRepositoryProvider);

    // Subscribe to Supabase auth state stream so the provider stays reactive
    // after the initial build: handles INITIAL_SESSION (cold-start session
    // restore), TOKEN_REFRESHED, and any sign-in/out triggered externally.
    final sub = repo.authStateChanges.listen((user) {
      // Skip updates while an explicit operation (signIn, signOut, verifyOtp)
      // is in progress — those methods manage state themselves.
      if (!state.isLoading) state = AsyncData(user);
    });
    ref.onDispose(sub.cancel);

    // Synchronous read: valid because Supabase.initialize() is awaited before
    // runApp(), so the persisted session is already available at this point.
    return repo.currentUser;
  }

  // ── Sign In ───────────────────────────────────────────────────
  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(_signInUseCaseProvider)
          .call(SignInParams(email: email, password: password)),
    );
  }

  // ── Sign Up ───────────────────────────────────────────────────
  /// Retorna true si se requiere confirmación de email.
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) async {
    state = const AsyncLoading();
    bool confirmationRequired = false;
    state = await AsyncValue.guard(() async {
      final result = await ref.read(_signUpUseCaseProvider).call(
            SignUpParams(
              email:       email,
              password:    password,
              fullName:    fullName,
              phoneNumber: phoneNumber,
            ),
          );
      confirmationRequired = result.emailConfirmationRequired;
      return result.user; // null si requiere confirmación
    });
    return confirmationRequired;
  }

  // ── OTP Verify ────────────────────────────────────────────────
  /// Verifica el código OTP y actualiza el estado a autenticado.
  Future<void> verifyOtp({
    required String email,
    required String token,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() =>
        ref.read(_authRepositoryProvider).verifyOtp(email: email, token: token));
  }

  /// Reenvía el OTP al email (máx 1 vez por minuto en Supabase).
  Future<void> resendOtp(String email) =>
      ref.read(_authRepositoryProvider).resendOtp(email);

  // ── Reset Password ────────────────────────────────────────────
  Future<void> resetPassword(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(_resetPasswordUseCaseProvider).call(email);
      return ref.read(_authRepositoryProvider).currentUser; // mantiene null
    });
  }

  // ── Sign Out ──────────────────────────────────────────────────
  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(_signOutUseCaseProvider).call();
      return null;
    });
  }

  // ── Error parser ──────────────────────────────────────────────
  String parseError(Object error) {
    final msg = error.toString().toLowerCase();
    // Supabase devuelve este error cuando el body llega sin email/password
    if (msg.contains('anonymous') || msg.contains('anonymous_provider_disabled')) {
      return 'Completa todos los campos del registro antes de continuar.';
    }
    if (msg.contains('invalid') || msg.contains('credentials')) {
      return 'Email o contraseña incorrectos';
    }
    if (msg.contains('already registered') || msg.contains('already been registered')) {
      return 'Este email ya tiene una cuenta. Inicia sesión.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Confirma tu email antes de ingresar';
    }
    if (msg.contains('weak password') || msg.contains('should be at least')) {
      return 'La contraseña es muy débil. Usa al menos 8 caracteres.';
    }
    if (msg.contains('too many') || msg.contains('rate limit')) {
      return 'Demasiados intentos. Espera un momento';
    }
    if (msg.contains('network') || msg.contains('socket') || msg.contains('connection')) {
      return 'Sin conexión. Verifica tu internet';
    }
    if (msg.contains('user not found')) {
      return 'No existe una cuenta con ese email';
    }
    return 'Algo salió mal. Intenta de nuevo ($error)';
  }
}
