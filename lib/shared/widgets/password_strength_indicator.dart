import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_constants.dart';
import '../../core/extensions/wayqui_colors.dart';

/// Modelo de fortaleza de contraseña.
class PasswordStrength {
  final bool hasMinLength;  // >= 8 caracteres
  final bool hasUppercase;  // A-Z
  final bool hasNumber;     // 0-9
  final bool hasSpecial;    // !@#$%...

  const PasswordStrength({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasNumber,
    required this.hasSpecial,
  });

  factory PasswordStrength.from(String password) => PasswordStrength(
        hasMinLength: password.length >= 8,
        hasUppercase: RegExp(r'[A-Z]').hasMatch(password),
        hasNumber:    RegExp(r'[0-9]').hasMatch(password),
        hasSpecial:   RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password),
      );

  int get score =>
      [hasMinLength, hasUppercase, hasNumber, hasSpecial]
          .where((e) => e)
          .length;

  bool get isStrong => score >= 3;

  String get label => switch (score) {
        0 || 1 => 'Muy débil',
        2      => 'Débil',
        3      => 'Buena',
        _      => 'Fuerte',
      };

  Color color(WayquiColors c) => switch (score) {
        0 || 1 => c.negative,
        2      => c.pending,
        3      => const Color(0xFF86EFAC), // verde claro
        _      => c.positive,
      };
}

/// Widget que muestra la fortaleza de la contraseña con 4 barras y checklist.
class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final theme    = Theme.of(context);
    final colors   = theme.extension<WayquiColors>()!;
    final strength = PasswordStrength.from(password);
    final barColor = strength.color(colors);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppConstants.spacing8),
        // ── Barras ──────────────────────────────────────────────
        Row(
          children: List.generate(4, (i) {
            final filled = i < strength.score;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 4,
                margin: EdgeInsets.only(
                  right: i < 3 ? AppConstants.spacing4 : 0,
                ),
                decoration: BoxDecoration(
                  color: filled
                      ? barColor
                      : theme.colorScheme.outline.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: AppConstants.spacing8),
        // ── Label + criterios ────────────────────────────────────
        Row(
          children: [
            Text(
              strength.label,
              style: theme.textTheme.labelSmall?.copyWith(color: barColor),
            ),
            const Spacer(),
            _Criterion(
              met: strength.hasMinLength,
              label: '8+',
              colors: colors,
            ),
            const SizedBox(width: AppConstants.spacing8),
            _Criterion(
              met: strength.hasUppercase,
              label: 'A-Z',
              colors: colors,
            ),
            const SizedBox(width: AppConstants.spacing8),
            _Criterion(
              met: strength.hasNumber,
              label: '0-9',
              colors: colors,
            ),
            const SizedBox(width: AppConstants.spacing8),
            _Criterion(
              met: strength.hasSpecial,
              label: '!@#',
              colors: colors,
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 200.ms);
  }
}

class _Criterion extends StatelessWidget {
  final bool met;
  final String label;
  final WayquiColors colors;

  const _Criterion({
    required this.met,
    required this.label,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacing4,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: met
            ? colors.positive.withValues(alpha: 0.12)
            : theme.colorScheme.outline.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: met
              ? colors.positive.withValues(alpha: 0.5)
              : theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: met
              ? colors.positive
              : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          fontSize: 9,
        ),
      ),
    );
  }
}
