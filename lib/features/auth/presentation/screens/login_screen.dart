import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/comic_button.dart';
import '../../../../shared/widgets/comic_text_field.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
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
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthProvider>().signIn(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.status == AuthStatus.error && auth.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showError(context, auth.errorMessage!);
        context.read<AuthProvider>().clearError();
      });
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacing24,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppConstants.spacing64),
                _Header(),
                const SizedBox(height: AppConstants.spacing48),
                _buildEmailField(),
                const SizedBox(height: AppConstants.spacing16),
                _buildPasswordField(),
                const SizedBox(height: AppConstants.spacing8),
                _buildForgotLink(context),
                const SizedBox(height: AppConstants.spacing32),
                ComicButton(
                  label: 'Iniciar sesión',
                  onPressed: _submit,
                  isLoading: auth.isLoading,
                  width: double.infinity,
                  animateDelay: 600,
                ),
                const SizedBox(height: AppConstants.spacing32),
                _buildRegisterRow(context),
                const SizedBox(height: AppConstants.spacing32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
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
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'El email es requerido';
        if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$')
            .hasMatch(v.trim())) {
          return 'Ingresa un email válido';
        }
        return null;
      },
    )
        .animate()
        .fadeIn(delay: 300.ms, duration: 350.ms)
        .slideX(begin: -0.08, end: 0);
  }

  Widget _buildPasswordField() {
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
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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

  Widget _buildForgotLink(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          // TODO: navigate to forgot password screen
        },
        child: Text(
          '¿Olvidaste tu contraseña?',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 500.ms, duration: 350.ms);
  }

  Widget _buildRegisterRow(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '¿No tienes cuenta? ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        GestureDetector(
          onTap: () {
            // TODO: navigate to register screen
          },
          child: Text(
            'Regístrate',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(delay: 700.ms, duration: 350.ms);
  }

  void _showError(BuildContext ctx, String message) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(ctx).colorScheme.error,
      ),
    );
  }
}

// ─── Header separado para mantener el build limpio ───────────────────────────
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
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
        const SizedBox(height: AppConstants.spacing16),
        Text(
          AppConstants.appName.toUpperCase(),
          style: theme.textTheme.headlineLarge,
          textAlign: TextAlign.center,
        )
            .animate()
            .fadeIn(delay: 100.ms, duration: 400.ms)
            .slideY(begin: -0.15, end: 0),
        const SizedBox(height: AppConstants.spacing8),
        Text(
          'Inicia sesión para continuar',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.55),
          ),
          textAlign: TextAlign.center,
        )
            .animate()
            .fadeIn(delay: 200.ms, duration: 400.ms),
      ],
    );
  }
}
