import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/loans/presentation/screens/create_loan_screen.dart';
import '../../features/loans/presentation/screens/loan_detail_screen.dart';

class AppRoutes {
  AppRoutes._();
  static const String login          = '/login';
  static const String register       = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String home           = '/home';
  static const String createLoan     = '/create-loan';
  static const String loanDetail     = '/loan/:loanId';

  static String loanDetailPath(String loanId) => '/loan/$loanId';
}

/// Rutas públicas (accesibles sin autenticar)
const _publicRoutes = {
  AppRoutes.login,
  AppRoutes.register,
  AppRoutes.forgotPassword,
};

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AsyncValue>(authProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final auth          = _ref.read(authProvider);
    final loc           = state.matchedLocation;
    final isPublicRoute = _publicRoutes.any((r) => loc.startsWith(r));

    if (auth.isLoading) return null;

    final authenticated = auth.hasValue && auth.value != null;

    if (!authenticated && !isPublicRoute) return AppRoutes.login;
    if (authenticated && isPublicRoute)   return AppRoutes.home;
    return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      // ── Auth ─────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      // ── App ──────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.createLoan,
        name: 'create-loan',
        builder: (_, __) => const CreateLoanScreen(),
      ),
      GoRoute(
        path: AppRoutes.loanDetail,
        name: 'loan-detail',
        builder: (_, state) => LoanDetailScreen(
          loanId: state.pathParameters['loanId']!,
        ),
      ),
    ],
  );
});
