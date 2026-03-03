import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Orientación solo vertical (financiero — evita layouts rotos)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Cargar variables de entorno
  await dotenv.load(fileName: '.env');

  // Inicializar Supabase con ANON KEY (nunca SERVICE_ROLE en cliente)
  await Supabase.initialize(
    url:     dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    // Modo debug: logs en consola. Desactivar en producción.
    debug: false,
  );

  // ProviderScope: raíz del árbol de Riverpod
  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
