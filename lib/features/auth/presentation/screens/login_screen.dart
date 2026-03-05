import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/comic_button.dart';
import '../../../../shared/widgets/comic_text_field.dart';
import '../providers/auth_notifier.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    HapticFeedback.mediumImpact(); // feedback háptico al enviar
    ref.read(authProvider.notifier).signIn(
          email:    _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);

    // Mostrar error si hay uno
    ref.listen<AsyncValue<dynamic>>(authProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        HapticFeedback.vibrate();
        final raw = error.toString().toLowerCase();
        final isUnconfirmed = raw.contains('email not confirmed')
            || raw.contains('email_not_confirmed');

        if (isUnconfirmed) {
          // El usuario existe pero no confirmó su email.
          // Ofrecemos navegar directamente a la pantalla de OTP.
          final email = _emailCtrl.text.trim();
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(SnackBar(
              content: const Text('Confirma tu email antes de ingresar'),
              backgroundColor: theme.colorScheme.error,
              duration: const Duration(seconds: 8),
              action: email.isNotEmpty
                  ? SnackBarAction(
                      label: 'Verificar email',
                      textColor: theme.colorScheme.onError,
                      onPressed: () => context.push(
                        '${AppRoutes.otpVerify}?email=${Uri.encodeComponent(email)}',
                      ),
                    )
                  : null,
            ));
        } else {
          final msg = ref.read(authProvider.notifier).parseError(error);
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(SnackBar(
              content: Text(msg),
              backgroundColor: theme.colorScheme.error,
            ));
        }
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacing24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppConstants.spacing64),
                const _LogoHeader(),
                const SizedBox(height: AppConstants.spacing48),
                _buildEmailField(theme),
                const SizedBox(height: AppConstants.spacing16),
                _buildPasswordField(theme),
                const SizedBox(height: AppConstants.spacing8),
                _buildForgotLink(theme),
                const SizedBox(height: AppConstants.spacing32),
                ComicButton(
                  label: 'Iniciar sesión',
                  onPressed: _submit,
                  isLoading: authState.isLoading,
                  width: double.infinity,
                  animateDelay: 600,
                ),
                const SizedBox(height: AppConstants.spacing32),
                _buildRegisterRow(theme),
                const SizedBox(height: AppConstants.spacing32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField(ThemeData theme) {
    return ComicTextField(
      label: 'Email',
      hint: 'tu@email.com',
      controller: _emailCtrl,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
      prefixIcon: FaIcon(
        FontAwesomeIcons.envelope,
        size: 16,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'El email es requerido';
        final valid = RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$');
        if (!valid.hasMatch(v.trim())) return 'Ingresa un email válido';
        return null;
      },
    )
        .animate()
        .fadeIn(delay: 300.ms, duration: 350.ms)
        .slideX(begin: -0.08, end: 0);
  }

  Widget _buildPasswordField(ThemeData theme) {
    return ComicTextField(
      label: 'Contraseña',
      hint: '••••••••',
      controller: _passwordCtrl,
      isPassword: true,
      focusNode: _passwordFocus,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
      prefixIcon: FaIcon(
        FontAwesomeIcons.lock,
        size: 16,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'La contraseña es requerida';
        if (v.length < 6) return 'Mínimo 6 caracteres';
        return null;
      },
    )
        .animate()
        .fadeIn(delay: 400.ms, duration: 350.ms)
        .slideX(begin: -0.08, end: 0);
  }

  Widget _buildForgotLink(ThemeData theme) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () => context.push(AppRoutes.forgotPassword),
        child: Text(
          '¿Olvidaste tu contraseña?',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ).animate().fadeIn(delay: 500.ms, duration: 350.ms);
  }

  Widget _buildRegisterRow(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '¿No tienes cuenta? ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        GestureDetector(
          onTap: () => context.push(AppRoutes.register),
          child: Text(
            'Regístrate',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 700.ms, duration: 350.ms);
  }
}

// ─── Header separado para evitar rebuilds innecesarios ────────────────────────
class _LogoHeader extends StatelessWidget {
  const _LogoHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        RepaintBoundary(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius:
                  BorderRadius.circular(AppConstants.borderRadiusLarge),
              border: Border.all(
                color: theme.colorScheme.outline,
                width: AppConstants.borderWidth,
              ),
            ),
            child: Center(
              child: FaIcon(
                FontAwesomeIcons.locationDot,
                color: theme.colorScheme.onPrimary,
                size: 36,
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .scale(begin: const Offset(0.75, 0.75)),
        ),
        const SizedBox(height: AppConstants.spacing16),
        Text(
          AppConstants.appName.toUpperCase(),
          style: theme.textTheme.headlineLarge,
        )
            .animate()
            .fadeIn(delay: 100.ms, duration: 400.ms)
            .slideY(begin: -0.15, end: 0),
        const SizedBox(height: AppConstants.spacing8),
        Text(
          'Préstamos entre amigos — simple y seguro',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
      ],
    );
  }
}
