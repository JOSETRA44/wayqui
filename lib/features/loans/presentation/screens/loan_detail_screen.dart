import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/wayqui_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/payment_bridge_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../domain/entities/loan_entity.dart';
import '../../domain/entities/loan_transaction_entity.dart';
import '../providers/loans_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class LoanDetailScreen extends ConsumerWidget {
  final String loanId;
  const LoanDetailScreen({super.key, required this.loanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme       = Theme.of(context);
    final detailAsync = ref.watch(loanDetailProvider(loanId));
    final uid         = ref.watch(authProvider).value?.id;

    // FAB: visible only to the debtor when the loan is still active
    Widget? fab;
    if (detailAsync case AsyncData(value: final data)) {
      final loan = LoanEntity.fromJson(
          Map<String, dynamic>.from(data['loan'] as Map? ?? data));
      if (uid != null && loan.debtorId == uid && loan.isActive) {
        fab = FloatingActionButton.extended(
          heroTag:  null,
          onPressed: () =>
              context.push(AppRoutes.registerPaymentPath(loanId)),
          icon:  const FaIcon(FontAwesomeIcons.plus, size: 14),
          label: const Text('Registrar pago'),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Detalle del Préstamo',
            style: theme.textTheme.headlineSmall),
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.arrowLeft, size: 18),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        actions: [
          IconButton(
            icon:    const FaIcon(FontAwesomeIcons.arrowsRotate, size: 16),
            tooltip: 'Actualizar',
            onPressed: () {
              HapticFeedback.selectionClick();
              ref.invalidate(loanDetailProvider(loanId));
            },
          ),
          const SizedBox(width: AppConstants.spacing8),
        ],
      ),
      floatingActionButton: fab,
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => _FullErrorView(message: e.toString()),
        data:    (data)  => _LoanDetailBody(data: data, loanId: loanId),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body
// ─────────────────────────────────────────────────────────────────────────────

class _LoanDetailBody extends ConsumerWidget {
  final Map<String, dynamic> data;
  final String               loanId;

  const _LoanDetailBody({required this.data, required this.loanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme  = Theme.of(context);
    final colors = theme.extension<WayquiColors>()!;
    final uid    = ref.watch(authProvider).value?.id;

    final loan = LoanEntity.fromJson(Map<String, dynamic>.from(
      data['loan'] as Map? ?? data,
    ));

    final rawTransactions = data['transactions'] as List? ?? [];
    final transactions = rawTransactions
        .map((t) => LoanTransactionEntity.fromJson(
            Map<String, dynamic>.from(t as Map)))
        .toList();

    final isCreditor  = loan.creditorId == uid;
    final debtorPhone = loan.debtorPhone;
    final canPayViaApp =
        loan.isActive && debtorPhone != null && isCreditor;
    final canRequestPayment =
        loan.isActive && isCreditor &&
        (loan.debtorId != null || debtorPhone != null);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(loanDetailProvider(loanId)),
      child: ListView(
        padding: const EdgeInsets.all(AppConstants.spacing16),
        children: [
          _DebtorCard(loan: loan, colors: colors)
              .animate().fadeIn(duration: 300.ms),

          const SizedBox(height: AppConstants.spacing16),

          _AmountProgress(loan: loan, colors: colors)
              .animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: AppConstants.spacing16),

          if (canPayViaApp) ...[
            _PaymentButtons(
              phone:       debtorPhone,
              amount:      loan.remainingAmount,
              description: loan.description,
              colors:      colors,
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: AppConstants.spacing16),
          ],

          if (canRequestPayment) ...[
            _RequestPaymentCard(
              loan:       loan,
              colors:     colors,
              onNotify:   loan.debtorId != null
                  ? () => _requestPayment(context, ref, loan)
                  : null,
              onWhatsApp: debtorPhone != null
                  ? () => _remindWhatsApp(loan)
                  : null,
            ).animate().fadeIn(delay: 240.ms),
            const SizedBox(height: AppConstants.spacing16),
          ],

          _SectionHeader(
              label: 'Historial de pagos',
              icon:  FontAwesomeIcons.clockRotateLeft),
          const SizedBox(height: AppConstants.spacing12),

          if (transactions.isEmpty)
            _EmptyTransactions()
          else
            ...transactions.asMap().entries.map((entry) {
              final txn = entry.value;
              return _TransactionTile(
                transaction: txn,
                isCreditor:  isCreditor,
                colors:      colors,
                onConfirm: txn.status == TransactionStatus.pending &&
                        isCreditor
                    ? () => _confirmTransaction(context, ref, txn.id)
                    : null,
                onReject: txn.status == TransactionStatus.pending &&
                        isCreditor
                    ? () => _rejectTransaction(context, ref, txn.id)
                    : null,
                onDispute: (txn.status == TransactionStatus.pending ||
                            txn.status == TransactionStatus.confirmed) &&
                        isCreditor
                    ? () => _disputeTransaction(context, ref, txn.id)
                    : null,
                onViewEvidence: txn.hasEvidence
                    ? () => _viewEvidence(context, ref, txn.evidencePath!)
                    : null,
                onShareWhatsApp:
                    txn.status == TransactionStatus.confirmed &&
                            isCreditor &&
                            loan.debtorPhone != null
                        ? () => _shareWhatsApp(loan, txn)
                        : null,
              ).animate().fadeIn(
                  delay: Duration(
                      milliseconds: 300 + entry.key * 60));
            }),

          // Bottom padding so the FAB doesn't cover the last tile
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── Creditor actions ────────────────────────────────────────────────────

  Future<void> _confirmTransaction(
    BuildContext context,
    WidgetRef ref,
    String transactionId,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConfirmDialog(),
    );
    if (ok != true) return;

    HapticFeedback.mediumImpact();
    try {
      await ref
          .read(loansProvider.notifier)
          .confirmTransaction(transactionId);
      ref.invalidate(loanDetailProvider(loanId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         const Text('Pago confirmado'),
          backgroundColor: context
              .findAncestorWidgetOfExactType<MaterialApp>() !=
              null
              ? null
              : Theme.of(context).extension<WayquiColors>()!.positive,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, e.toString());
      }
    }
  }

  Future<void> _rejectTransaction(
    BuildContext context,
    WidgetRef ref,
    String transactionId,
  ) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _ReasonDialog(
        title: 'Rechazar pago',
        hint:  '¿Por qué rechazas este pago?',
      ),
    );
    if (reason == null) return;

    HapticFeedback.mediumImpact();
    try {
      await ref.read(loansProvider.notifier).rejectTransaction(
            transactionId,
            reason: reason.isEmpty ? null : reason,
          );
      ref.invalidate(loanDetailProvider(loanId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:  Text('Pago rechazado'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, e.toString());
      }
    }
  }

  Future<void> _disputeTransaction(
    BuildContext context,
    WidgetRef ref,
    String transactionId,
  ) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _ReasonDialog(
        title: 'Disputar pago',
        hint:  '¿Por qué estás disputando este pago?',
      ),
    );
    if (reason == null) return;

    HapticFeedback.mediumImpact();
    try {
      await ref.read(loansProvider.notifier).disputeTransaction(
            transactionId,
            reason: reason.isEmpty ? null : reason,
          );
      ref.invalidate(loanDetailProvider(loanId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:  Text('Pago marcado como disputado'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, e.toString());
      }
    }
  }

  Future<void> _viewEvidence(
    BuildContext context,
    WidgetRef ref,
    String storagePath,
  ) async {
    try {
      final url =
          await ref.read(evidenceUrlProvider(storagePath).future);
      if (!context.mounted) return;
      showModalBottomSheet(
        context:       context,
        isScrollControlled: true,
        builder:       (_) => _EvidenceModal(url: url),
      );
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'No se pudo cargar la evidencia: $e');
      }
    }
  }

  Future<void> _shareWhatsApp(
      LoanEntity loan, LoanTransactionEntity txn) async {
    final phone = (loan.debtorPhone ?? '')
        .replaceAll(RegExp(r'[^\d]'), '');
    final message =
        'Confirmé tu pago de ${CurrencyFormatter.format(txn.amount)} '
        'via ${txn.paymentMethod.label}. '
        '${txn.operationId != null ? 'N° Op: ${txn.operationId}. ' : ''}'
        'Saldo pendiente: ${CurrencyFormatter.format(loan.remainingAmount)}. '
        '— Wayqui';
    final uri =
        Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _requestPayment(
    BuildContext context,
    WidgetRef    ref,
    LoanEntity   loan,
  ) async {
    HapticFeedback.mediumImpact();
    try {
      await ref.read(loansProvider.notifier).requestPayment(loan.id);
      if (!context.mounted) return;
      final name = loan.debtorName ?? 'el deudor';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:         Text('Notificación enviada a $name'),
        behavior:        SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (context.mounted) _showError(context, e.toString());
    }
  }

  Future<void> _remindWhatsApp(LoanEntity loan) async {
    final phone = (loan.debtorPhone ?? '')
        .replaceAll(RegExp(r'[^\d]'), '');
    final name = loan.debtorName ?? 'amigo/a';
    final message =
        'Hola $name, te recuerdo que tienes un pago pendiente de '
        '${CurrencyFormatter.format(loan.remainingAmount)} '
        'en Wayqui para "${loan.description}". '
        '¡Gracias!';
    final uri =
        Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text('Error: $msg'),
      backgroundColor: Theme.of(context).colorScheme.error,
      behavior:        SnackBarBehavior.floating,
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Card shown to the creditor with two quick-action buttons:
/// "Solicitar pago" (in-app notification) and "Recordar por WhatsApp".
class _RequestPaymentCard extends StatelessWidget {
  final LoanEntity   loan;
  final WayquiColors colors;
  final VoidCallback? onNotify;
  final VoidCallback? onWhatsApp;

  const _RequestPaymentCard({
    required this.loan,
    required this.colors,
    this.onNotify,
    this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacing16),
      decoration: BoxDecoration(
        color:        theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.4),
          width: AppConstants.borderWidthList,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(FontAwesomeIcons.bell,
                  size: 13, color: theme.colorScheme.primary),
              const SizedBox(width: AppConstants.spacing8),
              Text('Solicitar pago',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  )),
            ],
          ),
          const SizedBox(height: AppConstants.spacing12),
          Row(
            children: [
              if (onNotify != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onNotify,
                    icon:  const FaIcon(FontAwesomeIcons.paperPlane, size: 13),
                    label: const Text('Notificar en app'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(color: theme.colorScheme.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.borderRadius),
                      ),
                    ),
                  ),
                ),
              if (onNotify != null && onWhatsApp != null)
                const SizedBox(width: AppConstants.spacing8),
              if (onWhatsApp != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onWhatsApp,
                    icon:  const FaIcon(FontAwesomeIcons.whatsapp, size: 13),
                    label: const Text('WhatsApp'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.positive,
                      side: BorderSide(
                          color: colors.positive.withValues(alpha: 0.6)),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.borderRadius),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String   label;
  final IconData icon;
  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        FaIcon(icon, size: 14, color: theme.colorScheme.primary),
        const SizedBox(width: AppConstants.spacing8),
        Text(label, style: theme.textTheme.titleSmall?.copyWith(
          color:         theme.colorScheme.primary,
          letterSpacing: 0.4,
        )),
        const SizedBox(width: AppConstants.spacing8),
        Expanded(child: Divider(color: theme.colorScheme.outline)),
      ],
    );
  }
}

