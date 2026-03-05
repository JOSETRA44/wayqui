import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/wayqui_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../loans/presentation/providers/loans_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme   = Theme.of(context);
    final colors  = theme.extension<WayquiColors>()!;
    final user    = ref.watch(authProvider).value;
    final summary = ref.watch(userSummaryProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned:          true,
            expandedHeight:  180,
            backgroundColor: theme.colorScheme.surface,
            elevation:       0,
            flexibleSpace: FlexibleSpaceBar(
              background: _ProfileHeader(user: user, colors: colors),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(AppConstants.spacing16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Stats ────────────────────────────────────────
                summary.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error:   (_, __) => const SizedBox.shrink(),
                  data: (data) => _StatsRow(data: data, colors: colors)
                      .animate().fadeIn(delay: 100.ms),
                ),

                const SizedBox(height: AppConstants.spacing24),

                // ── Sección: Cuenta ───────────────────────────────
                _SectionLabel(label: 'Cuenta'),
                const SizedBox(height: AppConstants.spacing8),

                _ProfileTile(
                  icon:    FontAwesomeIcons.solidUser,
                  label:   'Nombre',
                  value:   user?.displayName ?? '—',
                  onTap:   null, // TODO: edit profile
                ),
                _ProfileTile(
                  icon:    FontAwesomeIcons.envelope,
                  label:   'Email',
                  value:   user?.email ?? '—',
                  onTap:   null,
                ),
                _ProfileTile(
                  icon:    FontAwesomeIcons.mobileScreen,
                  label:   'Teléfono',
                  value:   user?.phoneNumber ?? 'Sin número',
                  onTap:   null,
                ),

                const SizedBox(height: AppConstants.spacing24),

                // ── Sección: Seguridad ───────────────────────────
                _SectionLabel(label: 'Seguridad'),
                const SizedBox(height: AppConstants.spacing8),

                _ProfileTile(
                  icon:    FontAwesomeIcons.lock,
                  label:   'Cambiar contraseña',
                  value:   '',
                  onTap:   () {}, // TODO
                ),

                const SizedBox(height: AppConstants.spacing24),

                // ── Cerrar sesión ────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _confirmSignOut(context, ref);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side:            BorderSide(color: theme.colorScheme.error, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacing16),
                    ),
                    icon:  const FaIcon(FontAwesomeIcons.rightFromBracket, size: 16),
                    label: const Text('Cerrar sesión'),
                  ),
                ).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: AppConstants.spacing32),

                // ── Version ─────────────────────────────────────
                Center(
                  child: Text('Wayqui v1.0.0',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                      )),
                ),
                const SizedBox(height: AppConstants.spacing16),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      // dialogContext pertenece al navigator raíz donde se empujó el diálogo,
      // evitando el conflicto con el branch navigator del shell.
      builder: (dialogContext) => AlertDialog(
        title:   Text('Cerrar sesión',
            style: Theme.of(context).textTheme.titleMedium),
        content: Text('¿Estás seguro que quieres salir?',
            style: Theme.of(context).textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              // 1. Cerrar el diálogo en su propio navigator (root).
              dialogContext.pop();
              // 2. Diferir signOut al siguiente frame para que el pop
              //    se complete antes de que el redirect de GoRouter dispare,
              //    evitando la aserción currentConfiguration.isNotEmpty.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(authProvider.notifier).signOut();
              });
            },
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final dynamic      user;
  final WayquiColors colors;
  const _ProfileHeader({required this.user, required this.colors});

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final name     = user?.displayName ?? '...';
    final email    = user?.email ?? '';
    final initials = _initials(name);

    return Container(
      alignment: Alignment.bottomLeft,
      padding:   const EdgeInsets.fromLTRB(
        AppConstants.spacing24, 0, AppConstants.spacing24, AppConstants.spacing16,
      ),
      child: Row(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              color:  theme.colorScheme.primary.withValues(alpha: 0.12),
              border: Border.all(color: theme.colorScheme.primary, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(initials,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                )),
          ),
          const SizedBox(width: AppConstants.spacing16),
          Expanded(
            child: Column(
              mainAxisSize:       MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(email,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }
}

class _StatsRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final WayquiColors         colors;
  const _StatsRow({required this.data, required this.colors});

  @override
  Widget build(BuildContext context) {
    final owed       = (data['total_owed'] as num?)?.toDouble() ?? 0;
    final debt       = (data['total_debt'] as num?)?.toDouble() ?? 0;
    final netBalance = (data['net_balance'] as num?)?.toDouble() ?? 0;
    final isPositive = netBalance >= 0;

    return Row(
      children: [
        Expanded(child: _StatCard(
          label: 'Me deben',
          value: CurrencyFormatter.format(owed),
          color: colors.positive,
        )),
        const SizedBox(width: AppConstants.spacing8),
        Expanded(child: _StatCard(
          label: 'Debo',
          value: CurrencyFormatter.format(debt),
          color: colors.negative,
        )),
        const SizedBox(width: AppConstants.spacing8),
        Expanded(child: _StatCard(
          label: 'Balance',
          value: '${isPositive ? '+' : '-'}${CurrencyFormatter.format(netBalance.abs())}',
          color: isPositive ? colors.positive : colors.negative,
        )),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacing12),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border:       Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(value,
              style: theme.textTheme.labelLarge?.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              )),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(label,
        style: theme.textTheme.labelSmall?.copyWith(
          color:         theme.colorScheme.onSurface.withValues(alpha: 0.45),
          letterSpacing: 1.2,
        ));
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final String       value;
  final VoidCallback? onTap;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spacing8),
      decoration: BoxDecoration(
        color:        theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border:       Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: ListTile(
        dense:         true,
        leading:       FaIcon(icon, size: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
        title:         Text(label, style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
        )),
        subtitle:      value.isNotEmpty
            ? Text(value, style: theme.textTheme.bodyMedium)
            : null,
        trailing:      onTap != null
            ? FaIcon(FontAwesomeIcons.chevronRight, size: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3))
            : null,
        onTap:         onTap != null ? () {
          HapticFeedback.selectionClick();
          onTap!();
        } : null,
      ),
    );
  }
}
