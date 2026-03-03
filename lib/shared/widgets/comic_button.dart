import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_constants.dart';

enum ComicButtonVariant { primary, secondary, outlined }

class ComicButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ComicButtonVariant variant;
  final bool isLoading;
  final Widget? icon;
  final double? width;
  final int animateDelay;

  const ComicButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = ComicButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.width,
    this.animateDelay = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bgColor = switch (variant) {
      ComicButtonVariant.primary => theme.colorScheme.primary,
      ComicButtonVariant.secondary => theme.colorScheme.secondary,
      ComicButtonVariant.outlined => Colors.transparent,
    };

    final fgColor = switch (variant) {
      ComicButtonVariant.primary => theme.colorScheme.onPrimary,
      ComicButtonVariant.secondary => theme.colorScheme.onSecondary,
      ComicButtonVariant.outlined => theme.colorScheme.primary,
    };

    return SizedBox(
      width: width,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          disabledBackgroundColor: bgColor.withOpacity(0.6),
          elevation: AppConstants.elevation,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            side: BorderSide(
              color: theme.colorScheme.outline,
              width: AppConstants.borderWidth,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacing24,
            vertical: AppConstants.spacing16,
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: fgColor,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: AppConstants.spacing8),
                  ],
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: fgColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: animateDelay), duration: 350.ms)
        .slideY(begin: 0.15, end: 0);
  }
}
