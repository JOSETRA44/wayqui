import 'package:intl/intl.dart';

/// Formateador de moneda para el mercado peruano (PEN — Soles).
class CurrencyFormatter {
  CurrencyFormatter._();

  static final _penFormat = NumberFormat.currency(
    locale: 'es_PE',
    symbol: 'S/.',
    decimalDigits: 2,
  );

  static final _compactFormat = NumberFormat.compactCurrency(
    locale: 'es_PE',
    symbol: 'S/.',
    decimalDigits: 1,
  );

  /// Formato completo: S/. 1,234.50
  static String format(double amount) => _penFormat.format(amount);

  /// Formato compacto para listas: S/. 1.2K
  static String compact(double amount) =>
      amount >= 1000 ? _compactFormat.format(amount) : format(amount);

  /// Signo + color: retorna "+" o "-" según el balance
  static String sign(double amount) => amount >= 0 ? '+' : '';
}
