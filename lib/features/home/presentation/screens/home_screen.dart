import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/wayqui_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../loans/domain/entities/loan_entity.dart';
import '../../../loans/presentation/providers/loans_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme  = Theme.of(context);
    final colors = theme.extension<WayquiColors>()!;
    final user   = ref.watch(authProvider).value;
    final summary = ref.watch(userSummaryProvider);

    final loansAsync = ref.watch(loansProvider);

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
        onRefresh: () async {
          ref.invalidate(userSummaryProvider);
          await ref.read(loansProvider.notifier).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.all(AppConstants.spacing16),
          children: [
            // ── Bienvenida ─────────────────────────────────────
            Text(
              '¡Hola, ${user?.displayName?.split(' ').first ?? 'amigo'}!',
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
                    icon:  FontAwesomeIcons.handHoldingDollar,
                    label: 'Prestar',
                    color: colors.positive,
                    onTap: () => context.push(AppRoutes.createLoan),
                  ),
                ),
                const SizedBox(width: AppConstants.spacing12),
                Expanded(
                  child: _ActionCard(
                    icon:  FontAwesomeIcons.moneyBillTransfer,
                    label: 'Mis deudas',
                    color: colors.negative,
                    onTap: () {
                      // Scroll to debts section (handled via tab later)
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppConstants.spacing32),

            // ── Préstamos que hice ────────────────────────────
            loansAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:   (e, _) => _ErrorCard(message: e.toString()),
              data: (snapshot) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (snapshot.asCreditor.isNotEmpty) ...[
                    _LoansListHeader(
                      label: 'Me deben',
                      count: snapshot.asCreditor.length,
                      color: colors.positive,
                    ),
                    const SizedBox(height: AppConstants.spacing8),
                    ...snapshot.asCreditor.map((loan) => _LoanCard(
                      loan:   loan,
                      colors: colors,
                      onTap:  () => context.push(AppRoutes.loanDetailPath(loan.id)),
                    ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.05, end: 0)),
                    const SizedBox(height: AppConstants.spacing24),
                  ],
                  if (snapshot.asDebtor.isNotEmpty) ...[
                    _LoansListHeader(
                      label: 'Debo',
                      count: snapshot.asDebtor.length,
                      color: colors.negative,
                    ),
                    const SizedBox(height: AppConstants.spacing8),
                    ...snapshot.asDebtor.map((loan) => _LoanCard(
                      loan:   loan,
                      colors: colors,
                      onTap:  () => context.push(AppRoutes.loanDetailPath(loan.id)),
                    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.05, end: 0)),
                  ],
                  if (snapshot.asCreditor.isEmpty && snapshot.asDebtor.isEmpty)
                    _EmptyLoans(),
                ],
              ),
            ),

            const SizedBox(height: AppConstants.spacing80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          context.push(AppRoutes.createLoan);
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

// ─── Loans list widgets ──────────────────────────────────────────────────────

class _LoansListHeader extends StatelessWidget {
  final String label;
  final int    count;
  final Color  color;

  const _LoansListHeader({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(label, style: theme.textTheme.titleMedium),
        const SizedBox(width: AppConstants.spacing8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color:        color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _LoanCard extends StatelessWidget {
  final LoanEntity   loan;
  final WayquiColors colors;
  final VoidCallback onTap;

  const _LoanCard({
    required this.loan,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme      = Theme.of(context);
    final progress   = loan.progressPercent.clamp(0.0, 1.0);
    final statusColor = _statusColor(loan.status);
    final name       = loan.debtorName ?? 'Desconocido';

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppConstants.spacing8),
        padding: const EdgeInsets.all(AppConstants.spacing12),
        decoration: BoxDecoration(
          color:        theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: Border.all(
            color: theme.colorScheme.outline,
            width: AppConstants.borderWidthList,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Initials avatar
                CircleAvatar(
                  radius: 18,
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  child: Text(
                    _initials(name),
                    style: theme.textTheme.labelSmall?.copyWith(color: statusColor),
                  ),
                ),
                const SizedBox(width: AppConstants.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.labelLarge),
                      Text(
                        loan.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(loan.remainingAmount),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:        statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(loan.status.label,
                          style: theme.textTheme.labelSmall?.copyWith(color: statusColor)),
                    ),
                  ],
                ),
                const SizedBox(width: AppConstants.spacing8),
                FaIcon(FontAwesomeIcons.chevronRight, size: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
              ],
            ),
            if (loan.paidAmount > 0) ...[
              const SizedBox(height: AppConstants.spacing8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value:           progress,
                  minHeight:       4,
                  backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.3),
                  valueColor:      AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(LoanStatus status) => switch (status) {
    LoanStatus.active        => colors.positive,
    LoanStatus.partiallyPaid => colors.pending,
    LoanStatus.paid          => colors.positive,
    LoanStatus.cancelled     => colors.negative,
    LoanStatus.disputed      => colors.negative,
  };

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }
}

class _EmptyLoans extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacing32),
      child: Column(
        children: [
          FaIcon(
            FontAwesomeIcons.handshake,
            size: 40,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: AppConstants.spacing12),
          Text(
            '¡Sin préstamos activos!',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: AppConstants.spacing8),
          Text(
            'Toca "Nuevo préstamo" para registrar uno.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}
