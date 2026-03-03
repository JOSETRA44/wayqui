import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Puente de pagos — copia número al portapapeles y lanza Yape o Plin.
///
/// Yape:  Deep link personalizado por número de teléfono.
/// Plin:  Abre la app; el usuario completa el pago manualmente.
class PaymentBridgeService {
  PaymentBridgeService._();

  // Package IDs Android
  static const _yapePackageAndroid = 'com.bcp.innovatcx.yapeapp';
  static const _plinPackageAndroid = 'com.yovoy.plin';

  // ── Yape ─────────────────────────────────────────────────────
  static Future<LaunchResult> openYape({
    required String phoneNumber,
    required double amount,
    String? description,
  }) async {
    // 1. Copiar número al portapapeles para facilitar al usuario
    await Clipboard.setData(ClipboardData(text: phoneNumber));
    HapticFeedback.lightImpact();

    // 2. Intentar deep link directo de Yape
    final yapeUri = Uri.parse(
      'yape://transfer?phone=$phoneNumber'
      '&amount=${amount.toStringAsFixed(2)}'
      '${description != null ? '&concept=${Uri.encodeComponent(description)}' : ''}',
    );

    if (await canLaunchUrl(yapeUri)) {
      await launchUrl(yapeUri, mode: LaunchMode.externalApplication);
      return LaunchResult.success;
    }

    // 3. Fallback: intentar abrir Play Store con la app de Yape
    final storeUri = Uri.parse(
        'https://play.google.com/store/apps/details?id=$_yapePackageAndroid');
    if (await canLaunchUrl(storeUri)) {
      await launchUrl(storeUri, mode: LaunchMode.externalApplication);
      return LaunchResult.openedStore;
    }

    return LaunchResult.notInstalled;
  }

  // ── Plin ─────────────────────────────────────────────────────
  static Future<LaunchResult> openPlin({
    required String phoneNumber,
    required double amount,
  }) async {
    await Clipboard.setData(ClipboardData(text: phoneNumber));
    HapticFeedback.lightImpact();

    // Plin no expone deep links públicos documentados; abrimos la app directamente
    final plinUri = Uri.parse('plin://');

    if (await canLaunchUrl(plinUri)) {
      await launchUrl(plinUri, mode: LaunchMode.externalApplication);
      return LaunchResult.success;
    }

    final storeUri = Uri.parse(
        'https://play.google.com/store/apps/details?id=$_plinPackageAndroid');
    if (await canLaunchUrl(storeUri)) {
      await launchUrl(storeUri, mode: LaunchMode.externalApplication);
      return LaunchResult.openedStore;
    }

    return LaunchResult.notInstalled;
  }

  /// Copia el número al portapapeles sin abrir ninguna app
  static Future<void> copyPhone(String phoneNumber) async {
    await Clipboard.setData(ClipboardData(text: phoneNumber));
    HapticFeedback.selectionClick();
  }
}

enum LaunchResult {
  success,      // App abierta correctamente
  openedStore,  // App no instalada → redirigido a Play Store / App Store
  notInstalled, // No se pudo abrir ninguna URL
}
