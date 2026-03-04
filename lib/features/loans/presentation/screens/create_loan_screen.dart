import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/wayqui_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/comic_button.dart';
import '../../../../shared/widgets/comic_text_field.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../domain/entities/user_search_result.dart';
import '../../domain/usecases/create_loan_usecase.dart';
import '../providers/loans_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class CreateLoanScreen extends ConsumerStatefulWidget {
  const CreateLoanScreen({super.key});

  @override
  ConsumerState<CreateLoanScreen> createState() => _CreateLoanScreenState();
}

class _CreateLoanScreenState extends ConsumerState<CreateLoanScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _phoneCtrl   = TextEditingController();
  final _nameCtrl    = TextEditingController();
  final _amountCtrl  = TextEditingController();
  final _descCtrl    = TextEditingController();

  DateTime? _dueDate;
  // true when user typed 9 digits but was not found → show name field
  bool _showExternalFields = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    // Clean up debounced search
    ref.read(phoneSearchProvider.notifier).clear();
    super.dispose();
  }

  void _onPhoneChanged(String value) {
    ref.read(phoneSearchProvider.notifier).search(value);
    if (_showExternalFields) setState(() => _showExternalFields = false);
    if (_nameCtrl.text.isNotEmpty) _nameCtrl.clear();
  }

  Future<void> _pickDueDate() async {
    HapticFeedback.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _submit(UserSearchResult? searchResult) async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.vibrate();
      return;
    }
    HapticFeedback.mediumImpact();

    final uid    = ref.read(authProvider).value!.id;
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;

    final isRegistered = searchResult?.found == true;
    final params = CreateLoanParams(
      creditorId:  uid,
      debtorId:    isRegistered ? searchResult!.id : null,
      debtorName:  isRegistered
          ? searchResult!.displayName
          : _nameCtrl.text.trim(),
      debtorPhone: isRegistered
          ? searchResult!.phoneNumber
          : _phoneCtrl.text.trim(),
      amount:      amount,
      description: _descCtrl.text.trim(),
      dueDate:     _dueDate,
    );

    await ref.read(loansProvider.notifier).createLoan(params);

    final loansState = ref.read(loansProvider);
    if (loansState.hasError) return; // error shown inline

    if (mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final theme      = Theme.of(context);
    final colors     = theme.extension<WayquiColors>()!;
    final searchState = ref.watch(phoneSearchProvider);
    final loansState  = ref.watch(loansProvider);
    final isLoading   = loansState.isLoading;

    // Sync external fields toggle with search result
    final searchResult = searchState.value;
    final phoneLen = _phoneCtrl.text.replaceAll(RegExp(r'\s'), '').length;
    final notFoundState = searchResult != null && !searchResult.found;
    final showExternal  = _showExternalFields || notFoundState;

    return Scaffold(
      appBar: AppBar(
        title: Text('Nuevo Préstamo', style: theme.textTheme.headlineSmall),
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.arrowLeft, size: 18),
          onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.home),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppConstants.spacing16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            // ── Sección destinatario ────────────────────────────────
            _SectionHeader(
              label: '¿A quién le prestas?',
              icon: FontAwesomeIcons.userGroup,
            ).animate().fadeIn(duration: 300.ms),

            const SizedBox(height: AppConstants.spacing12),

            ComicTextField(
              controller:      _phoneCtrl,
              label:           'Número de teléfono',
              hint:            '9XXXXXXXX',
              prefixIcon:      const FaIcon(FontAwesomeIcons.mobileScreen, size: 16),
              keyboardType:    TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              onChanged:    _onPhoneChanged,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.isEmpty)         return 'Ingresa el número';
                if (!RegExp(r'^9\d{8}$').hasMatch(v)) return 'Número inválido (9XXXXXXXX)';
                return null;
              },
            ).animate().fadeIn(delay: 50.ms),

            const SizedBox(height: AppConstants.spacing12),

            // ── Estado de búsqueda ──────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildSearchResult(
                context:   context,
                colors:    colors,
                state:     searchState,
                phoneLen:  phoneLen,
                onAddExternal: () => setState(() => _showExternalFields = true),
              ),
            ),

            // ── Campos para contacto externo ────────────────────────
            if (showExternal) ...[
              const SizedBox(height: AppConstants.spacing12),
              ComicTextField(
                controller:          _nameCtrl,
                label:               'Nombre del contacto',
                hint:                'Ej: Carlos López',
                prefixIcon:          const FaIcon(FontAwesomeIcons.userPen, size: 16),
                textCapitalization:  TextCapitalization.words,
                textInputAction:     TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Ingresa el nombre';
                  if (v.trim().length < 2)           return 'Nombre muy corto';
                  return null;
                },
              ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.1, end: 0),
              const SizedBox(height: AppConstants.spacing8),
              _ExternalContactNote(),
            ],

            const SizedBox(height: AppConstants.spacing24),

            // ── Sección detalles del préstamo ───────────────────────
            _SectionHeader(
              label:  'Detalles del préstamo',
              icon:   FontAwesomeIcons.sackDollar,
            ).animate().fadeIn(delay: 100.ms),

            const SizedBox(height: AppConstants.spacing12),

            // Monto
            ComicTextField(
              controller:      _amountCtrl,
              label:           'Monto (PEN)',
              hint:            '0.00',
              prefixIcon:      Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'S/.',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              keyboardType:    const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d{0,8}\.?\d{0,2}')),
              ],
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.isEmpty)            return 'Ingresa el monto';
                final n = double.tryParse(v.replaceAll(',', '.'));
                if (n == null || n <= 0)               return 'Monto inválido';
                if (n > 99999.99)                      return 'Máximo S/. 99,999.99';
                return null;
              },
            ).animate().fadeIn(delay: 150.ms),

            const SizedBox(height: AppConstants.spacing12),

            // Descripción
            ComicTextField(
              controller:         _descCtrl,
              label:              'Descripción',
              hint:               'Ej: Para el almuerzo del viernes',
              prefixIcon:         const FaIcon(FontAwesomeIcons.alignLeft, size: 16),
              maxLines:           2,
              maxLength:          200,
              textCapitalization: TextCapitalization.sentences,
              textInputAction:    TextInputAction.done,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingresa una descripción';
                if (v.trim().length < 4)           return 'Descripción muy corta';
                return null;
              },
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: AppConstants.spacing12),

            // Fecha de vencimiento (opcional)
            _DueDatePicker(
              dueDate:  _dueDate,
              colors:   colors,
              onPick:   _pickDueDate,
              onClear:  () => setState(() => _dueDate = null),
            ).animate().fadeIn(delay: 250.ms),

            const SizedBox(height: AppConstants.spacing32),

            // ── CTA ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ComicButton(
                label:     isLoading ? 'Registrando...' : 'Registrar Préstamo',
                isLoading: isLoading,
                icon:      const FaIcon(FontAwesomeIcons.handHoldingDollar,
                    size: 16),
                onPressed: isLoading
                    ? null
                    : () => _submit(searchResult),
                animateDelay: 300,
              ),
            ),

            // Error inline
            if (loansState.hasError) ...[
              const SizedBox(height: AppConstants.spacing12),
              _ErrorBanner(message: _parseError(loansState.error!)),
            ],

            const SizedBox(height: AppConstants.spacing32),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResult({
    required BuildContext context,
    required WayquiColors colors,
    required AsyncValue<UserSearchResult?> state,
    required int phoneLen,
    required VoidCallback onAddExternal,
  }) {
    return state.when(
      loading: () => const _SearchingIndicator(),
      error:   (e, _) => _SearchError(message: e.toString()),
      data: (result) {
        if (result == null || phoneLen < 9) return const SizedBox.shrink(key: ValueKey('empty'));
        if (result.found) {
          return _UserFoundCard(
            key: ValueKey(result.id),
            user: result,
            colors: colors,
          );
        }
        return _UserNotFoundBanner(
          key: const ValueKey('not-found'),
          onAddExternal: onAddExternal,
          colors: colors,
        );
      },
    );
  }

  String _parseError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('duplicate') || s.contains('unique')) {
      return 'Ya existe un préstamo con los mismos datos.';
    }
    if (s.contains('network') || s.contains('socket')) {
      return 'Sin conexión. Verifica tu internet.';
    }
    return 'No se pudo crear el préstamo. Intenta de nuevo.';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

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
          color: theme.colorScheme.primary,
          letterSpacing: 0.4,
        )),
        const SizedBox(width: AppConstants.spacing8),
        Expanded(child: Divider(color: theme.colorScheme.outline)),
      ],
    );
  }
}

