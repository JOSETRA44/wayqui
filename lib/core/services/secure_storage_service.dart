import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Servicio de almacenamiento seguro (Keychain en iOS, Keystore en Android).
/// Usado para datos sensibles del usuario que persisten entre sesiones.
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _keyOnboarded = 'wayqui_onboarded';
  static const _keyBiometricEnabled = 'wayqui_biometric';

  // ── Onboarding ────────────────────────────────────────────────
  Future<void> setOnboarded() =>
      _storage.write(key: _keyOnboarded, value: 'true');

  Future<bool> isOnboarded() async {
    final val = await _storage.read(key: _keyOnboarded);
    return val == 'true';
  }

  // ── Biometría ─────────────────────────────────────────────────
  Future<void> setBiometricEnabled({required bool enabled}) =>
      _storage.write(key: _keyBiometricEnabled, value: enabled.toString());

  Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(key: _keyBiometricEnabled);
    return val == 'true';
  }

  // ── Limpieza total (logout) ───────────────────────────────────
  Future<void> clearAll() => _storage.deleteAll();
}
