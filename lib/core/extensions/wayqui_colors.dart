import 'package:flutter/material.dart';

/// ThemeExtension de colores semánticos de Wayqui.
/// Uso: `Theme.of(context).extension<WayquiColors>()!.positive`
@immutable
class WayquiColors extends ThemeExtension<WayquiColors> {
  final Color positive;    // Saldo a favor (te deben)
  final Color negative;    // Saldo en contra (debes)
  final Color pending;     // Transacción pendiente de confirmación
  final Color yape;        // Color brand Yape
  final Color plin;        // Color brand Plin
  final Color cardBorder;  // Borde Comic de tarjetas
  final Color cardSurface; // Fondo de tarjetas

  const WayquiColors({
    required this.positive,
    required this.negative,
    required this.pending,
    required this.yape,
    required this.plin,
    required this.cardBorder,
    required this.cardSurface,
  });

  static const light = WayquiColors(
    positive:    Color(0xFF1DB954), // Verde — dinero a tu favor
    negative:    Color(0xFFE53935), // Rojo — dinero que debes
    pending:     Color(0xFFF59E0B), // Ámbar — pendiente
    yape:        Color(0xFF7B2FF7), // Morado Yape
    plin:        Color(0xFF00B4D8), // Celeste Plin
    cardBorder:  Color(0xFF1A1A2E),
    cardSurface: Color(0xFFFFFDF7),
  );

  static const dark = WayquiColors(
    positive:    Color(0xFF22C55E),
    negative:    Color(0xFFEF4444),
    pending:     Color(0xFFFBBF24),
    yape:        Color(0xFF9B5DE5),
    plin:        Color(0xFF48CAE4),
    cardBorder:  Color(0xFFE2E8F0),
    cardSurface: Color(0xFF1E293B),
  );

  @override
  WayquiColors copyWith({
    Color? positive,
    Color? negative,
    Color? pending,
    Color? yape,
    Color? plin,
    Color? cardBorder,
    Color? cardSurface,
  }) {
    return WayquiColors(
      positive:    positive    ?? this.positive,
      negative:    negative    ?? this.negative,
      pending:     pending     ?? this.pending,
      yape:        yape        ?? this.yape,
      plin:        plin        ?? this.plin,
      cardBorder:  cardBorder  ?? this.cardBorder,
      cardSurface: cardSurface ?? this.cardSurface,
    );
  }

  @override
  WayquiColors lerp(WayquiColors? other, double t) {
    if (other is! WayquiColors) return this;
    return WayquiColors(
      positive:    Color.lerp(positive,    other.positive,    t)!,
      negative:    Color.lerp(negative,    other.negative,    t)!,
      pending:     Color.lerp(pending,     other.pending,     t)!,
      yape:        Color.lerp(yape,        other.yape,        t)!,
      plin:        Color.lerp(plin,        other.plin,        t)!,
      cardBorder:  Color.lerp(cardBorder,  other.cardBorder,  t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
    );
  }
}
