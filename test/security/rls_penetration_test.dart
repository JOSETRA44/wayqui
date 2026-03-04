// RLS Penetration Test — Wayqui
//
// Verifica que las políticas de Row Level Security en Supabase impidan que:
//   1. Un usuario B lea los préstamos de usuario A.
//   2. Un usuario B inserte transacciones en préstamos ajenos.
//   3. Un usuario B lea transacciones de préstamos ajenos.
//
// CÓMO EJECUTAR:
//   dart test test/security/rls_penetration_test.dart --reporter expanded
//
// Requiere las variables de entorno en `.env`:
//   SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY

import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

// ─── Helper mínimo para llamadas directas a la API REST de Supabase ──────────

class _SupaRest {
  final String url;
  final String key;
  final String? jwt; // JWT del usuario autenticado (nulo → service role)

  const _SupaRest({required this.url, required this.key, this.jwt});

  Map<String, String> get _headers => {
        'apikey':       key,
        'Authorization': 'Bearer ${jwt ?? key}',
        'Content-Type': 'application/json',
        'Prefer':       'return=representation',
      };

  Future<http.Response> get(String path) =>
      http.get(Uri.parse('$url$path'), headers: _headers);

  Future<http.Response> post(String path, Map<String, dynamic> body) =>
      http.post(Uri.parse('$url$path'),
          headers: _headers, body: jsonEncode(body));

  Future<http.Response> delete(String path) =>
      http.delete(Uri.parse('$url$path'), headers: _headers);
}

// ─── Utilidades de autenticación ─────────────────────────────────────────────

Future<String> _signUp(_SupaRest admin, String email, String password) async {
  // Crear usuario vía admin API (sin confirmación de email)
  final res = await admin.post('/auth/v1/admin/users', {
    'email':            email,
    'password':         password,
    'email_confirm':    true,
    'user_metadata':    {'full_name': 'Test User'},
  });
  expect(res.statusCode, 201,
      reason: 'signUp admin falló (${res.statusCode}): ${res.body}');
  return (jsonDecode(res.body) as Map)['id'] as String;
}

Future<String> _signIn(_SupaRest anon, String email, String password) async {
  final res = await anon.post(
    '/auth/v1/token?grant_type=password',
    {'email': email, 'password': password},
  );
  expect(res.statusCode, 200,
      reason: 'signIn falló (${res.statusCode}): ${res.body}');
  return (jsonDecode(res.body) as Map)['access_token'] as String;
}

Future<void> _deleteUser(_SupaRest admin, String userId) async {
  final res = await admin.delete('/auth/v1/admin/users/$userId');
  // 204 No Content o 200 son éxito
  expect(res.statusCode, lessThan(300),
      reason: 'deleteUser falló (${res.statusCode}): ${res.body}');
}

// ─── Test suite ───────────────────────────────────────────────────────────────

