import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/wayqui_colors.dart';
import '../../../../core/services/file_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/loan_entity.dart';
import '../../domain/entities/loan_transaction_entity.dart';
import '../providers/loans_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class RegisterPaymentScreen extends ConsumerStatefulWidget {
  final String loanId;
  const RegisterPaymentScreen({super.key, required this.loanId});

  @override
  ConsumerState<RegisterPaymentScreen> createState() =>
      _RegisterPaymentScreenState();
}

class _RegisterPaymentScreenState
    extends ConsumerState<RegisterPaymentScreen> {
  final _formKey         = GlobalKey<FormState>();
  final _amountCtrl      = TextEditingController();
  final _operationIdCtrl = TextEditingController();
  final _notesCtrl       = TextEditingController();

  PaymentMethod _method           = PaymentMethod.yape;
  XFile?        _compressedImage;
  OcrPaymentResult? _ocrResult;
  bool          _isSubmitting     = false;
  bool          _isProcessingImage = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _operationIdCtrl.dispose();
    _notesCtrl.dispose();
    FileService.disposeOcr(); // release ML Kit model — fire and forget
    super.dispose();
  }

  // ── Image handling ───────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: source, imageQuality: 100);
    if (picked == null) return;

    setState(() => _isProcessingImage = true);
    try {
      final compressed = await FileService.compressForUpload(picked);
      final ocr        = await FileService.extractPaymentInfo(compressed);
      setState(() {
        _compressedImage = compressed;
        _ocrResult       = ocr;
        // Pre-fill fields only if user hasn't typed yet
        if (ocr.amount != null && _amountCtrl.text.isEmpty) {
          _amountCtrl.text = ocr.amount!.toStringAsFixed(2);
        }
        if (ocr.operationId != null && _operationIdCtrl.text.isEmpty) {
          _operationIdCtrl.text = ocr.operationId!;
        }
      });
    } finally {
      if (mounted) setState(() => _isProcessingImage = false);
    }
  }

  void _removeImage() {
    setState(() {
      _compressedImage = null;
      _ocrResult       = null;
    });
  }

  // ── Submit ───────────────────────────────────────────────────────────────

  Future<void> _submit(LoanEntity loan) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isSubmitting) return;

    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);

    try {
      final repo   = ref.read(loansRepositoryProvider);
      final amount = double.parse(
          _amountCtrl.text.trim().replaceAll(',', '.'));

      // 1. Save local backup before any network operation
      if (_compressedImage != null) {
        await FileService.saveLocalCopy(
            _compressedImage!, 'pending_${loan.id}');
      }

      // 2. Upload evidence to Supabase Storage
      String? storagePath;
      if (_compressedImage != null) {
        storagePath = await repo.uploadPaymentEvidence(
          loanId:        loan.id,
          localFilePath: _compressedImage!.path,
        );
      }

      // 3. Build OCR metadata
      Map<String, dynamic>? metadata;
      if (_ocrResult != null && _ocrResult!.success) {
        metadata = {
          if (_ocrResult!.amount      != null) 'ocr_amount':       _ocrResult!.amount,
          if (_ocrResult!.operationId != null) 'ocr_operation_id': _ocrResult!.operationId,
        };
      }

      // 4. Register payment via RPC
      final operationId = _operationIdCtrl.text.trim();
      final notes       = _notesCtrl.text.trim();
      await repo.registerPayment(
        loanId:          loan.id,
        amount:          amount,
        paymentMethod:   _method,
        notes:           notes.isEmpty ? null : notes,
        operationId:     operationId.isEmpty ? null : operationId,
        evidencePath:    storagePath,
        paymentMetadata: metadata,
      );

      // 5. Cleanup local backup
      if (_compressedImage != null) {
        await FileService.deleteLocalCopy('pending_${loan.id}');
      }

      // 6. Invalidate providers
      ref.invalidate(loanDetailProvider(widget.loanId));
      ref.invalidate(loansProvider);
      ref.invalidate(userSummaryProvider);

      if (!mounted) return;

      // 7. Capture messenger before popping
      final messenger = ScaffoldMessenger.of(context);
      final colors    = Theme.of(context).extension<WayquiColors>()!;
      context.pop();
      messenger.showSnackBar(SnackBar(
        content:         const Text('Pago registrado. Tu evidencia está segura.'),
        backgroundColor: colors.positive,
        behavior:        SnackBarBehavior.floating,
      ));
    } catch (e, st) {
      // Log ALWAYS — before the mounted check so silent failures become visible.
      debugPrint('[RegisterPayment] ERROR: $e');
      debugPrint('[RegisterPayment] STACK: $st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:         Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior:        SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final colors      = theme.extension<WayquiColors>()!;
    final detailAsync = ref.watch(loanDetailProvider(widget.loanId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Registrar pago',
            style: theme.textTheme.headlineSmall),
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.arrowLeft, size: 18),
          onPressed: _isSubmitting
              ? null
              : () => context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => _ErrorBody(message: e.toString()),
        data:    (data)  {
          final loan = LoanEntity.fromJson(
              Map<String, dynamic>.from(data['loan'] as Map? ?? data));
          return _FormBody(
            loan:               loan,
            formKey:            _formKey,
            amountCtrl:         _amountCtrl,
            operationIdCtrl:    _operationIdCtrl,
            notesCtrl:          _notesCtrl,
            method:             _method,
            compressedImage:    _compressedImage,
            ocrResult:          _ocrResult,
            isSubmitting:       _isSubmitting,
            isProcessingImage:  _isProcessingImage,
            colors:             colors,
            onMethodChanged:    (m) => setState(() => _method = m),
            onPickCamera:       () => _pickImage(ImageSource.camera),
            onPickGallery:      () => _pickImage(ImageSource.gallery),
            onRemoveImage:      _removeImage,
            onSubmit:           () => _submit(loan),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form body (stateless, rebuilds on parent setState)
// ─────────────────────────────────────────────────────────────────────────────

class _FormBody extends StatelessWidget {
  final LoanEntity             loan;
  final GlobalKey<FormState>   formKey;
  final TextEditingController  amountCtrl;
  final TextEditingController  operationIdCtrl;
  final TextEditingController  notesCtrl;
  final PaymentMethod          method;
  final XFile?                 compressedImage;
  final OcrPaymentResult?      ocrResult;
  final bool                   isSubmitting;
  final bool                   isProcessingImage;
  final WayquiColors           colors;
  final ValueChanged<PaymentMethod> onMethodChanged;
  final VoidCallback           onPickCamera;
  final VoidCallback           onPickGallery;
  final VoidCallback           onRemoveImage;
  final VoidCallback           onSubmit;

  const _FormBody({
    required this.loan,
    required this.formKey,
    required this.amountCtrl,
    required this.operationIdCtrl,
    required this.notesCtrl,
    required this.method,
    required this.compressedImage,
    required this.ocrResult,
    required this.isSubmitting,
    required this.isProcessingImage,
    required this.colors,
    required this.onMethodChanged,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onRemoveImage,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppConstants.spacing16),
        children: [
          // ── Loan summary card ─────────────────────────────────────
          _LoanSummaryCard(loan: loan, colors: colors)
              .animate().fadeIn(duration: 250.ms),

          const SizedBox(height: AppConstants.spacing24),

          // ── Method selection ──────────────────────────────────────
          _SectionLabel(label: 'Método de pago',
              icon: FontAwesomeIcons.creditCard),
          const SizedBox(height: AppConstants.spacing12),
          _MethodSelector(
            selected:  method,
            onChanged: onMethodChanged,
            colors:    colors,
          ).animate().fadeIn(delay: 80.ms),

          const SizedBox(height: AppConstants.spacing24),

          // ── Amount ────────────────────────────────────────────────
          _SectionLabel(label: 'Monto a pagar',
              icon: FontAwesomeIcons.coins),
          const SizedBox(height: AppConstants.spacing12),
          TextFormField(
            controller:    amountCtrl,
            keyboardType:  const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText:    CurrencyFormatter.format(loan.remainingAmount),
              helperText:  'Saldo pendiente: ${CurrencyFormatter.format(loan.remainingAmount)}',
              prefixText:  'S/ ',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Ingresa el monto';
              }
              final parsed =
                  double.tryParse(v.trim().replaceAll(',', '.'));
              if (parsed == null || parsed <= 0) {
                return 'Monto inválido';
              }
              if (parsed > loan.remainingAmount + 0.001) {
                return 'No puede superar el saldo pendiente '
                    '(${CurrencyFormatter.format(loan.remainingAmount)})';
              }
              return null;
            },
          ).animate().fadeIn(delay: 120.ms),

          const SizedBox(height: AppConstants.spacing24),

          // ── Evidence ──────────────────────────────────────────────
          _SectionLabel(
            label: method == PaymentMethod.cash
                ? 'Comprobante (opcional)'
                : 'Comprobante',
            icon: FontAwesomeIcons.image,
          ),
          const SizedBox(height: AppConstants.spacing8),

          if (method == PaymentMethod.yape ||
              method == PaymentMethod.plin) ...[
            _BridgeHint(method: method, loan: loan, colors: colors),
            const SizedBox(height: AppConstants.spacing12),
          ],

          if (method == PaymentMethod.cash) ...[
            _CashHint(colors: colors),
            const SizedBox(height: AppConstants.spacing12),
          ],

          if (isProcessingImage)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: AppConstants.spacing16),
              child: CircularProgressIndicator(),
            ))
          else if (compressedImage != null)
            _EvidencePreview(
              image:     compressedImage!,
              ocr:       ocrResult,
              onRemove:  onRemoveImage,
              colors:    colors,
            ).animate().fadeIn(duration: 300.ms)
          else
            _ImagePickRow(
              onCamera:  onPickCamera,
              onGallery: onPickGallery,
              colors:    colors,
            ).animate().fadeIn(delay: 160.ms),

          const SizedBox(height: AppConstants.spacing24),

          // ── Operation ID (Yape / Plin / Transfer) ─────────────────
          if (method == PaymentMethod.yape    ||
              method == PaymentMethod.plin    ||
              method == PaymentMethod.bankTransfer) ...[
            _SectionLabel(label: 'N° de operación',
                icon: FontAwesomeIcons.hashtag),
            const SizedBox(height: AppConstants.spacing12),
            TextFormField(
              controller:     operationIdCtrl,
              keyboardType:   TextInputType.text,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'Ej. 123456789',
                helperText: 'Opcional — mejora la verificación',
              ),
            ).animate().fadeIn(delay: 160.ms),
            const SizedBox(height: AppConstants.spacing24),
          ],

          // ── Notes ─────────────────────────────────────────────────
          _SectionLabel(label: 'Notas', icon: FontAwesomeIcons.comment),
          const SizedBox(height: AppConstants.spacing12),
          TextFormField(
            controller:     notesCtrl,
            maxLines:       3,
            maxLength:      200,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'Información adicional (opcional)',
            ),
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: AppConstants.spacing32),

          // ── Submit ────────────────────────────────────────────────
          FilledButton.icon(
            onPressed: isSubmitting ? null : onSubmit,
            icon: isSubmitting
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const FaIcon(FontAwesomeIcons.paperPlane, size: 14),
            label: Text(isSubmitting ? 'Registrando...' : 'Registrar pago'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppConstants.borderRadius),
                side: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                    width: AppConstants.borderWidth),
              ),
            ),
          ).animate().fadeIn(delay: 250.ms),

          const SizedBox(height: AppConstants.spacing32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String   label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        FaIcon(icon, size: 13, color: theme.colorScheme.primary),
        const SizedBox(width: AppConstants.spacing8),
        Text(label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            )),
      ],
    );
  }
}

