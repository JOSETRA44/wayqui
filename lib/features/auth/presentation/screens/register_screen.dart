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
import '../../../../shared/widgets/password_strength_indicator.dart';
import '../providers/auth_notifier.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _nameCtrl      = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _passwordCtrl  = TextEditingController();
  final _confirmCtrl   = TextEditingController();
  final _emailFocus    = FocusNode();
  final _phoneFocus    = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus  = FocusNode();

  bool _termsAccepted = false;
  bool _emailConfSent = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_termsAccepted) {
      _showSnack('Debes aceptar los términos para continuar',
          isError: true);
      return;
    }
    HapticFeedback.mediumImpact();

    final confirmNeeded = await ref.read(authProvider.notifier).signUp(
          email:       _emailCtrl.text.trim(),
          password:    _passwordCtrl.text,
          fullName:    _nameCtrl.text.trim(),
          phoneNumber: _phoneCtrl.text.trim().isNotEmpty
              ? _phoneCtrl.text.trim()
              : null,
        );

    if (!mounted) return;

    if (ref.read(authProvider).hasError) {
      final err = ref.read(authProvider.notifier).parseError(
            ref.read(authProvider).error!,
          );
      _showSnack(err, isError: true);
      return;
    }

    if (confirmNeeded) {
      setState(() => _emailConfSent = true);
      HapticFeedback.lightImpact();
    }
    // Si no necesita confirmación → router redirige a /home automáticamente
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final authState = ref.watch(authProvider);

    if (_emailConfSent) return _EmailConfirmationSent(email: _emailCtrl.text);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.arrowLeft, size: 18),
          onPressed: () => context.go(AppRoutes.login),
        ),
        title: const Text('Crear cuenta'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacing24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppConstants.spacing32),
                _buildSectionHeader(theme, 'Datos personales'),
                const SizedBox(height: AppConstants.spacing16),
                ComicTextField(
                  label: 'Nombre completo',
                  hint: 'Juan Pérez',
                  controller: _nameCtrl,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                  prefixIcon: _icon(FontAwesomeIcons.user),
                  validator: (v) {
                    if (v == null || v.trim().length < 2) {
                      return 'Ingresa tu nombre completo';
                    }
                    return null;
                  },
                ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.06),

                const SizedBox(height: AppConstants.spacing16),
                ComicTextField(
                  label: 'Email',
                  hint: 'tu@email.com',
                  controller: _emailCtrl,
                  focusNode: _emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
                  prefixIcon: _icon(FontAwesomeIcons.envelope),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'El email es requerido';
                    }
                    if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(v.trim())) {
                      return 'Ingresa un email válido';
                    }
                    return null;
                  },
                ).animate().fadeIn(delay: 150.ms).slideX(begin: -0.06),

                const SizedBox(height: AppConstants.spacing16),
                ComicTextField(
                  label: 'Teléfono (para Yape/Plin)',
                  hint: '987 654 321',
                  controller: _phoneCtrl,
                  focusNode: _phoneFocus,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                  prefixIcon: _icon(FontAwesomeIcons.mobileScreen),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null; // opcional
                    final clean = v.replaceAll(RegExp(r'\s'), '');
                    if (!RegExp(r'^9\d{8}$').hasMatch(clean)) {
                      return 'Debe ser un celular peruano (9XXXXXXXX)';
                    }
                    return null;
                  },
                ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.06),

                const SizedBox(height: AppConstants.spacing24),
                _buildSectionHeader(theme, 'Seguridad'),
                const SizedBox(height: AppConstants.spacing16),

                ComicTextField(
                  label: 'Contraseña',
                  hint: '••••••••',
                  controller: _passwordCtrl,
                  focusNode: _passwordFocus,
                  isPassword: true,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
                  prefixIcon: _icon(FontAwesomeIcons.lock),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'La contraseña es requerida';
                    if (v.length < 8) return 'Mínimo 8 caracteres';
                    return null;
                  },
                ).animate().fadeIn(delay: 250.ms).slideX(begin: -0.06),

                // Indicador de fortaleza
                ValueListenableBuilder(
                  valueListenable: _passwordCtrl,
                  builder: (_, __, ___) {
                    return PasswordStrengthIndicator(
                      password: _passwordCtrl.text,
                    );
                  },
                ),

                const SizedBox(height: AppConstants.spacing16),
                ComicTextField(
                  label: 'Confirmar contraseña',
                  hint: '••••••••',
                  controller: _confirmCtrl,
                  focusNode: _confirmFocus,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  prefixIcon: _icon(FontAwesomeIcons.lockOpen),
                  validator: (v) {
                    if (v != _passwordCtrl.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.06),

                const SizedBox(height: AppConstants.spacing24),

                // ── Términos ────────────────────────────────────────
                GestureDetector(
                  onTap: () =>
                      setState(() => _termsAccepted = !_termsAccepted),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _termsAccepted
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _termsAccepted
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                            width: AppConstants.borderWidth,
                          ),
                        ),
                        child: _termsAccepted
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: AppConstants.spacing12),
                      Expanded(
                        child: Text.rich(TextSpan(children: [
                          TextSpan(
                            text: 'Acepto los ',
                            style: theme.textTheme.bodySmall,
                          ),
                          TextSpan(
                            text: 'Términos y Condiciones',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ])),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 350.ms),

                const SizedBox(height: AppConstants.spacing32),
                ComicButton(
                  label: 'Crear cuenta',
                  onPressed: _submit,
                  isLoading: authState.isLoading,
                  width: double.infinity,
                  animateDelay: 400,
                ),
                const SizedBox(height: AppConstants.spacing24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('¿Ya tienes cuenta? ',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        )),
                    GestureDetector(
                      onTap: () => context.go(AppRoutes.login),
                      child: Text('Inicia sesión',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                  ],
                ).animate().fadeIn(delay: 450.ms),
                const SizedBox(height: AppConstants.spacing40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _icon(IconData icon) => FaIcon(
        icon,
        size: 15,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
      );

  Widget _buildSectionHeader(ThemeData theme, String label) {
    return Row(
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        const SizedBox(width: AppConstants.spacing8),
        Expanded(
          child: Divider(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            thickness: 1,
          ),
        ),
      ],
    );
  }
}

// ── Vista de confirmación de email ────────────────────────────────────────────
class _EmailConfirmationSent extends StatelessWidget {
  final String email;
  const _EmailConfirmationSent({required this.email});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacing32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FaIcon(
                FontAwesomeIcons.solidEnvelope,
                size: 64,
                color: Color(0xFF5B3FE8),
              )
                  .animate()
                  .scale(begin: const Offset(0.5, 0.5))
                  .fadeIn(duration: 500.ms),
              const SizedBox(height: AppConstants.spacing32),
              Text(
                '¡Revisa tu email!',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: AppConstants.spacing16),
              Text(
                'Enviamos un enlace de confirmación a\n$email',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: AppConstants.spacing48),
              ComicButton(
                label: 'Ir al inicio de sesión',
                onPressed: () => context.go(AppRoutes.login),
                width: double.infinity,
                animateDelay: 500,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
