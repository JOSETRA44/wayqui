import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';

class AppRoutes {
  AppRoutes._();
  static const String login = '/login';
  static const String home = '/home';
}

class AppRouter {
  AppRouter._();

  static GoRouter create(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: AppRoutes.login,
      refreshListenable: authProvider,
      redirect: (context, state) {
        final authenticated = authProvider.isAuthenticated;
        final onLogin = state.matchedLocation == AppRoutes.login;

        if (!authenticated && !onLogin) return AppRoutes.login;
        if (authenticated && onLogin) return AppRoutes.home;
        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.login,
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: AppRoutes.home,
          name: 'home',
          builder: (context, state) => const HomeScreen(),
        ),
      ],
    );
  }
}
