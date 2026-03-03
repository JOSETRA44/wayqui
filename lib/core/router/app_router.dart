import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';

class AppRoutes {
  AppRoutes._();
  static const String login = '/login';
  static const String home  = '/home';
}

/// RouterNotifier escucha authProvider y notifica a GoRouter para
/// re-ejecutar el redirect cuando cambia el estado de autenticación.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    // Cada vez que authProvider cambie, GoRouter re-evalúa el redirect
    _ref.listen<AsyncValue>(authProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final auth = _ref.read(authProvider);
    final onLogin = state.matchedLocation == AppRoutes.login;

    // En carga inicial no redirigir
    if (auth.isLoading) return null;

    final authenticated = auth.hasValue && auth.value != null;

    if (!authenticated && !onLogin) return AppRoutes.login;
    if (authenticated && onLogin)   return AppRoutes.home;
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
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (_, __) => const HomeScreen(),
      ),
    ],
  );
});
