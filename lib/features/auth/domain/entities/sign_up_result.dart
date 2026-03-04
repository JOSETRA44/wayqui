import 'user_entity.dart';

/// Resultado del registro de usuario.
/// [user] está presente si la sesión se inició automáticamente.
/// [emailConfirmationRequired] es true si el usuario debe confirmar su email.
class SignUpResult {
  final UserEntity? user;
  final bool emailConfirmationRequired;

  const SignUpResult({
    this.user,
    required this.emailConfirmationRequired,
  });
}