void main() {
  late String supabaseUrl;
  late String anonKey;
  late String serviceKey;

  // IDs de usuarios de prueba — se limpian en tearDownAll
  String? userAId;
  String? userBId;
  String? loanId;

  setUpAll(() async {
    await dotenv.load(fileName: '.env');
    supabaseUrl = dotenv.env['SUPABASE_URL']!;
    anonKey     = dotenv.env['SUPABASE_ANON_KEY']!;
    serviceKey  = dotenv.env['SUPABASE_SERVICE_ROLE_KEY']!;
  });

  tearDownAll(() async {
    final admin = _SupaRest(url: supabaseUrl, key: serviceKey);
    // Limpiar préstamos de prueba (cascading delete borra transacciones)
    if (loanId != null) {
      await admin.delete('/rest/v1/loans?id=eq.$loanId');
    }
    // Eliminar usuarios de prueba
    if (userAId != null) await _deleteUser(admin, userAId!);
    if (userBId != null) await _deleteUser(admin, userBId!);
  });

  group('Configuración', () {
    test('Crear usuarios de prueba A y B', () async {
      final admin = _SupaRest(url: supabaseUrl, key: serviceKey);
      final ts    = DateTime.now().millisecondsSinceEpoch;

      userAId = await _signUp(admin, 'testA_$ts@wayqui.test', 'SecurePass123!');
      userBId = await _signUp(admin, 'testB_$ts@wayqui.test', 'SecurePass123!');

      expect(userAId, isNotEmpty);
      expect(userBId, isNotEmpty);
      expect(userAId, isNot(equals(userBId)));
    });
  });

  group('RLS: Tabla loans', () {
    test('Usuario A puede crear su propio préstamo', () async {
      final ts        = DateTime.now().millisecondsSinceEpoch;
      final jwtA      = await _signIn(
        _SupaRest(url: supabaseUrl, key: anonKey),
        'testA_$ts@wayqui.test',
        'SecurePass123!',
      );
      final clientA = _SupaRest(url: supabaseUrl, key: anonKey, jwt: jwtA);

      final res = await clientA.post('/rest/v1/loans', {
        'creditor_id': userAId,
        'debtor_name': 'Deudor Externo',
        'amount':      100.0,
        'remaining_amount': 100.0,
        'description': 'Préstamo de prueba RLS',
        'currency':    'PEN',
        'checksum':    'test-checksum-${DateTime.now().millisecondsSinceEpoch}',
      });

      expect(res.statusCode, anyOf(201, 200),
          reason: 'Usuario A no pudo crear préstamo: ${res.body}');

      final body = jsonDecode(res.body);
      loanId = body is List ? body.first['id'] : body['id'];
      expect(loanId, isNotNull);
    });

    test('Usuario B NO puede leer préstamos de usuario A', () async {
      expect(loanId, isNotNull, reason: 'loanId debe existir del test anterior');
      final ts   = DateTime.now().millisecondsSinceEpoch;
      final jwtB = await _signIn(
        _SupaRest(url: supabaseUrl, key: anonKey),
        'testB_$ts@wayqui.test',
        'SecurePass123!',
      );
      final clientB = _SupaRest(url: supabaseUrl, key: anonKey, jwt: jwtB);

      final res = await clientB.get('/rest/v1/loans?id=eq.$loanId&select=*');

      // RLS debe devolver lista vacía (200) — no un error, sino sin datos
      expect(res.statusCode, 200);
      final list = jsonDecode(res.body) as List;
      expect(list, isEmpty,
          reason: 'RLS FALLO: Usuario B pudo leer ${list.length} préstamo(s) de A');
    });

    test('Usuario B NO puede modificar el préstamo de usuario A', () async {
      expect(loanId, isNotNull);
      final ts   = DateTime.now().millisecondsSinceEpoch;
      final jwtB = await _signIn(
        _SupaRest(url: supabaseUrl, key: anonKey),
        'testB_$ts@wayqui.test',
        'SecurePass123!',
      );
      final res = await http.patch(
        Uri.parse('$supabaseUrl/rest/v1/loans?id=eq.$loanId'),
        headers: {
          'apikey':        anonKey,
          'Authorization': 'Bearer $jwtB',
          'Content-Type':  'application/json',
          'Prefer':        'return=representation',
        },
        body: jsonEncode({'description': 'HACKED BY USER B'}),
      );

      // Supabase devuelve 200 con lista vacía (0 filas afectadas) o 403
      final updated = res.statusCode == 200
          ? (jsonDecode(res.body) as List)
          : <dynamic>[];
      expect(updated, isEmpty,
          reason: 'RLS FALLO: Usuario B modificó el préstamo de A');
    });
  });

  group('RLS: Tabla loan_transactions', () {
    test('Usuario B NO puede insertar transacción en préstamo de A', () async {
      expect(loanId, isNotNull);
      final ts   = DateTime.now().millisecondsSinceEpoch;
      final jwtB = await _signIn(
        _SupaRest(url: supabaseUrl, key: anonKey),
        'testB_$ts@wayqui.test',
        'SecurePass123!',
      );
      final clientB = _SupaRest(url: supabaseUrl, key: anonKey, jwt: jwtB);

      final res = await clientB.post('/rest/v1/loan_transactions', {
        'loan_id':        loanId,
        'payer_id':       userBId,
        'amount':         10.0,
        'payment_method': 'cash',
        'checksum':       'fake-checksum-$ts',
      });

      // Debe ser 403 Forbidden o 401 Unauthorized
      expect(res.statusCode, greaterThanOrEqualTo(400),
          reason: 'RLS FALLO: Usuario B insertó transacción en préstamo de A '
              '(status=${res.statusCode})');
    });

    test('Usuario B NO puede leer transacciones del préstamo de A', () async {
      expect(loanId, isNotNull);
      final ts   = DateTime.now().millisecondsSinceEpoch;
      final jwtB = await _signIn(
        _SupaRest(url: supabaseUrl, key: anonKey),
        'testB_$ts@wayqui.test',
        'SecurePass123!',
      );
      final clientB = _SupaRest(url: supabaseUrl, key: anonKey, jwt: jwtB);

      final res = await clientB.get(
          '/rest/v1/loan_transactions?loan_id=eq.$loanId&select=*');

      expect(res.statusCode, 200);
      final list = jsonDecode(res.body) as List;
      expect(list, isEmpty,
          reason: 'RLS FALLO: Usuario B leyó ${list.length} transacción(es) del préstamo de A');
    });
  });

  group('RLS: Acceso del propio usuario', () {
    test('Usuario A puede leer su propio préstamo', () async {
      expect(loanId, isNotNull);
      final ts   = DateTime.now().millisecondsSinceEpoch;
      final jwtA = await _signIn(
        _SupaRest(url: supabaseUrl, key: anonKey),
        'testA_$ts@wayqui.test',
        'SecurePass123!',
      );
      final clientA = _SupaRest(url: supabaseUrl, key: anonKey, jwt: jwtA);

      final res = await clientA.get('/rest/v1/loans?id=eq.$loanId&select=*');

      expect(res.statusCode, 200);
      final list = jsonDecode(res.body) as List;
      expect(list, hasLength(1),
          reason: 'Usuario A no puede leer su propio préstamo');
      expect(list.first['id'], equals(loanId));
    });
  });
}
