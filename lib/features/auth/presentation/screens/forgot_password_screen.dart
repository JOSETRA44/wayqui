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

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _emailCtrl  = TextEditingController();
  bool _emailSent   = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    HapticFeedback.mediumImpact();

    await ref.read(authProvider.notifier).resetPassword(_emailCtrl.text.trim());

    if (!mounted) return;
    if (ref.read(authProvider).hasError) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('No se pudo enviar el correo. Verifica el email.'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
      return;
    }
    setState(() => _emailSent = true);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.arrowLeft, size: 18),
          onPressed: () => context.go(AppRoutes.login),
        ),
        title: const Text('Recuperar contraseña'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacing24),
          child: _emailSent
              ? _SuccessView(email: _emailCtrl.text)
              : _FormView(
                  formKey:   _formKey,
                  emailCtrl: _emailCtrl,
                  isLoading: authState.isLoading,
                  onSubmit:  _submit,
                  theme:     theme,
                ),
        ),
      ),
    );
  }
}

class _FormView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final bool isLoading;
  final VoidCallback onSubmit;
  final ThemeData theme;

  const _FormView({
    required this.formKey,
    required this.emailCtrl,
    required this.isLoading,
    required this.onSubmit,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppConstants.spacing32),
          const FaIcon(
            FontAwesomeIcons.key,
            size: 48,
            color: Color(0xFF5B3FE8),
          ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.7, 0.7)),
          const SizedBox(height: AppConstants.spacing24),
          Text(
            'Ingresa tu email y te enviaremos\nun enlace para crear una nueva contraseña.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 150.ms),
          const SizedBox(height: AppConstants.spacing32),
          ComicTextField(
            label: 'Email',
            hint: 'tu@email.com',
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSubmit(),
            prefixIcon: FaIcon(
              FontAwesomeIcons.envelope,
              size: 15,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'El email es requerido';
              if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$')
                  .hasMatch(v.trim())) {
                return 'Ingresa un email válido';
              }
              return null;
            },
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
          const SizedBox(height: AppConstants.spacing32),
          ComicButton(
            label: 'Enviar enlace',
            onPressed: onSubmit,
            isLoading: isLoading,
            width: double.infinity,
            animateDelay: 300,
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final String email;
  const _SuccessView({required this.email});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FaIcon(
          FontAwesomeIcons.circleCheck,
          size: 64,
          color: Color(0xFF1DB954),
        )
            .animate()
            .scale(begin: const Offset(0.5, 0.5))
            .fadeIn(duration: 500.ms),
        const SizedBox(height: AppConstants.spacing32),
        Text(
          'Enlace enviado',
          style: theme.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 300.ms),
        const SizedBox(height: AppConstants.spacing12),
        Text(
          'Revisa tu bandeja en\n$email',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 400.ms),
        const SizedBox(height: AppConstants.spacing48),
        ComicButton(
          label: 'Volver al inicio',
          onPressed: () => context.go(AppRoutes.login),
          variant: ComicButtonVariant.outlined,
          width: double.infinity,
          animateDelay: 500,
        ),
      ],
    );
  }
}
