import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/activity/presentation/screens/activity_screen.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/otp_verify_screen.dart';
import '../../features/contacts/presentation/screens/contacts_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/loans/presentation/screens/create_loan_screen.dart';
import '../../features/loans/presentation/screens/loan_detail_screen.dart';
import '../../features/navigation/presentation/main_shell.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Routes
// ─────────────────────────────────────────────────────────────────────────────

class AppRoutes {
  AppRoutes._();

  // ── Public ─────────────────────────────────────────────────────
  static const String login          = '/login';
  static const String register       = '/register';  // onboarding
  static const String forgotPassword = '/forgot-password';
  static const String otpVerify      = '/otp';

  // ── Shell (bottom nav) ─────────────────────────────────────────
  static const String home     = '/home';
  static const String activity = '/activity';
  static const String contacts = '/contacts';
  static const String profile  = '/profile';

  // ── Modal (pushed over shell) ──────────────────────────────────
  static const String createLoan = '/create-loan';
  static const String loanDetail = '/loan/:loanId';

  static String loanDetailPath(String loanId) => '/loan/$loanId';
}

/// Rutas accesibles sin autenticar.
const _publicRoutes = {
  AppRoutes.login,
  AppRoutes.register,
  AppRoutes.forgotPassword,
  AppRoutes.otpVerify,
};

// ─────────────────────────────────────────────────────────────────────────────
// Router notifier
// ─────────────────────────────────────────────────────────────────────────────

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    // Escuchar solo cambios de valor/error; ignorar el estado de carga
    // para no disparar redirects intermedios durante signOut.
    _ref.listen<AsyncValue<dynamic>>(authProvider, (previous, next) {
      if (next.isLoading) return;
      notifyListeners();
    });
  }
  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final auth = _ref.read(authProvider);

    // Durante cualquier operación asíncrona (signIn, signOut) no redirigir
    // para evitar navegaciones mientras el stack está en transición.
    if (auth.isLoading) return null;

    final loc      = state.matchedLocation;
    final isPublic = _publicRoutes.any((r) => loc.startsWith(r));

    final authenticated = auth.hasValue && auth.value != null;

    if (!authenticated && !isPublic) return AppRoutes.login;
    if (authenticated  && isPublic)  return AppRoutes.home;
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Router provider
// ─────────────────────────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation:   AppRoutes.login,
    refreshListenable: notifier,
    redirect:          notifier.redirect,
    routes: [

      // ── Auth (public, no shell) ─────────────────────────────────
      GoRoute(
        path:    AppRoutes.login,
        name:    'login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path:    AppRoutes.register,
        name:    'register',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path:    AppRoutes.forgotPassword,
        name:    'forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path:    AppRoutes.otpVerify,
        name:    'otp-verify',
        builder: (_, state) => OtpVerifyScreen(
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),

      // ── Shell (bottom nav with 4 branches) ──────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path:    AppRoutes.home,
              name:    'home',
              builder: (_, __) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path:    AppRoutes.activity,
              name:    'activity',
              builder: (_, __) => const ActivityScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path:    AppRoutes.contacts,
              name:    'contacts',
              builder: (_, __) => const ContactsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path:    AppRoutes.profile,
              name:    'profile',
              builder: (_, __) => const ProfileScreen(),
            ),
          ]),
        ],
      ),

      // ── Modal routes (pushed over shell) ────────────────────────
      GoRoute(
        path:    AppRoutes.createLoan,
        name:    'create-loan',
        builder: (_, __) => const CreateLoanScreen(),
      ),
      GoRoute(
        path:    AppRoutes.loanDetail,
        name:    'loan-detail',
        builder: (_, state) => LoanDetailScreen(
          loanId: state.pathParameters['loanId']!,
        ),
      ),
    ],
  );
});