class _DebtorCard extends StatelessWidget {
  final LoanEntity   loan;
  final WayquiColors colors;
  const _DebtorCard({required this.loan, required this.colors});

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final name        = loan.debtorName ?? 'Sin nombre';
    final phone       = loan.debtorPhone;
    final statusColor = _statusColor(loan.status, colors);
    final initials    = _initials(name);

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacing16),
      decoration: BoxDecoration(
        color:        theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
        border: Border.all(
          color: theme.colorScheme.outline,
          width: AppConstants.borderWidth,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              color:  statusColor.withValues(alpha: 0.15),
              border: Border.all(color: statusColor, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(initials,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: statusColor)),
          ),
          const SizedBox(width: AppConstants.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.titleMedium),
                if (phone != null) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    FaIcon(FontAwesomeIcons.mobileScreen,
                        size: 11,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5)),
                    const SizedBox(width: 4),
                    Text(phone,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        )),
                  ]),
                ],
                const SizedBox(height: AppConstants.spacing8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color:        statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(loan.status.label,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: statusColor)),
                ),
              ],
            ),
          ),
          if (loan.dueDate != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FaIcon(FontAwesomeIcons.calendarDays,
                    size: 12,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.45)),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM', 'es').format(loan.dueDate!),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }

  Color _statusColor(LoanStatus status, WayquiColors c) => switch (status) {
        LoanStatus.active        => c.positive,
        LoanStatus.partiallyPaid => c.pending,
        LoanStatus.paid          => c.positive,
        LoanStatus.cancelled     => c.negative,
        LoanStatus.disputed      => c.negative,
      };
}

