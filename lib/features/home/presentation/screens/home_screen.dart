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
import '../../../notifications/presentation/widgets/notification_bell.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme      = Theme.of(context);
    final colors     = theme.extension<WayquiColors>()!;
    final user       = ref.watch(authProvider).value;
    final summary    = ref.watch(userSummaryProvider);
    final loansAsync = ref.watch(loansProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userSummaryProvider);
          await ref.read(loansProvider.notifier).refresh();
        },
        child: NestedScrollView(
          headerSliverBuilder: (ctx, innerBoxScrolled) => [
            // ── App bar ──────────────────────────────────────────
            SliverAppBar(
              pinned:          true,
              backgroundColor: theme.colorScheme.surface,
              elevation:       0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¡Hola, ${user?.displayName?.split(' ').first ?? 'amigo'}!',
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    AppConstants.appName.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color:         theme.colorScheme.primary,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
              actions: [
                const NotificationBell(),
                const SizedBox(width: AppConstants.spacing8),
              ],
            ),

            // ── Balance section ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacing16),
                child: summary.when(
                  loading: () => const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => const SizedBox.shrink(),
                  data:  (data) => _BalanceCard(data: data, colors: colors)
                      .animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: AppConstants.spacing16)),

            // ── Quick actions ────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacing16),
                child: _QuickActions(colors: colors),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: AppConstants.spacing16)),

            // ── TabBar ───────────────────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBar(
                tabCtrl: _tabCtrl,
                theme:   theme,
              ),
            ),
          ],

          // ── TabBarView (horizontal) ───────────────────────────
          body: loansAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:   (e, _) => _ErrorView(message: e.toString()),
            data: (snapshot) => TabBarView(
              controller: _tabCtrl,
              children: [
                // Tab 0: Me deben
                _LoansList(
                  loans:     snapshot.asCreditor,
                  emptyMsg:  'No tienes préstamos activos',
                  emptyIcon: FontAwesomeIcons.handHoldingDollar,
                  colors:    colors,
                ),
                // Tab 1: Debo
                _LoansList(
                  loans:     snapshot.asDebtor,
                  emptyMsg:  'No tienes deudas activas',
                  emptyIcon: FontAwesomeIcons.moneyBillWave,
                  colors:    colors,
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () {
          HapticFeedback.mediumImpact();
          context.push(AppRoutes.createLoan);
        },
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation:       0,
        icon:            const FaIcon(FontAwesomeIcons.plus, size: 14),
        label: Text('Nuevo préstamo', style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onPrimary,
        )),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: AppConstants.borderWidth,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky TabBar delegate
// ─────────────────────────────────────────────────────────────────────────────

class _StickyTabBar extends SliverPersistentHeaderDelegate {
  final TabController _tabCtrl;
  final ThemeData     _theme;
  const _StickyTabBar({required TabController tabCtrl, required ThemeData theme})
      : _tabCtrl = tabCtrl, _theme = theme;

  @override double get minExtent => 48;
  @override double get maxExtent => 48;

  @override
  bool shouldRebuild(_StickyTabBar old) => false;

  @override
  Widget build(BuildContext ctx, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: _theme.colorScheme.surface,
      child: TabBar(
        controller:         _tabCtrl,
        labelStyle:         _theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: _theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w400),
        labelColor:         _theme.colorScheme.primary,
        unselectedLabelColor: _theme.colorScheme.onSurface.withValues(alpha: 0.45),
        indicatorColor:     _theme.colorScheme.primary,
        indicatorSize:      TabBarIndicatorSize.label,
        dividerColor:       _theme.colorScheme.outline.withValues(alpha: 0.3),
        tabs: const [
          Tab(text: 'Me deben'),
          Tab(text: 'Debo'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Balance Card
// ─────────────────────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final WayquiColors         colors;
  const _BalanceCard({required this.data, required this.colors});

  @override
  Widget build(BuildContext context) {
    final theme      = Theme.of(context);
    final owed       = (data['total_owed'] as num?)?.toDouble() ?? 0;
    final debt       = (data['total_debt'] as num?)?.toDouble() ?? 0;
    final netBalance = (data['net_balance'] as num?)?.toDouble() ?? 0;
    final isPositive = netBalance >= 0;

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacing20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
          colors: isPositive
              ? [colors.positive.withValues(alpha: 0.12), colors.positive.withValues(alpha: 0.04)]
              : [colors.negative.withValues(alpha: 0.12), colors.negative.withValues(alpha: 0.04)],
        ),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
        border: Border.all(
          color: (isPositive ? colors.positive : colors.negative).withValues(alpha: 0.3),
          width: AppConstants.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Balance neto',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                letterSpacing: 0.5,
              )),
          const SizedBox(height: AppConstants.spacing4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isPositive ? '+' : '-'}${CurrencyFormatter.format(netBalance.abs())}',
                style: theme.textTheme.displaySmall?.copyWith(
                  color:      isPositive ? colors.positive : colors.negative,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppConstants.spacing8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: FaIcon(
                  isPositive
                      ? FontAwesomeIcons.arrowTrendUp
                      : FontAwesomeIcons.arrowTrendDown,
                  size:  14,
                  color: isPositive ? colors.positive : colors.negative,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacing16),
          Row(
            children: [
              _BalanceStat(
                label: 'Me deben',
                value: CurrencyFormatter.format(owed),
                color: colors.positive,
              ),
              const SizedBox(width: AppConstants.spacing24),
              _BalanceStat(
                label: 'Debo',
                value: CurrencyFormatter.format(debt),
                color: colors.negative,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _BalanceStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: theme.textTheme.titleSmall?.copyWith(
              color:      color,
              fontWeight: FontWeight.w700,
            )),
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Actions row
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final WayquiColors colors;
  const _QuickActions({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _QuickAction(
          icon:  FontAwesomeIcons.handHoldingDollar,
          label: 'Prestar',
          color: colors.positive,
          onTap: () {
            HapticFeedback.selectionClick();
            context.push(AppRoutes.createLoan);
          },
        )),
        const SizedBox(width: AppConstants.spacing8),
        Expanded(child: _QuickAction(
          icon:  FontAwesomeIcons.moneyBillTransfer,
          label: 'Pagar',
          color: colors.negative,
          onTap: () => HapticFeedback.selectionClick(),
        )),
        const SizedBox(width: AppConstants.spacing8),
        Expanded(child: _QuickAction(
          icon:  FontAwesomeIcons.qrcode,
          label: 'Escanear',
          color: colors.pending,
          onTap: () => HapticFeedback.selectionClick(),
        )),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical:   AppConstants.spacing12,
          horizontal: AppConstants.spacing8,
        ),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border:       Border.all(
            color: color.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            FaIcon(icon, size: 18, color: color),
            const SizedBox(height: AppConstants.spacing4),
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loans list (reusable for both tabs)
// ─────────────────────────────────────────────────────────────────────────────

class _LoansList extends StatelessWidget {
  final List<LoanEntity> loans;
  final String           emptyMsg;
  final IconData         emptyIcon;
  final WayquiColors     colors;

  const _LoansList({
    required this.loans,
    required this.emptyMsg,
    required this.emptyIcon,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    if (loans.isEmpty) {
      return _EmptyTab(message: emptyMsg, icon: emptyIcon);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacing16, AppConstants.spacing12,
        AppConstants.spacing16, AppConstants.spacing80 + AppConstants.spacing16,
      ),
      itemCount:      loans.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppConstants.spacing8),
      itemBuilder:    (ctx, i) => _LoanCard(
        loan:   loans[i],
        colors: colors,
        onTap:  () => ctx.push(AppRoutes.loanDetailPath(loans[i].id)),
      ).animate().fadeIn(delay: Duration(milliseconds: i * 50), duration: 250.ms),
    );
  }
}

class _LoanCard extends StatelessWidget {
  final LoanEntity   loan;
  final WayquiColors colors;
  final VoidCallback onTap;

  const _LoanCard({required this.loan, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme     = Theme.of(context);
    final progress  = loan.progressPercent.clamp(0.0, 1.0);
    final color     = switch (loan.status) {
      LoanStatus.active        => colors.positive,
      LoanStatus.partiallyPaid => colors.pending,
      LoanStatus.paid          => colors.positive,
      _                        => colors.negative,
    };
    final name = loan.debtorName ?? 'Desconocido';

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacing12),
        decoration: BoxDecoration(
          color:        theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius:          18,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Text(_initials(name),
                      style: theme.textTheme.labelSmall?.copyWith(color: color)),
                ),
                const SizedBox(width: AppConstants.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.labelLarge),
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
                    Text(CurrencyFormatter.format(loan.remainingAmount),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color:      color,
                          fontWeight: FontWeight.w700,
                        )),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:        color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(loan.status.label,
                          style: theme.textTheme.labelSmall?.copyWith(color: color)),
                    ),
                  ],
                ),
              ],
            ),
            if (loan.paidAmount > 0) ...[
              const SizedBox(height: AppConstants.spacing8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value:           progress,
                  minHeight:       3,
                  backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.25),
                  valueColor:      AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }
}

class _EmptyTab extends StatelessWidget {
  final String   message;
  final IconData icon;
  const _EmptyTab({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(icon, size: 44,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.18)),
          const SizedBox(height: AppConstants.spacing16),
          Text(message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              )),
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
    return Center(
      child: Text(message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.error,
          )),
    );
  }
}