class _SearchingIndicator extends StatelessWidget {
  const _SearchingIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('searching'),
      padding: const EdgeInsets.all(AppConstants.spacing12),
      decoration: BoxDecoration(
        color:        theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border:       Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppConstants.spacing12),
          Text('Buscando usuario...', style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SearchError extends StatelessWidget {
  final String message;
  const _SearchError({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('search-error'),
      padding: const EdgeInsets.all(AppConstants.spacing12),
      decoration: BoxDecoration(
        color:        theme.colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border:       Border.all(color: theme.colorScheme.error),
      ),
      child: Row(
        children: [
          FaIcon(FontAwesomeIcons.circleExclamation,
              size: 14, color: theme.colorScheme.error),
          const SizedBox(width: AppConstants.spacing8),
          Expanded(
            child: Text('Error al buscar: $message',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                )),
          ),
        ],
      ),
    );
  }
}

class _UserFoundCard extends StatelessWidget {
  final UserSearchResult user;
  final WayquiColors     colors;
  const _UserFoundCard({super.key, required this.user, required this.colors});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacing12),
      decoration: BoxDecoration(
        color:        colors.positive.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border:       Border.all(color: colors.positive, width: AppConstants.borderWidth),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: colors.positive.withValues(alpha: 0.2),
            child: Text(
              user.initials,
              style: theme.textTheme.labelLarge?.copyWith(color: colors.positive),
            ),
          ),
          const SizedBox(width: AppConstants.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName,
                    style: theme.textTheme.titleSmall),
                if (user.phoneNumber != null)
                  Text(user.phoneNumber!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      )),
              ],
            ),
          ),
          FaIcon(FontAwesomeIcons.circleCheck, size: 18, color: colors.positive),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.1, end: 0);
  }
}