class _AmountProgress extends StatelessWidget {
  final LoanEntity   loan;
  final WayquiColors colors;
  const _AmountProgress({required this.loan, required this.colors});

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final progress    = loan.progressPercent.clamp(0.0, 1.0);
    final isFullyPaid = loan.isFullyPaid;

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacing16),
      decoration: BoxDecoration(
        color:        theme.colorScheme.surface,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Monto prestado',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      )),
                  Text(CurrencyFormatter.format(loan.amount),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                      )),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Saldo pendiente',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      )),
                  Text(
                    CurrencyFormatter.format(loan.remainingAmount),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isFullyPaid
                          ? colors.positive
                          : colors.negative,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacing12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value:           progress,
              minHeight:       8,
              backgroundColor: theme.colorScheme.outline
                  .withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                isFullyPaid ? colors.positive : colors.pending,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacing8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pagado: ${CurrencyFormatter.format(loan.paidAmount)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.positive,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          if (loan.description.isNotEmpty) ...[
            const SizedBox(height: AppConstants.spacing8),
            Divider(
                color: theme.colorScheme.outline.withValues(alpha: 0.5)),
            const SizedBox(height: AppConstants.spacing8),
            Row(children: [
              FaIcon(FontAwesomeIcons.alignLeft,
                  size: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45)),
              const SizedBox(width: AppConstants.spacing8),
              Expanded(
                child: Text(loan.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.7),
                    )),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _PaymentButtons extends StatefulWidget {
  final String     phone;
  final double     amount;
  final String     description;
  final WayquiColors colors;

  const _PaymentButtons({
    required this.phone,
    required this.amount,
    required this.description,
    required this.colors,
  });

  @override
  State<_PaymentButtons> createState() => _PaymentButtonsState();
}

class _PaymentButtonsState extends State<_PaymentButtons> {
  bool _yapeLoading = false;
  bool _plinLoading = false;

  Future<void> _openYape() async {
    setState(() => _yapeLoading = true);
    HapticFeedback.lightImpact();
    try {
      final result = await PaymentBridgeService.openYape(
        phoneNumber: widget.phone,
        amount:      widget.amount,
        description: widget.description,
      );
      _showLaunchFeedback(result, 'Yape');
    } finally {
      if (mounted) setState(() => _yapeLoading = false);
    }
  }

  Future<void> _openPlin() async {
    setState(() => _plinLoading = true);
    HapticFeedback.lightImpact();
    try {
      final result = await PaymentBridgeService.openPlin(
        phoneNumber: widget.phone,
        amount:      widget.amount,
      );
      _showLaunchFeedback(result, 'Plin');
    } finally {
      if (mounted) setState(() => _plinLoading = false);
    }
  }

  void _showLaunchFeedback(LaunchResult result, String app) {
    if (!mounted) return;
    final msg = switch (result) {
      LaunchResult.success      => 'Número copiado — continúa en $app',
      LaunchResult.openedStore  => '$app no instalado — redirigido a Play Store',
      LaunchResult.notInstalled => 'No se pudo abrir $app',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:  Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: result == LaunchResult.success
          ? widget.colors.positive
          : Theme.of(context).colorScheme.secondary,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          label: 'Cobrar por app',
          icon:  FontAwesomeIcons.mobileScreen,
        ),
        const SizedBox(height: AppConstants.spacing12),
        Row(children: [
          Expanded(
            child: _AppPayButton(
              label:     'Cobrar por\nYape',
              color:     widget.colors.yape,
              isLoading: _yapeLoading,
              icon:      FontAwesomeIcons.y,
              amount:    widget.amount,
              onTap:     _openYape,
            ),
          ),
          const SizedBox(width: AppConstants.spacing12),
          Expanded(
            child: _AppPayButton(
              label:     'Cobrar por\nPlin',
              color:     widget.colors.plin,
              isLoading: _plinLoading,
              icon:      FontAwesomeIcons.p,
              amount:    widget.amount,
              onTap:     _openPlin,
            ),
          ),
        ]),
        const SizedBox(height: AppConstants.spacing8),
        Row(children: [
          FaIcon(FontAwesomeIcons.copy,
              size: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
          const SizedBox(width: 6),
          Text(
            'El número se copiará automáticamente.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ]),
      ],
    );
  }
}

class _AppPayButton extends StatelessWidget {
  final String     label;
  final Color      color;
  final bool       isLoading;
  final IconData   icon;
  final double     amount;
  final VoidCallback onTap;

  const _AppPayButton({
    required this.label,
    required this.color,
    required this.isLoading,
    required this.icon,
    required this.amount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacing16,
          vertical:   AppConstants.spacing12,
        ),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: Border.all(
              color: color, width: AppConstants.borderWidth),
        ),
        child: isLoading
            ? Center(
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: color),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FaIcon(icon, size: 18, color: color),
                  const SizedBox(height: AppConstants.spacing8),
                  Text(label,
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: color)),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.format(amount),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Transaction tile
// ─────────────────────────────────────────────────────────────────────────────

class _TransactionTile extends StatelessWidget {
  final LoanTransactionEntity transaction;
  final bool                  isCreditor;
  final WayquiColors          colors;
  final VoidCallback?         onConfirm;
  final VoidCallback?         onReject;
  final VoidCallback?         onDispute;
  final VoidCallback?         onViewEvidence;
  final VoidCallback?         onShareWhatsApp;

  const _TransactionTile({
    required this.transaction,
    required this.isCreditor,
    required this.colors,
    this.onConfirm,
    this.onReject,
    this.onDispute,
    this.onViewEvidence,
    this.onShareWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final status = transaction.status;
    final color  = switch (status) {
      TransactionStatus.confirmed => colors.positive,
      TransactionStatus.rejected  => colors.negative,
      TransactionStatus.disputed  => colors.negative,
      TransactionStatus.pending   => colors.pending,
    };
    final statusLabel = switch (status) {
      TransactionStatus.confirmed => 'Confirmado',
      TransactionStatus.rejected  => 'Rechazado',
      TransactionStatus.disputed  => 'En disputa',
      TransactionStatus.pending   => 'Pendiente',
    };
    final fmt  = DateFormat('dd MMM yyyy • HH:mm', 'es');
    final icon = switch (transaction.paymentMethod) {
      PaymentMethod.yape         => FontAwesomeIcons.mobileRetro,
      PaymentMethod.plin         => FontAwesomeIcons.mobileRetro,
      PaymentMethod.cash         => FontAwesomeIcons.moneyBill,
      PaymentMethod.bankTransfer => FontAwesomeIcons.buildingColumns,
      PaymentMethod.other        => FontAwesomeIcons.circleDollarToSlot,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spacing12),
      padding: const EdgeInsets.all(AppConstants.spacing12),
      decoration: BoxDecoration(
        color:        theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: AppConstants.borderWidthList,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────────
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
              ),
              child: Center(
                  child: FaIcon(icon, size: 14, color: color)),
            ),
            const SizedBox(width: AppConstants.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(transaction.paymentMethod.label,
                          style: theme.textTheme.labelLarge),
                      Text(
                        CurrencyFormatter.format(transaction.amount),
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: color),
                      ),
                    ],
                  ),
                  Text(
                    fmt.format(transaction.createdAt.toLocal()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ]),

          // ── Status + primary actions ──────────────────────────────
          const SizedBox(height: AppConstants.spacing8),
          Row(
            children: [
              // Status chip
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:        color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                      color: color.withValues(alpha: 0.3)),
                ),
                child: Text(statusLabel,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: color)),
              ),
              const Spacer(),
              // Confirm
              if (onConfirm != null)
                _ActionButton(
                  icon:  FontAwesomeIcons.check,
                  label: 'Confirmar',
                  color: colors.positive,
                  onTap: onConfirm!,
                ),
              // Reject
              if (onReject != null) ...[
                const SizedBox(width: 4),
                _ActionButton(
                  icon:  FontAwesomeIcons.xmark,
                  label: 'Rechazar',
                  color: colors.negative,
                  onTap: onReject!,
                ),
              ],
              // Dispute
              if (onDispute != null) ...[
                const SizedBox(width: 4),
                _ActionButton(
                  icon:  FontAwesomeIcons.triangleExclamation,
                  label: 'Disputar',
                  color: colors.pending,
                  onTap: onDispute!,
                ),
              ],
            ],
          ),

          // ── Operation ID ──────────────────────────────────────────
          if (transaction.operationId != null) ...[
            const SizedBox(height: AppConstants.spacing8),
            Row(children: [
              FaIcon(FontAwesomeIcons.hashtag,
                  size: 10,
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: 0.4)),
              const SizedBox(width: 5),
              Text('Op. ${transaction.operationId}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.55),
                    fontFamily: 'monospace',
                  )),
            ]),
          ],

          // ── Notes ─────────────────────────────────────────────────
          if (transaction.notes != null) ...[
            const SizedBox(height: AppConstants.spacing8),
            Row(children: [
              FaIcon(FontAwesomeIcons.comment,
                  size: 11,
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(transaction.notes!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.6),
                    )),
              ),
            ]),
          ],

          // ── Secondary actions: evidence + WhatsApp ────────────────
          if (onViewEvidence != null || onShareWhatsApp != null) ...[
            const SizedBox(height: AppConstants.spacing8),
            Row(children: [
              if (onViewEvidence != null)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding:       const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: theme.colorScheme.primary,
                  ),
                  onPressed: onViewEvidence,
                  icon: const FaIcon(
                      FontAwesomeIcons.image, size: 11),
                  label: Text('Ver evidencia',
                      style: theme.textTheme.labelSmall),
                ),
              if (onShareWhatsApp != null) ...[
                const SizedBox(width: 4),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding:       const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: const Color(0xFF25D366),
                  ),
                  onPressed: onShareWhatsApp,
                  icon: const FaIcon(
                      FontAwesomeIcons.whatsapp, size: 11),
                  label: Text('Compartir',
                      style: theme.textTheme.labelSmall),
                ),
              ],
            ]),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        padding:         const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        foregroundColor: color,
        tapTargetSize:   MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onTap,
      icon:  FaIcon(icon, size: 11),
      label: Text(label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: color)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialogs
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog();

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final colors = theme.extension<WayquiColors>()!;
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        side: BorderSide(
            color: theme.colorScheme.outline,
            width: AppConstants.borderWidth),
      ),
      title:   Text('Confirmar pago', style: theme.textTheme.titleMedium),
      content: Text(
        '¿Confirmas que recibiste este pago? '
        'Esta acción actualizará el balance del préstamo.',
        style: theme.textTheme.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child:     const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.positive,
            foregroundColor: Colors.white,
            elevation:       0,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppConstants.borderRadius),
              side: BorderSide(color: theme.colorScheme.outline),
            ),
          ),
          onPressed: () {
            HapticFeedback.mediumImpact();
            Navigator.pop(context, true);
          },
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

