import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/comic_button.dart';
import '../providers/auth_notifier.dart';
import '../providers/onboarding_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  // 5 pasos: nombre, email, teléfono, contraseña, confirmar contraseña
  static const int _totalSteps = 5;

  final _pageCtrl        = PageController();
  final _formKeys        = List.generate(_totalSteps, (_) => GlobalKey<FormState>());

  final _nameCtrl        = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _phoneCtrl       = TextEditingController();
  final _passCtrl        = TextEditingController();
  final _passConfirmCtrl = TextEditingController();

  final _nameFocus        = FocusNode();
  final _emailFocus       = FocusNode();
  final _phoneFocus       = FocusNode();
  final _passFocus        = FocusNode();
  final _passConfirmFocus = FocusNode();

  int  _currentStep       = 0;
  bool _passObscure       = true;
  bool _passConfirmObscure = true;
  bool _isSubmitting      = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _passConfirmCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passFocus.dispose();
    _passConfirmFocus.dispose();
    super.dispose();
  }

  // ── Navegación ─────────────────────────────────────────────────────────────

  Future<void> _next() async {
    // Cerrar teclado ANTES de validar y animar para evitar conflictos
    // de layout en Android (el teclado desplaza el PageView).
    FocusScope.of(context).unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;

    try {
      final formState = _formKeys[_currentStep].currentState;
      if (formState == null) return;
      if (!formState.validate()) {
        HapticFeedback.vibrate();
        return;
      }

      // Guardar el paso actual en el provider (backup)
      _saveCurrentStep();
      HapticFeedback.selectionClick();

      if (_currentStep < _totalSteps - 1) {
        await _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 350),
          curve:    Curves.easeInOutCubic,
        );
      } else {
        await _submit();
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Error inesperado: ${e.toString()}');
    }
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_currentStep > 0) {
      HapticFeedback.selectionClick();
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 350),
        curve:    Curves.easeInOutCubic,
      );
    } else {
      context.go(AppRoutes.login);
    }
  }

  void _saveCurrentStep() {
    final notifier = ref.read(onboardingProvider.notifier);
    switch (_currentStep) {
      case 0: notifier.setName(_nameCtrl.text.trim());
      case 1: notifier.setEmail(_emailCtrl.text.trim().toLowerCase());
      case 2: notifier.setPhone(_phoneCtrl.text.trim());
      case 3: notifier.setPassword(_passCtrl.text);
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      // Leer DIRECTAMENTE de los controllers — no del provider autoDispose
      // para evitar que email/password lleguen vacíos a Supabase.
      final email    = _emailCtrl.text.trim().toLowerCase();
      final password = _passCtrl.text;
      final name     = _nameCtrl.text.trim();
      final phone    = _phoneCtrl.text.trim();

      // Guard: nunca llamar signUp con credenciales vacías
      if (email.isEmpty || password.isEmpty) {
        _showError('Por favor completa todos los pasos del registro.');
        // Volver al paso problemático
        final step = email.isEmpty ? 1 : 3;
        await _pageCtrl.animateToPage(
          step,
          duration: const Duration(milliseconds: 350),
          curve:    Curves.easeInOutCubic,
        );
        return;
      }

      final confirmRequired = await ref
          .read(authProvider.notifier)
          .signUp(
            email:       email,
            password:    password,
            fullName:    name,
            phoneNumber: phone.isNotEmpty ? phone : null,
          );

      if (!mounted) return;

      final authState = ref.read(authProvider);
      if (authState.hasError) {
        HapticFeedback.vibrate();
        _showError(
          ref.read(authProvider.notifier).parseError(authState.error!),
        );
        return;
      }

      if (confirmRequired) {
        // Navegar a verificación OTP con el email
        if (mounted) {
          context.push(
            '${AppRoutes.otpVerify}?email=${Uri.encodeComponent(email)}',
          );
        }
      }
      // Si !confirmRequired, el router redirige automáticamente a /home.
    } catch (e) {
      if (!mounted) return;
      _showError('No se pudo crear la cuenta: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content:         Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior:        SnackBarBehavior.floating,
        duration:        const Duration(seconds: 4),
      ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme     = Theme.of(context);
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading || _isSubmitting;
    final isLastStep = _currentStep == _totalSteps - 1;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      // false → el PageView no se comprime con el teclado
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacing16,
                vertical:   AppConstants.spacing12,
              ),
              child: Row(
                children: [
                  _BackButton(onTap: _back),
                  const SizedBox(width: AppConstants.spacing16),
                  Expanded(
                    child: _ProgressBar(
                      current: _currentStep + 1,
                      total:   _totalSteps,
                      color:   theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacing48),
                ],
              ),
            ),

            const SizedBox(height: AppConstants.spacing8),
            Text(
              AppConstants.appName.toUpperCase(),
              style: theme.textTheme.titleSmall?.copyWith(
                color:         theme.colorScheme.onSurface.withValues(alpha: 0.35),
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: AppConstants.spacing32),

            // ── PageView ──────────────────────────────────────────
            Expanded(
              child: PageView(
                controller:    _pageCtrl,
                physics:       const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentStep = i),
                children: [
                  _NameStep(
                    formKey:  _formKeys[0],
                    ctrl:     _nameCtrl,
                    focus:    _nameFocus,
                    onSubmit: _next,
                  ),
                  _EmailStep(
                    formKey:  _formKeys[1],
                    ctrl:     _emailCtrl,
                    focus:    _emailFocus,
                    onSubmit: _next,
                  ),
                  _PhoneStep(
                    formKey:  _formKeys[2],
                    ctrl:     _phoneCtrl,
                    focus:    _phoneFocus,
                    onSubmit: _next,
                  ),
                  _PasswordStep(
                    formKey:  _formKeys[3],
                    ctrl:     _passCtrl,
                    focus:    _passFocus,
                    obscure:  _passObscure,
                    onToggle: () => setState(() => _passObscure = !_passObscure),
                    onSubmit: _next,
                  ),
                  _PasswordConfirmStep(
                    formKey:         _formKeys[4],
                    ctrl:            _passConfirmCtrl,
                    focus:           _passConfirmFocus,
                    originalPassCtrl: _passCtrl,
                    obscure:         _passConfirmObscure,
                    onToggle:        () => setState(
                      () => _passConfirmObscure = !_passConfirmObscure,
                    ),
                    onSubmit:        _next,
                  ),
                ],
              ),
            ),

            // ── CTA ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacing24, 0,
                AppConstants.spacing24, AppConstants.spacing32,
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ComicButton(
                      label: isLastStep
                          ? (isLoading ? 'Creando cuenta...' : 'Crear cuenta')
                          : 'Continuar',
                      isLoading: isLoading,
                      icon: FaIcon(
                        isLastStep
                            ? FontAwesomeIcons.check
                            : FontAwesomeIcons.arrowRight,
                        size: 14,
                      ),
                      onPressed: isLoading ? null : _next,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacing16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '¿Ya tienes cuenta? ',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.go(AppRoutes.login),
                        child: Text(
                          'Inicia sesión',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:      theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress bar + Back button
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final int   current;
  final int   total;
  final Color color;
  const _ProgressBar({required this.current, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: List.generate(total, (i) {
        final active    = i < current;
        final isCurrent = i == current - 1;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve:    Curves.easeInOut,
            margin:   const EdgeInsets.only(right: 4),
            height:   4,
            decoration: BoxDecoration(
              color:        active
                  ? color
                  : theme.colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(99),
              boxShadow:    isCurrent
                  ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape:  BoxShape.circle,
          color:  theme.colorScheme.surfaceContainerHighest,
          border: Border.all(color: theme.colorScheme.outline, width: 1.5),
        ),
        child: Center(
          child: FaIcon(
            FontAwesomeIcons.arrowLeft, size: 14,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shell compartido por todos los pasos
// ─────────────────────────────────────────────────────────────────────────────

class _StepShell extends StatelessWidget {
  final String   headline;
  final String   subtitle;
  final IconData icon;
  final Widget   field;

  const _StepShell({
    required this.headline,
    required this.subtitle,
    required this.icon,
    required this.field,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FaIcon(icon, size: 28, color: theme.colorScheme.primary)
              .animate()
              .scale(begin: const Offset(0.6, 0.6), duration: 350.ms)
              .fadeIn(),
          const SizedBox(height: AppConstants.spacing16),
          Text(
            headline,
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: AppConstants.spacing8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: AppConstants.spacing32),
          field.animate().fadeIn(delay: 150.ms).slideY(begin: 0.08, end: 0),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Estilo de texto para campos de entrada
// NUNCA usar headlineSmall (Bangers = all-caps) en campos editables.
// ─────────────────────────────────────────────────────────────────────────────

TextStyle _fieldTextStyle(BuildContext context) => GoogleFonts.nunito(
      fontSize:   22,
      fontWeight: FontWeight.w600,
      color:      Theme.of(context).colorScheme.onSurface,
    );

TextStyle _fieldHintStyle(BuildContext context) => GoogleFonts.nunito(
      fontSize:   22,
      fontWeight: FontWeight.w400,
      color:      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 — Nombre
// ─────────────────────────────────────────────────────────────────────────────

class _NameStep extends StatelessWidget {
  final GlobalKey<FormState>  formKey;
  final TextEditingController ctrl;
  final FocusNode             focus;
  final VoidCallback          onSubmit;
  const _NameStep({
    required this.formKey, required this.ctrl,
    required this.focus,   required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: _StepShell(
        headline: '¿Cómo te llamas?',
        subtitle: 'Tu nombre aparecerá en los préstamos.',
        icon:     FontAwesomeIcons.solidStar,
        field: TextFormField(
          controller:         ctrl,
          focusNode:          focus,
          autofocus:          true,
          textCapitalization: TextCapitalization.words,
          textInputAction:    TextInputAction.next,
          onFieldSubmitted:   (_) => onSubmit(),
          style:              _fieldTextStyle(context),
          decoration:         _inputDecoration(context, 'Ej: María García'),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Ingresa tu nombre';
            if (v.trim().length < 2)           return 'Nombre muy corto';
            return null;
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 — Email
// ─────────────────────────────────────────────────────────────────────────────

class _EmailStep extends StatelessWidget {
  final GlobalKey<FormState>  formKey;
  final TextEditingController ctrl;
  final FocusNode             focus;
  final VoidCallback          onSubmit;
  const _EmailStep({
    required this.formKey, required this.ctrl,
    required this.focus,   required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: _StepShell(
        headline: '¿Cuál es tu email?',
        subtitle: 'Te enviaremos un código de 6 dígitos para verificar tu cuenta.',
        icon:     FontAwesomeIcons.envelope,
        field: TextFormField(
          controller:         ctrl,
          focusNode:          focus,
          autofocus:          true,
          keyboardType:       TextInputType.emailAddress,
          textInputAction:    TextInputAction.next,
          // Email: sin auto-capitalización ni corrector
          textCapitalization: TextCapitalization.none,
          autocorrect:        false,
          enableSuggestions:  false,
          onFieldSubmitted:   (_) => onSubmit(),
          style:              _fieldTextStyle(context),
          decoration:         _inputDecoration(context, 'tu@email.com'),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Ingresa tu email';
            if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(v.trim())) {
              return 'Email inválido';
            }
            return null;
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3 — Teléfono (opcional)
// ─────────────────────────────────────────────────────────────────────────────

class _PhoneStep extends StatelessWidget {
  final GlobalKey<FormState>  formKey;
  final TextEditingController ctrl;
  final FocusNode             focus;
  final VoidCallback          onSubmit;
  const _PhoneStep({
    required this.formKey, required this.ctrl,
    required this.focus,   required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: _StepShell(
        headline: '¿Tienes Yape o Plin?',
        subtitle: 'Tu número permitirá que otros te paguen fácilmente. Puedes omitirlo.',
        icon:     FontAwesomeIcons.mobileScreen,
        field: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller:         ctrl,
              focusNode:          focus,
              autofocus:          true,
              keyboardType:       TextInputType.phone,
              textInputAction:    TextInputAction.next,
              textCapitalization: TextCapitalization.none,
              onFieldSubmitted:   (_) => onSubmit(),
              style:              _fieldTextStyle(context),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              decoration: _inputDecoration(context, '9XXXXXXXX'),
              validator: (v) {
                if (v == null || v.isEmpty) return null; // opcional
                if (!RegExp(r'^9\d{8}$').hasMatch(v)) {
                  return 'Número inválido (9XXXXXXXX)';
                }
                return null;
              },
            ),
            const SizedBox(height: AppConstants.spacing12),
            GestureDetector(
              onTap: onSubmit,
              child: Text(
                'Omitir por ahora →',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 4 — Contraseña
// ─────────────────────────────────────────────────────────────────────────────

class _PasswordStep extends StatelessWidget {
  final GlobalKey<FormState>  formKey;
  final TextEditingController ctrl;
  final FocusNode             focus;
  final bool                  obscure;
  final VoidCallback          onToggle;
  final VoidCallback          onSubmit;
  const _PasswordStep({
    required this.formKey,  required this.ctrl,
    required this.focus,    required this.obscure,
    required this.onToggle, required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: formKey,
      child: _StepShell(
        headline: 'Crea tu contraseña',
        subtitle: 'Mínimo 8 caracteres con mayúscula y número.',
        icon:     FontAwesomeIcons.lock,
        field: TextFormField(
          controller:         ctrl,
          focusNode:          focus,
          autofocus:          true,
          obscureText:        obscure,
          textInputAction:    TextInputAction.next,
          // Contraseña: sin transformaciones de ningún tipo
          textCapitalization: TextCapitalization.none,
          autocorrect:        false,
          enableSuggestions:  false,
          onFieldSubmitted:   (_) => onSubmit(),
          style:              _fieldTextStyle(context),
          decoration: _inputDecoration(
            context,
            'Tu contraseña',
            suffix: IconButton(
              icon: FaIcon(
                obscure ? FontAwesomeIcons.eye : FontAwesomeIcons.eyeSlash,
                size:  16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              tooltip:   obscure ? 'Mostrar' : 'Ocultar',
              onPressed: onToggle,
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty)            return 'Crea una contraseña';
            if (v.length < 8)                      return 'Mínimo 8 caracteres';
            if (!RegExp(r'[A-Z]').hasMatch(v))     return 'Incluye al menos una mayúscula';
            if (!RegExp(r'[0-9]').hasMatch(v))     return 'Incluye al menos un número';
            return null;
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 5 — Confirmar contraseña
// ─────────────────────────────────────────────────────────────────────────────

class _PasswordConfirmStep extends StatelessWidget {
  final GlobalKey<FormState>  formKey;
  final TextEditingController ctrl;
  final TextEditingController originalPassCtrl; // para validar coincidencia
  final FocusNode             focus;
  final bool                  obscure;
  final VoidCallback          onToggle;
  final VoidCallback          onSubmit;
  const _PasswordConfirmStep({
    required this.formKey,         required this.ctrl,
    required this.originalPassCtrl, required this.focus,
    required this.obscure,         required this.onToggle,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: formKey,
      child: _StepShell(
        headline: 'Confirma tu contraseña',
        subtitle: 'Vuelve a escribir la misma contraseña para asegurarnos de que no haya errores.',
        icon:     FontAwesomeIcons.shieldHalved,
        field: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller:         ctrl,
              focusNode:          focus,
              autofocus:          true,
              obscureText:        obscure,
              textInputAction:    TextInputAction.done,
              textCapitalization: TextCapitalization.none,
              autocorrect:        false,
              enableSuggestions:  false,
              onFieldSubmitted:   (_) => onSubmit(),
              style:              _fieldTextStyle(context),
              decoration: _inputDecoration(
                context,
                'Repite la contraseña',
                suffix: IconButton(
                  icon: FaIcon(
                    obscure ? FontAwesomeIcons.eye : FontAwesomeIcons.eyeSlash,
                    size:  16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  tooltip:   obscure ? 'Mostrar' : 'Ocultar',
                  onPressed: onToggle,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Repite tu contraseña';
                if (v != originalPassCtrl.text) return 'Las contraseñas no coinciden';
                return null;
              },
            ),
            const SizedBox(height: AppConstants.spacing12),
            Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.circleInfo,
                  size:  12,
                  color: theme.colorScheme.primary.withValues(alpha: 0.6),
                ),
                const SizedBox(width: AppConstants.spacing8),
                Expanded(
                  child: Text(
                    'Al crear la cuenta recibirás un código OTP de 6 dígitos en tu email para verificar tu identidad.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Decoración compartida (underline style)
// ─────────────────────────────────────────────────────────────────────────────

InputDecoration _inputDecoration(
  BuildContext context,
  String hint, {
  Widget? suffix,
}) {
  final theme = Theme.of(context);
  return InputDecoration(
    hintText:    hint,
    hintStyle:   _fieldHintStyle(context),
    suffixIcon:  suffix,
    filled:      false,
    contentPadding: const EdgeInsets.symmetric(vertical: AppConstants.spacing12),
    border: UnderlineInputBorder(
      borderSide: BorderSide(color: theme.colorScheme.outline, width: 2),
    ),
    enabledBorder: UnderlineInputBorder(
      borderSide: BorderSide(
        color: theme.colorScheme.outline.withValues(alpha: 0.5),
        width: 2,
      ),
    ),
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2.5),
    ),
    errorBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
    ),
    focusedErrorBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: theme.colorScheme.error, width: 2.5),
    ),
  );
}
