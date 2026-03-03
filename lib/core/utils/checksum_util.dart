import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Utilidad de checksums SHA-256 para integridad de transacciones.
/// Previene manipulación de datos entre pantallas en el cliente.
///
/// El checksum generado aquí se almacena en la DB y se re-verifica
/// al leer el préstamo/transacción para detectar alteraciones.
class ChecksumUtil {
  ChecksumUtil._();

  /// Genera checksum para un préstamo.
  /// Payload: creditorId:debtorId:amount:description:createdAt
  static String forLoan({
    required String creditorId,
    required String debtorId,
    required String amount,
    required String description,
    required String createdAt,
  }) {
    final payload =
        '$creditorId:$debtorId:$amount:${description.trim()}:$createdAt';
    return _sha256(payload);
  }

  /// Genera checksum para una transacción de pago.
  /// Payload: loanId:payerId:amount:paymentMethod:createdAt
  static String forTransaction({
    required String loanId,
    required String payerId,
    required String amount,
    required String paymentMethod,
    required String createdAt,
  }) {
    final payload = '$loanId:$payerId:$amount:$paymentMethod:$createdAt';
    return _sha256(payload);
  }

  /// Verifica la integridad de un checksum.
  static bool verify(String computed, String stored) =>
      computed == stored;

  static String _sha256(String input) =>
      sha256.convert(utf8.encode(input)).toString();
}
