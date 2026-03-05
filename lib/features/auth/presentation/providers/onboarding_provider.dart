import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class OnboardingData {
  final String name;
  final String email;
  final String phone;
  final String password;

  const OnboardingData({
    this.name     = '',
    this.email    = '',
    this.phone    = '',
    this.password = '',
  });

  OnboardingData copyWith({
    String? name,
    String? email,
    String? phone,
    String? password,
  }) =>
      OnboardingData(
        name:     name     ?? this.name,
        email:    email    ?? this.email,
        phone:    phone    ?? this.phone,
        password: password ?? this.password,
      );
}

class OnboardingNotifier extends StateNotifier<OnboardingData> {
  OnboardingNotifier() : super(const OnboardingData());

  void setName(String v)     => state = state.copyWith(name: v.trim());
  void setEmail(String v)    => state = state.copyWith(email: v.trim());
  void setPhone(String v)    => state = state.copyWith(phone: v.trim());
  void setPassword(String v) => state = state.copyWith(password: v);
  void reset()               => state = const OnboardingData();
}

/// Datos del onboarding — autoDispose al salir del flujo de registro.
final onboardingProvider =
    StateNotifierProvider.autoDispose<OnboardingNotifier, OnboardingData>(
  (ref) => OnboardingNotifier(),
);