class _ReasonDialog extends StatefulWidget {
  final String title;
  final String hint;
  const _ReasonDialog({required this.title, required this.hint});

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        side: BorderSide(
            color: theme.colorScheme.outline,
            width: AppConstants.borderWidth),
      ),
      title:   Text(widget.title, style: theme.textTheme.titleMedium),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.hint, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppConstants.spacing12),
          TextField(
            controller: _ctrl,
            maxLines:   3,
            maxLength:  200,
            decoration: const InputDecoration(
              hintText:     'Motivo (opcional)',
              border:       OutlineInputBorder(),
              counterText:  '',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:     const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(elevation: 0),
          onPressed: () {
            HapticFeedback.mediumImpact();
            Navigator.pop(context, _ctrl.text.trim());
          },
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Evidence modal
// ─────────────────────────────────────────────────────────────────────────────

class _EvidenceModal extends StatelessWidget {
  final String url;
  const _EvidenceModal({required this.url});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand:          false,
      initialChildSize: 0.75,
      maxChildSize:    0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color:        theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppConstants.borderRadiusLarge)),
        ),
        child: Column(
          children: [
            const SizedBox(height: AppConstants.spacing8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppConstants.spacing16),
              child: Row(children: [
                FaIcon(FontAwesomeIcons.image,
                    size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: AppConstants.spacing8),
                Text('Comprobante de pago',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    )),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacing16),
                child: Image.network(
                  url,
                  fit:          BoxFit.contain,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                        child: CircularProgressIndicator());
                  },
                  errorBuilder: (_, __, ___) => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppConstants.spacing32),
                      child: Text('No se pudo cargar la imagen'),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spacing16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty / error states
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyTransactions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacing24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
      child: Column(children: [
        FaIcon(FontAwesomeIcons.clockRotateLeft,
            size: 28,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.25)),
        const SizedBox(height: AppConstants.spacing12),
        Text('Sin pagos registrados',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            )),
      ]),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _FullErrorView extends StatelessWidget {
  final String message;
  const _FullErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(FontAwesomeIcons.triangleExclamation,
                size: 40, color: theme.colorScheme.error),
            const SizedBox(height: AppConstants.spacing16),
            Text('No se pudo cargar el préstamo',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: AppConstants.spacing8),
            Text(message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
