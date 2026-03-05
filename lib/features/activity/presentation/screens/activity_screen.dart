import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/wayqui_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../loans/domain/entities/loan_entity.dart';
import '../../../loans/presentation/providers/loans_providers.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme      = Theme.of(context);
    final colors     = theme.extension<WayquiColors>()!;
    final loansAsync = ref.watch(loansProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned:          true,
            backgroundColor: theme.colorScheme.surface,
            elevation:       0,
            title:           Text('Actividad', style: theme.textTheme.headlineSmall),
            actions: [
              IconButton(
                icon:      const FaIcon(FontAwesomeIcons.arrowsRotate, size: 16),
                tooltip:   'Actualizar',
                onPressed: () => ref.read(loansProvider.notifier).refresh(),
              ),
              const SizedBox(width: AppConstants.spacing8),
            ],
          ),

          loansAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: _ErrorView(message: e.toString()),
            ),
            data: (snapshot) {
              final allLoans = [...snapshot.asCreditor, ...snapshot.asDebtor];
              if (allLoans.isEmpty) {
                return const SliverFillRemaining(child: _EmptyActivity());
              }

              // Agrupa por mes
              final grouped = _groupByMonth(allLoans);

              return SliverPadding(
                padding: const EdgeInsets.all(AppConstants.spacing16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final entry  = grouped.entries.elementAt(i);
                      final month  = entry.key;
                      final loans  = entry.value;
                      return _MonthGroup(
                        month:  month,
                        loans:  loans,
                        colors: colors,
                        onTap:  (id) => ctx.push(AppRoutes.loanDetailPath(id)),
                      ).animate().fadeIn(
                        delay: Duration(milliseconds: i * 60),
                        duration: 300.ms,
                      );
                    },
                    childCount: grouped.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Map<String, List<LoanEntity>> _groupByMonth(List<LoanEntity> loans) {
    final fmt = DateFormat('MMMM yyyy', 'es');
    final map = <String, List<LoanEntity>>{};
    for (final loan in loans) {
      final key = fmt.format(loan.createdAt).toUpperCase();
      (map[key] ??= []).add(loan);
    }
    return map;
  }
}

class _MonthGroup extends StatelessWidget {
  final String           month;
  final List<LoanEntity> loans;
  final WayquiColors     colors;
  final void Function(String) onTap;

  const _MonthGroup({
    required this.month,
    required this.loans,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: AppConstants.spacing16,
            bottom: AppConstants.spacing8,
          ),
          child: Text(
            month,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...loans.map((loan) => _ActivityTile(
          loan:   loan,
          colors: colors,
          onTap:  () => onTap(loan.id),
        )),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final LoanEntity   loan;
  final WayquiColors colors;
  final VoidCallback onTap;

  const _ActivityTile({
    required this.loan,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme     = Theme.of(context);
    final statusColor = switch (loan.status) {
      LoanStatus.active        => colors.positive,
      LoanStatus.partiallyPaid => colors.pending,
      LoanStatus.paid          => colors.positive,
      _                        => colors.negative,
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppConstants.spacing8),
        padding: const EdgeInsets.all(AppConstants.spacing12),
        decoration: BoxDecoration(
          color:        theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border:       Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor.withValues(alpha: 0.12),
              ),
              child: Center(
                child: FaIcon(
                  loan.status == LoanStatus.paid
                      ? FontAwesomeIcons.circleCheck
                      : FontAwesomeIcons.handHoldingDollar,
                  size: 16,
                  color: statusColor,
                ),
              ),
            ),
            const SizedBox(width: AppConstants.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loan.debtorName ?? 'Contacto externo',
                      style: theme.textTheme.labelLarge),
                  Text(loan.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(loan.amount),
                  style: theme.textTheme.labelLarge?.copyWith(color: statusColor),
                ),
                Text(
                  loan.status.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
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

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(FontAwesomeIcons.clockRotateLeft, size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: AppConstants.spacing16),
          Text('Sin actividad aún',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              )),
          const SizedBox(height: AppConstants.spacing8),
          Text('Tus préstamos y pagos aparecerán aquí.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
              textAlign: TextAlign.center),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacing24),
        child: Text(message, style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
        )),
      ),
    );
  }
}
