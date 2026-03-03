import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/wayqui_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../loans/presentation/providers/loans_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme  = Theme.of(context);
    final colors = theme.extension<WayquiColors>()!;
    final user   = ref.watch(authProvider).value;
    final summary = ref.watch(userSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppConstants.appName,
            style: theme.textTheme.headlineSmall),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.rightFromBracket, size: 18),
            tooltip: 'Cerrar sesión',
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.read(authProvider.notifier).signOut();
            },
          ),
          const SizedBox(width: AppConstants.spacing8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(userSummaryProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(AppConstants.spacing16),
          children: [
            // ── Bienvenida ─────────────────────────────────────
            Text(
              '¡Hola, ${user?.displayName?.split(' ').first ?? 'amigo'}! 👋',
              style: theme.textTheme.titleLarge,
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: AppConstants.spacing4),
            Text(
              user?.email ?? '',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: AppConstants.spacing24),

            // ── Balance cards ─────────────────────────────────
            summary.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorCard(message: e.toString()),
              data: (data) => _BalanceSection(data: data, colors: colors),
            ),

            const SizedBox(height: AppConstants.spacing32),

            // ── Acciones rápidas ──────────────────────────────
            Text('Acciones rápidas', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppConstants.spacing12),
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: FontAwesomeIcons.handHoldingDollar,
                    label: 'Prestar',
                    color: colors.positive,
                    onTap: () {}, // TODO: CreateLoanScreen
                  ),
                ),
                const SizedBox(width: AppConstants.spacing12),
                Expanded(
                  child: _ActionCard(
                    icon: FontAwesomeIcons.moneyBillTransfer,
                    label: 'Pagar',
                    color: colors.negative,
                    onTap: () {}, // TODO: RegisterPaymentScreen
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          // TODO: CreateLoanScreen
        },
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        icon: const FaIcon(FontAwesomeIcons.plus, size: 16),
        label: Text('Nuevo préstamo', style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onPrimary,
        )),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          side: BorderSide(
            color: theme.colorScheme.outline,
            width: AppConstants.borderWidth,
          ),
        ),
        elevation: 0,
      ),
    );
  }
}

// ─── Sección balance ─────────────────────────────────────────────────────────
class _BalanceSection extends StatelessWidget {
  final Map<String, dynamic> data;
  final WayquiColors colors;

  const _BalanceSection({required this.data, required this.colors});

  @override
  Widget build(BuildContext context) {
    final theme     = Theme.of(context);
    final owed      = (data['total_owed'] as num?)?.toDouble() ?? 0;
    final debt      = (data['total_debt'] as num?)?.toDouble() ?? 0;
    final netBalance = (data['net_balance'] as num?)?.toDouble() ?? 0;
    final isPositive = netBalance >= 0;

    return Column(
      children: [
        // Balance neto
        _SummaryCard(
          label: 'Balance neto',
          value: CurrencyFormatter.format(netBalance.abs()),
          prefix: isPositive ? '+' : '-',
          color: isPositive ? colors.positive : colors.negative,
          icon: isPositive
              ? FontAwesomeIcons.arrowTrendUp
              : FontAwesomeIcons.arrowTrendDown,
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
        const SizedBox(height: AppConstants.spacing12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Me deben',
                value: CurrencyFormatter.format(owed),
                color: colors.positive,
                icon: FontAwesomeIcons.arrowDown,
                compact: true,
              ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1, end: 0),
            ),
            const SizedBox(width: AppConstants.spacing12),
            Expanded(
              child: _SummaryCard(
                label: 'Debo',
                value: CurrencyFormatter.format(debt),
                color: colors.negative,
                icon: FontAwesomeIcons.arrowUp,
                compact: true,
              ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1, end: 0),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String? prefix;
  final Color color;
  final IconData icon;
  final bool compact;

  const _SummaryCard({
    required this.label,
    required this.value,
    this.prefix,
    required this.color,
    required this.icon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacing16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(
          color: theme.colorScheme.outline,
          width: AppConstants.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(icon, size: 14, color: color),
              const SizedBox(width: AppConstants.spacing8),
              Text(label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  )),
            ],
          ),
          const SizedBox(height: AppConstants.spacing8),
          Text(
            '${prefix ?? ''}$value',
            style: (compact
                    ? theme.textTheme.titleMedium
                    : theme.textTheme.titleLarge)
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacing16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: Border.all(
            color: theme.colorScheme.outline,
            width: AppConstants.borderWidth,
          ),
        ),
        child: Row(
          children: [
            FaIcon(icon, size: 18, color: color),
            const SizedBox(width: AppConstants.spacing8),
            Text(label,
                style: theme.textTheme.labelLarge?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacing16),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(color: theme.colorScheme.error),
      ),
      child: Text(message, style: theme.textTheme.bodySmall),
    );
  }
}