class _UserNotFoundBanner extends StatelessWidget {
  final VoidCallback onAddExternal;
  final WayquiColors colors;
  const _UserNotFoundBanner({
    super.key,
    required this.onAddExternal,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacing12),
      decoration: BoxDecoration(
        color:        colors.pending.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border:       Border.all(color: colors.pending, width: AppConstants.borderWidth),
      ),
      child: Row(
        children: [
          FaIcon(FontAwesomeIcons.userSlash, size: 16, color: colors.pending),
          const SizedBox(width: AppConstants.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No encontrado en Wayqui',
                    style: theme.textTheme.labelLarge?.copyWith(color: colors.pending)),
                const SizedBox(height: 2),
                Text('Puedes registrarlo como contacto externo.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    )),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              onAddExternal();
            },
            child: Text('Agregar', style: theme.textTheme.labelMedium?.copyWith(
              color: colors.pending,
            )),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}

class _ExternalContactNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        FaIcon(FontAwesomeIcons.circleInfo,
            size: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.45)),
        const SizedBox(width: AppConstants.spacing8),
        Text(
          'Contacto externo: no recibirá notificaciones.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }
}

class _DueDatePicker extends StatelessWidget {
  final DateTime?    dueDate;
  final WayquiColors colors;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _DueDatePicker({
    required this.dueDate,
    required this.colors,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt   = DateFormat('dd MMM yyyy', 'es');
    final hasDate = dueDate != null;

    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacing16,
          vertical:   AppConstants.spacing12,
        ),
        decoration: BoxDecoration(
          color:        theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border:       Border.all(
            color: hasDate ? colors.pending : theme.colorScheme.outline,
            width: AppConstants.borderWidth,
          ),
        ),
        child: Row(
          children: [
            FaIcon(
              FontAwesomeIcons.calendarDays,
              size: 16,
              color: hasDate ? colors.pending : theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
            const SizedBox(width: AppConstants.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fecha de vencimiento (opcional)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  if (hasDate)
                    Text(fmt.format(dueDate!), style: theme.textTheme.bodyMedium),
                  if (!hasDate)
                    Text('Sin fecha límite', style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    )),
                ],
              ),
            ),
            if (hasDate)
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onClear();
                },
                child: FaIcon(FontAwesomeIcons.xmark, size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacing12),
      decoration: BoxDecoration(
        color:        theme.colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border:       Border.all(color: theme.colorScheme.error),
      ),
      child: Row(
        children: [
          FaIcon(FontAwesomeIcons.triangleExclamation,
              size: 14, color: theme.colorScheme.error),
          const SizedBox(width: AppConstants.spacing8),
          Expanded(
            child: Text(message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                )),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).shake();
  }
}