class _LoanSummaryCard extends StatelessWidget {
  final LoanEntity   loan;
  final WayquiColors colors;
  const _LoanSummaryCard({required this.loan, required this.colors});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacing16),
      decoration: BoxDecoration(
        color:        theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: AppConstants.borderWidthList,
        ),
      ),
      child: Row(
        children: [
          FaIcon(FontAwesomeIcons.fileInvoiceDollar,
              size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: AppConstants.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loan.description,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  'Saldo: ${CurrencyFormatter.format(loan.remainingAmount)} '
                  '/ ${CurrencyFormatter.format(loan.amount)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodSelector extends StatelessWidget {
  final PaymentMethod              selected;
  final ValueChanged<PaymentMethod> onChanged;
  final WayquiColors               colors;
  const _MethodSelector({
    required this.selected,
    required this.onChanged,
    required this.colors,
  });

  Color _colorFor(PaymentMethod m) => switch (m) {
        PaymentMethod.yape         => colors.yape,
        PaymentMethod.plin         => colors.plin,
        PaymentMethod.cash         => colors.positive,
        PaymentMethod.bankTransfer => colors.pending,
        PaymentMethod.other        => colors.negative,
      };

  IconData _iconFor(PaymentMethod m) => switch (m) {
        PaymentMethod.yape         => FontAwesomeIcons.mobileRetro,
        PaymentMethod.plin         => FontAwesomeIcons.mobileRetro,
        PaymentMethod.cash         => FontAwesomeIcons.moneyBill,
        PaymentMethod.bankTransfer => FontAwesomeIcons.buildingColumns,
        PaymentMethod.other        => FontAwesomeIcons.circleDollarToSlot,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: AppConstants.spacing8,
      runSpacing: AppConstants.spacing8,
      children: PaymentMethod.values.map((m) {
        final isSelected = m == selected;
        final color      = _colorFor(m);
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(m);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.15)
                  : theme.colorScheme.surface,
              borderRadius:
                  BorderRadius.circular(AppConstants.borderRadius),
              border: Border.all(
                color: isSelected
                    ? color
                    : theme.colorScheme.outline.withValues(alpha: 0.5),
                width: isSelected
                    ? AppConstants.borderWidth
                    : AppConstants.borderWidthList,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(_iconFor(m),
                    size: 13,
                    color: isSelected
                        ? color
                        : theme.colorScheme.onSurface
                            .withValues(alpha: 0.5)),
                const SizedBox(width: 6),
                Text(m.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isSelected
                          ? color
                          : theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _BridgeHint extends StatelessWidget {
  final PaymentMethod method;
  final LoanEntity    loan;
  final WayquiColors  colors;
  const _BridgeHint({
    required this.method,
    required this.loan,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = method == PaymentMethod.yape ? colors.yape : colors.plin;
    final label = method == PaymentMethod.yape ? 'Yape' : 'Plin';

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacing12),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: AppConstants.borderWidthList),
      ),
      child: Row(
        children: [
          FaIcon(FontAwesomeIcons.mobileRetro, size: 14, color: color),
          const SizedBox(width: AppConstants.spacing12),
          Expanded(
            child: Text(
              'Luego de pagar por $label, adjunta la captura de pantalla '
              'del comprobante.',
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _CashHint extends StatelessWidget {
  final WayquiColors colors;
  const _CashHint({required this.colors});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacing12),
      decoration: BoxDecoration(
        color:        colors.positive.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(
            color: colors.positive.withValues(alpha: 0.3),
            width: AppConstants.borderWidthList),
      ),
      child: Row(
        children: [
          FaIcon(FontAwesomeIcons.moneyBill, size: 14, color: colors.positive),
          const SizedBox(width: AppConstants.spacing12),
          Expanded(
            child: Text(
              'Para pagos en efectivo la foto es opcional. '
              'Puedes añadir una nota describiendo el acuerdo.',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.positive),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePickRow extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final WayquiColors colors;
  const _ImagePickRow({
    required this.onCamera,
    required this.onGallery,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: _PickButton(
            icon:    FontAwesomeIcons.camera,
            label:   'Cámara',
            color:   theme.colorScheme.primary,
            onTap:   onCamera,
          ),
        ),
        const SizedBox(width: AppConstants.spacing12),
        Expanded(
          child: _PickButton(
            icon:    FontAwesomeIcons.images,
            label:   'Galería',
            color:   theme.colorScheme.primary,
            onTap:   onGallery,
          ),
        ),
      ],
    );
  }
}

class _PickButton extends StatelessWidget {
  final IconData   icon;
  final String     label;
  final Color      color;
  final VoidCallback onTap;
  const _PickButton({
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
        padding: const EdgeInsets.symmetric(vertical: AppConstants.spacing16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: Border.all(
            color:  theme.colorScheme.outline,
            width:  AppConstants.borderWidthList,
          ),
        ),
        child: Column(
          children: [
            FaIcon(icon, size: 20,
                color: color.withValues(alpha: 0.7)),
            const SizedBox(height: AppConstants.spacing8),
            Text(label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                )),
          ],
        ),
      ),
    );
  }
}

class _EvidencePreview extends StatelessWidget {
  final XFile            image;
  final OcrPaymentResult? ocr;
  final VoidCallback     onRemove;
  final WayquiColors     colors;
  const _EvidencePreview({
    required this.image,
    required this.ocr,
    required this.onRemove,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacing12),
      decoration: BoxDecoration(
        color:        colors.positive.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(
          color: colors.positive.withValues(alpha: 0.4),
          width: AppConstants.borderWidthList,
        ),
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(image.path),
              width: 64, height: 64,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: AppConstants.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FaIcon(FontAwesomeIcons.circleCheck,
                        size: 12, color: colors.positive),
                    const SizedBox(width: 6),
                    Text('Comprobante listo',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.positive,
                        )),
                  ],
                ),
                if (ocr?.success == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    'OCR: ${ocr!.amount != null ? CurrencyFormatter.format(ocr!.amount!) : "?"}'
                    '${ocr!.operationId != null ? ' · Op ${ocr!.operationId}' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Text('Imagen comprimida y lista para subir',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      )),
                ],
              ],
            ),
          ),
          // Remove button
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.xmark, size: 14),
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            onPressed: onRemove,
            tooltip: 'Eliminar comprobante',
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  const _ErrorBody({required this.message});

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
                size: 36, color: theme.colorScheme.error),
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
