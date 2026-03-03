import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/usecases/sign_in_usecase.dart';
import 'features/auth/domain/usecases/sign_out_usecase.dart';
import 'features/auth/presentation/providers/auth_provider.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    // Dependency wiring manual (sin getIt para mantenerlo simple y explícito)
    final dataSource =
        AuthRemoteDataSourceImpl(Supabase.instance.client);
    final repository = AuthRepositoryImpl(dataSource);

    final authProvider = AuthProvider(
      signInUseCase: SignInUseCase(repository),
      signOutUseCase: SignOutUseCase(repository),
      initialUser: repository.currentUser,
    );

    return ChangeNotifierProvider.value(
      value: authProvider,
      child: Builder(
        builder: (context) {
          final router = AppRouter.create(authProvider);
          return MaterialApp.router(
            title: 'Wayqui',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
