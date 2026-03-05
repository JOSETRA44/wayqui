import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/wayqui_colors.dart';
import '../providers/auth_notifier.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class OtpVerifyScreen extends ConsumerStatefulWidget {
  final String email;
  const OtpVerifyScreen({super.key, required this.email});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  static const int _otpLength     = 6;
  static const int _resendSeconds = 60;

  final _controllers = List.generate(_otpLength, (_) => TextEditingController());
  final _focusNodes  = List.generate(_otpLength, (_) => FocusNode());

  int  _secondsLeft  = _resendSeconds;
  late Timer _timer;
  bool _hasError     = false;
  bool _isVerifying  = false;   // ← guard double-submit

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes)  { f.dispose(); }
    super.dispose();
  }

  void _startTimer() {
    _secondsLeft = _resendSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        if (mounted) { setState(() => _secondsLeft--); }
      }
    });
  }

  String get _fullOtp => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (_isVerifying) return;
    setState(() => _hasError = false);

    if (value.length > 1) {
      // Paste: distribute digits across boxes
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < _otpLength && i < digits.length; i++) {
        _controllers[i].text = digits[i];
      }
      final nextIndex = digits.length.clamp(0, _otpLength - 1);
      _focusNodes[nextIndex].requestFocus();
      if (_fullOtp.length == _otpLength) { _submit(); }
      return;
    }

    if (value.isNotEmpty && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    if (_fullOtp.length == _otpLength) {
      _submit();
    }
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  Future<void> _submit() async {
    final otp = _fullOtp;
    if (otp.length < _otpLength || _isVerifying) return;

    setState(() => _isVerifying = true);
    HapticFeedback.mediumImpact();

    try {
      await ref.read(authProvider.notifier).verifyOtp(
            email: widget.email,
            token: otp,
          );

      if (!mounted) return;

      final authState = ref.read(authProvider);
      if (authState.hasError) {
        HapticFeedback.vibrate();
        setState(() => _hasError = true);
        for (final c in _controllers) { c.clear(); }
        _focusNodes[0].requestFocus();
        _showError('Código incorrecto o expirado. Intenta de nuevo.');
      }
      // Si es AsyncData(user) el router redirige automáticamente a /home
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0) return;
    HapticFeedback.selectionClick();
    try {
      await ref.read(authProvider.notifier).resendOtp(widget.email);
      _timer.cancel();
      _startTimer();
      for (final c in _controllers) { c.clear(); }
      _focusNodes[0].requestFocus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:  Text('Código reenviado a tu email'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      _showError('No se pudo reenviar. Espera un momento.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content:         Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior:        SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final theme     = Theme.of(context);
    final colors    = theme.extension<WayquiColors>()!;
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading || _isVerifying;

    final emailDisplay = widget.email.length > 28
        ? '${widget.email.substring(0, 14)}…${widget.email.split('@').last}'
        : widget.email;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation:       0,
        leading: IconButton(
          icon:      const FaIcon(FontAwesomeIcons.arrowLeft, size: 16),
          onPressed: isLoading ? null : () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spacing24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppConstants.spacing24),

              // ── Icon ────────────────────────────────────────────
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: FaIcon(FontAwesomeIcons.envelopeOpenText,
                      size: 28, color: theme.colorScheme.primary),
                ),
              ).animate().scale(begin: const Offset(0.5, 0.5), duration: 400.ms)
               .fadeIn(),

              const SizedBox(height: AppConstants.spacing24),

              // ── Headline ─────────────────────────────────────────
              Text('Verifica tu email',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  )).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: AppConstants.spacing8),

              Text('Ingresa el código de 6 dígitos enviado a',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                  textAlign: TextAlign.center)
                .animate().fadeIn(delay: 150.ms),

              const SizedBox(height: AppConstants.spacing4),

              Text(emailDisplay,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ))
                .animate().fadeIn(delay: 200.ms),

              const SizedBox(height: AppConstants.spacing40),

              // ── OTP boxes ────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_otpLength, (i) => _OtpBox(
                  controller: _controllers[i],
                  focusNode:  _focusNodes[i],
                  hasError:   _hasError,
                  isLoading:  isLoading,
                  onChanged:  (v) => _onDigitChanged(i, v),
                  onKey:      (e) => _onKeyEvent(i, e),
                  colors:     colors,
                ).animate().fadeIn(delay: Duration(milliseconds: 250 + i * 40))
                 .slideY(begin: 0.2, end: 0)),
              ),

              const SizedBox(height: AppConstants.spacing40),

              // ── Submit ───────────────────────────────────────────
              if (isLoading)
                CircularProgressIndicator(color: theme.colorScheme.primary)
                    .animate().fadeIn()
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _fullOtp.length == _otpLength ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:         theme.colorScheme.primary,
                      foregroundColor:         theme.colorScheme.onPrimary,
                      disabledBackgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
                      elevation:               0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                        side: BorderSide(color: theme.colorScheme.outline, width: 2),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacing16),
                    ),
                    child: Text('Verificar',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: _fullOtp.length == _otpLength
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        )),
                  ),
                ).animate().fadeIn(delay: 500.ms),

              const SizedBox(height: AppConstants.spacing32),

              // ── Resend ───────────────────────────────────────────
              _ResendRow(
                secondsLeft: _secondsLeft,
                onResend:    isLoading ? () {} : _resend,
              ).animate().fadeIn(delay: 600.ms),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OTP Box  —  StatefulWidget to manage KeyboardListener's FocusNode lifecycle
