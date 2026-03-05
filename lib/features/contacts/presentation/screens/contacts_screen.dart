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
import '../../../loans/domain/entities/loan_entity.dart';
import '../../../loans/presentation/providers/loans_providers.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

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
            title:           Text('Contactos', style: theme.textTheme.headlineSmall),
          ),

          loansAsync.when(
            loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverFillRemaining(
                child: Center(child: Text(e.toString()))),
            data: (snapshot) {
              // Extraer contactos únicos de todos los préstamos
              final contacts = _extractContacts([
                ...snapshot.asCreditor,
                ...snapshot.asDebtor,
              ]);

              if (contacts.isEmpty) {
                return const SliverFillRemaining(child: _EmptyContacts());
              }

              return SliverPadding(
                padding: const EdgeInsets.all(AppConstants.spacing16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final contact = contacts[i];
                      return _ContactTile(
                        contact: contact,
                        colors:  colors,
                        onTap:   () => ctx.push(
                          AppRoutes.loanDetailPath(contact.recentLoanId),
                        ),
                        onNewLoan: () => ctx.push(AppRoutes.createLoan),
                      ).animate().fadeIn(
                        delay: Duration(milliseconds: i * 50),
                        duration: 300.ms,
                      );
                    },
                    childCount: contacts.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          context.push(AppRoutes.createLoan);
        },
        backgroundColor: theme.colorScheme.primary,
        elevation:       0,
        child: const FaIcon(FontAwesomeIcons.userPlus, size: 18),
      ),
    );
  }

  List<_ContactData> _extractContacts(List<LoanEntity> loans) {
    final map = <String, _ContactData>{};
    for (final loan in loans) {
      final key  = loan.debtorPhone ?? loan.debtorId ?? loan.debtorName ?? 'unknown';
      final name = loan.debtorName ?? 'Desconocido';
      final phone = loan.debtorPhone;

      if (map.containsKey(key)) {
        map[key] = map[key]!.copyWith(
          totalAmount:  map[key]!.totalAmount + loan.remainingAmount,
          recentLoanId: loan.id,
        );
      } else {
        map[key] = _ContactData(
          name:         name,
          phone:        phone,
          totalAmount:  loan.remainingAmount,
          recentLoanId: loan.id,
        );
      }
    }

    final list = map.values.toList();
    list.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    return list;
  }
}

class _ContactData {
  final String  name;
  final String? phone;
  final double  totalAmount;
  final String  recentLoanId;

  const _ContactData({
    required this.name,
    this.phone,
    required this.totalAmount,
    required this.recentLoanId,
  });

  _ContactData copyWith({
    double? totalAmount,
    String? recentLoanId,
  }) =>
      _ContactData(
        name:         name,
        phone:        phone,
        totalAmount:  totalAmount  ?? this.totalAmount,
        recentLoanId: recentLoanId ?? this.recentLoanId,
      );

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }
}

class _ContactTile extends StatelessWidget {
  final _ContactData contact;
  final WayquiColors colors;
  final VoidCallback onTap;
  final VoidCallback onNewLoan;

  const _ContactTile({
    required this.contact,
    required this.colors,
    required this.onTap,
    required this.onNewLoan,
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
          color: theme.colorScheme.outline.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacing16,
          vertical:   AppConstants.spacing8,
        ),
        leading: CircleAvatar(
          radius:          22,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          child: Text(
            contact.initials,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        title: Text(contact.name, style: theme.textTheme.labelLarge),
        subtitle: contact.phone != null
            ? Text(contact.phone!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize:      MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(contact.totalAmount),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: contact.totalAmount > 0 ? colors.negative : colors.positive,
                  ),
                ),
                Text('saldo',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                    )),
              ],
            ),
            const SizedBox(width: AppConstants.spacing8),
            FaIcon(FontAwesomeIcons.chevronRight, size: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          ],
        ),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
      ),
    );
  }
}

class _EmptyContacts extends StatelessWidget {
  const _EmptyContacts();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(FontAwesomeIcons.userGroup, size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: AppConstants.spacing16),
          Text('Sin contactos aún',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              )),
          const SizedBox(height: AppConstants.spacing8),
          Text('Tus contactos aparecerán aquí\ncuando registres préstamos.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
              textAlign: TextAlign.center),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}