// ─────────────────────────────────────────────────────────────────────────────

class _OtpBox extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode             focusNode;
  final bool                  hasError;
  final bool                  isLoading;
  final ValueChanged<String>  onChanged;
  final Function(KeyEvent)    onKey;
  final WayquiColors          colors;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.isLoading,
    required this.onChanged,
    required this.onKey,
    required this.colors,
  });

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  final _keyListenerFocus = FocusNode();

  @override
  void dispose() {
    _keyListenerFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: KeyboardListener(
        focusNode: _keyListenerFocus,
        onKeyEvent: widget.onKey,
        child: SizedBox(
          width:  46,
          height: 56,
          child: TextFormField(
            controller:      widget.controller,
            focusNode:       widget.focusNode,
            enabled:         !widget.isLoading,
            keyboardType:    TextInputType.number,
            textAlign:       TextAlign.center,
            maxLength:       1,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.nunito(
              fontSize:   24,
              fontWeight: FontWeight.w700,
              color:      theme.colorScheme.onSurface,
            ),
            onChanged: widget.onChanged,
            decoration: InputDecoration(
              counterText: '',
              filled:      true,
              fillColor:   widget.hasError
                  ? widget.colors.negative.withValues(alpha: 0.08)
                  : widget.focusNode.hasFocus
                      ? theme.colorScheme.primary.withValues(alpha: 0.06)
                      : theme.colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: widget.hasError
                      ? widget.colors.negative
                      : theme.colorScheme.outline,
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: widget.hasError
                      ? widget.colors.negative
                      : theme.colorScheme.outline.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: widget.hasError
                      ? widget.colors.negative
                      : theme.colorScheme.primary,
                  width: 2.5,
                ),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Resend row
// ─────────────────────────────────────────────────────────────────────────────

class _ResendRow extends StatelessWidget {
  final int          secondsLeft;
  final VoidCallback onResend;
  const _ResendRow({required this.secondsLeft, required this.onResend});

  @override
  Widget build(BuildContext context) {
    final theme     = Theme.of(context);
    final canResend = secondsLeft == 0;

    return Column(
      children: [
        Text('¿No recibiste el código?',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            )),
        const SizedBox(height: AppConstants.spacing8),
        if (!canResend)
          Text(
            'Reenviar en ${secondsLeft}s',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          )
        else
          GestureDetector(
            onTap: onResend,
            child: Text(
              'Reenviar código',
              style: theme.textTheme.labelMedium?.copyWith(
                color:      theme.colorScheme.primary,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
