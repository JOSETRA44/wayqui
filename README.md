# Wayqui

> Gestión de préstamos personales para el mercado peruano.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.9-0175C2?logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-2.8-3ECF8E?logo=supabase&logoColor=white)
![Riverpod](https://img.shields.io/badge/Riverpod-2.6-blue)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey?logo=android)
![License](https://img.shields.io/badge/License-Private-red)

---

## Tabla de contenidos

- [Descripcion](#descripcion)
- [Arquitectura](#arquitectura)
- [Estructura de directorios](#estructura-de-directorios)
- [Stack tecnologico](#stack-tecnologico)
- [Esquema de base de datos](#esquema-de-base-de-datos)
- [Sistema de diseno](#sistema-de-diseno)
- [Pantallas implementadas](#pantallas-implementadas)
- [Seguridad](#seguridad)
- [Configuracion del entorno](#configuracion-del-entorno)
- [Instalacion y ejecucion](#instalacion-y-ejecucion)
- [Tests](#tests)
- [Roadmap](#roadmap)

---

## Descripcion

**Wayqui** ("hermano" en quechua) es una aplicacion movil de gestion de prestamos personales orientada al mercado peruano. Permite registrar deudas entre personas, hacer seguimiento del estado de cada prestamo y facilitar los pagos a traves de los billeteras digitales **Yape** y **Plin**, sin intermediar el dinero.

### Caracteristicas principales

| Capacidad | Detalle |
|-----------|---------|
| Registro de prestamos | Creditor crea el prestamo con monto, descripcion y fecha de vencimiento |
| Busqueda de contactos | Busqueda por numero de telefono con debounce de 500 ms |
| Pagos integrados | Deep links a Yape y Plin con copia automatica al portapapeles |
| Integridad de datos | Checksum SHA-256 por prestamo, verificado en servidor |
| Autenticacion segura | Supabase Auth con confirmacion por OTP de 6 digitos |
| Soporte dark mode | `ThemeMode.system` automatico |

---

## Arquitectura

La aplicacion sigue **Clean Architecture** con organizacion **Feature-First**. Cada feature es autonomo y se comunica con el resto unicamente a traves de providers de Riverpod.

```
Presentation  ─────────────────────────────
  Screens / Widgets
  Providers (AsyncNotifierProvider)
        |
Domain  ────────────────────────────────────
  Entities
  Use Cases
  Repository interfaces
        |
Data    ────────────────────────────────────
  Repository implementations
  Remote Data Sources (Supabase)
```

### Flujo de datos

```
Widget
  └─ ref.watch(provider)
       └─ AsyncNotifier.build()
            └─ UseCase.call()
                 └─ Repository.method()
                      └─ SupabaseClient (REST / RPC)
```

### Router

`GoRouter` con `StatefulShellRoute.indexedStack` para las cuatro ramas del shell de navegacion inferior. La autenticacion se gestiona mediante un `_RouterNotifier` que escucha `authProvider` e ignora estados de carga intermedios para evitar redirects durante operaciones asincronas.

---

## Estructura de directorios

```
wayqui/
├── lib/
│   ├── main.dart                          # Inicializacion: Supabase, dotenv, orientacion
│   ├── app.dart                           # ConsumerWidget + routerProvider
│   │
│   ├── core/
│   │   ├── constants/
│   │   │   └── app_constants.dart         # Espaciados, radios, elevacion
│   │   ├── extensions/
│   │   │   └── wayqui_colors.dart         # ThemeExtension con colores semanticos
│   │   ├── providers/
│   │   │   └── supabase_providers.dart    # SupabaseClient provider
│   │   ├── router/
│   │   │   └── app_router.dart            # GoRouter + RouterNotifier + rutas
│   │   ├── services/
│   │   │   ├── secure_storage_service.dart
│   │   │   └── payment_bridge_service.dart  # Deep links Yape / Plin
│   │   ├── theme/
│   │   │   └── app_theme.dart             # Light / Dark + ThemeExtension
│   │   └── utils/
│   │       ├── checksum_util.dart         # SHA-256 para integridad de prestamos
│   │       └── currency_formatter.dart    # Formato PEN (S/. 1,234.50)
│   │
│   ├── features/
│   │   ├── auth/
│   │   │   ├── domain/
│   │   │   │   ├── entities/              # UserEntity, SignUpResult
│   │   │   │   ├── repositories/          # AuthRepository (interfaz)
│   │   │   │   └── usecases/              # SignIn, SignUp, SignOut, ResetPassword
│   │   │   ├── data/
│   │   │   │   ├── datasources/           # AuthRemoteDataSourceImpl
│   │   │   │   └── repositories/          # AuthRepositoryImpl
│   │   │   └── presentation/
│   │   │       ├── providers/             # AuthNotifier, OnboardingProvider
│   │   │       └── screens/               # Login, Onboarding, OtpVerify, ForgotPassword
│   │   │
│   │   ├── loans/
│   │   │   ├── domain/
│   │   │   │   ├── entities/              # LoanEntity, LoanTransactionEntity, UserSearchResult
│   │   │   │   ├── repositories/          # LoansRepository (interfaz)
│   │   │   │   └── usecases/              # CreateLoan, GetLoans
│   │   │   ├── data/
│   │   │   │   ├── datasources/           # LoansRemoteDataSourceImpl
│   │   │   │   └── repositories/          # LoansRepositoryImpl
│   │   │   └── presentation/
│   │   │       ├── providers/             # LoansNotifier, UserSummaryProvider
│   │   │       └── screens/               # CreateLoan, LoanDetail
│   │   │
│   │   ├── home/presentation/screens/     # HomeScreen
│   │   ├── activity/presentation/screens/ # ActivityScreen
│   │   ├── contacts/presentation/screens/ # ContactsScreen
│   │   ├── profile/presentation/screens/  # ProfileScreen
│   │   └── navigation/presentation/       # MainShell (BottomNav)
│   │
│   └── shared/
│       └── widgets/
│           ├── comic_button.dart
│           ├── comic_text_field.dart
│           └── password_strength_indicator.dart
│
├── test/
│   └── security/
│       └── rls_penetration_test.dart      # Tests de RLS contra Supabase real
│
├── android/app/src/main/AndroidManifest.xml
├── pubspec.yaml
└── .env                                   # Variables de entorno (gitignored)
```

---

## Stack tecnologico

### Core

| Paquete | Version | Rol |
|---------|---------|-----|
| `flutter` | 3.x | Framework UI multiplataforma |
| `supabase_flutter` | 2.8.0 | Backend as a Service (Auth, DB, Storage) |
| `flutter_riverpod` | 2.6.1 | Gestion de estado reactiva |
| `go_router` | 14.6.3 | Routing declarativo con deep links |
| `flutter_dotenv` | 5.2.1 | Variables de entorno desde `.env` |

### Seguridad

| Paquete | Version | Rol |
|---------|---------|-----|
| `flutter_secure_storage` | 9.2.2 | Almacenamiento en Keychain / Keystore |
| `crypto` | 3.0.5 | Checksums SHA-256 para integridad |

### UI y diseno

| Paquete | Version | Rol |
|---------|---------|-----|
| `google_fonts` | 6.2.1 | Bangers (headings) + Nunito (body) |
| `font_awesome_flutter` | 10.7.0 | Iconografia consistente |
| `flutter_animate` | 4.5.0 | Animaciones declarativas a 60/120 FPS |

### Logica de negocio

| Paquete | Version | Rol |
|---------|---------|-----|
| `url_launcher` | 6.3.1 | Deep links a Yape y Plin |
| `intl` | 0.19.0 | Formato monetario PEN |
| `image_picker` | 1.1.2 | Captura de comprobantes de pago |
| `file_cache_flutter` | 0.0.3 | Cache en memoria + disco con TTL |

---

## Esquema de base de datos

### Tablas

#### `profiles`
| Columna | Tipo | Descripcion |
|---------|------|-------------|
| `id` | `uuid` (FK auth.users) | Identificador unico |
| `full_name` | `text` | Nombre del usuario |
| `phone_number` | `text` | Telefono para busquedas |
| `total_owed` | `numeric(12,2)` | Suma de lo que le deben |
| `total_debt` | `numeric(12,2)` | Suma de lo que debe |
| `created_at` | `timestamptz` | Fecha de creacion |

#### `loans`
| Columna | Tipo | Descripcion |
|---------|------|-------------|
| `id` | `uuid` | Identificador del prestamo |
| `creditor_id` | `uuid` (FK profiles) | Quien presto el dinero |
| `debtor_id` | `uuid` (FK profiles) | Quien recibio el dinero (nullable) |
| `debtor_name` | `text` | Nombre si el deudor no tiene cuenta |
| `debtor_phone` | `text` | Telefono del deudor externo |
| `amount` | `numeric(12,2)` | Monto original |
| `remaining_amount` | `numeric(12,2)` | Monto pendiente de pago |
| `currency` | `text` | Moneda (default: `PEN`) |
| `description` | `text` | Descripcion del prestamo |
| `due_date` | `date` | Fecha de vencimiento (nullable) |
| `status` | `enum` | `active`, `partially_paid`, `paid`, `cancelled`, `disputed` |
| `checksum` | `text` | SHA-256 de los campos criticos |

#### `loan_transactions`
| Columna | Tipo | Descripcion |
|---------|------|-------------|
| `id` | `uuid` | Identificador de la transaccion |
| `loan_id` | `uuid` (FK loans) | Prestamo asociado |
| `payer_id` | `uuid` (FK profiles) | Quien registra el pago |
| `amount` | `numeric(12,2)` | Monto del pago |
| `status` | `enum` | `pending`, `confirmed`, `rejected` |
| `payment_method` | `text` | `yape`, `plin`, `cash`, etc. |
| `note` | `text` | Nota del pagador |

#### `payment_proofs`
| Columna | Tipo | Descripcion |
|---------|------|-------------|
| `id` | `uuid` | Identificador |
| `transaction_id` | `uuid` (FK loan_transactions) | Transaccion asociada |
| `storage_path` | `text` | Ruta en Supabase Storage |
| `file_size` | `bigint` | Tamano en bytes (max 10 MB) |

### Funciones RPC

| Funcion | Descripcion |
|---------|-------------|
| `get_user_summary()` | Retorna `total_owed`, `total_debt`, `net_balance` del usuario autenticado |
| `confirm_transaction(uuid)` | Confirma una transaccion pendiente y actualiza `remaining_amount` |

### Triggers

| Trigger | Evento | Accion |
|---------|--------|--------|
| `handle_loan_created` | `INSERT ON loans` | Actualiza `total_owed` en profiles del creditor |
| `handle_transaction_status_change` | `UPDATE ON loan_transactions` | Actualiza `remaining_amount` y estado del prestamo |

### Row Level Security

RLS activo en todas las tablas. Politica general: cada usuario unicamente puede leer y escribir sus propios registros. Las transacciones son visibles tanto para el creditor como para el deudor del prestamo asociado.

---

## Sistema de diseno

Wayqui usa un sistema de diseno propio llamado **Comic Design System**, inspirado en los bordes gruesos y tipografia expresiva del estilo comic.

### Tokens

| Token | Valor | Uso |
|-------|-------|-----|
| `borderWidth` | `2.0` | Tarjetas, botones, formularios |
| `borderWidthList` | `1.0` | Items de lista |
| `borderRadius` | `12.0` | Esquinas redondeadas estandar |
| `borderRadiusLarge` | `20.0` | Modales y sheets |
| `elevation` | `0.0` | Sin sombras (diseno plano) |

### Tipografia

| Uso | Fuente | Estilo |
|-----|--------|--------|
| Titulos y headings | Bangers | Bold, all-caps visual |
| Cuerpo y formularios | Nunito | Variable weight, legible |
| Monospace / OTP | Nunito 24px w700 | Para digitos |

> **Importante:** Los campos de formulario nunca deben usar `headlineSmall` o cualquier estilo que referencie Bangers, ya que renderiza en mayusculas independientemente del valor real del campo.

### Colores semanticos (`WayquiColors`)

| Token | Uso |
|-------|-----|
| `positive` | Montos a favor, balances positivos |
| `negative` | Montos en contra, errores |
| `pending` | Transacciones pendientes |
| `yape` | Color marca Yape |
| `plin` | Color marca Plin |

### Regla de opacidad

Siempre usar `.withValues(alpha: x)` en lugar del deprecado `.withOpacity(x)`.

---

## Pantallas implementadas

### Autenticacion

| Pantalla | Ruta | Descripcion |
|----------|------|-------------|
| `LoginScreen` | `/login` | Email + password, link a registro y recuperacion |
| `OnboardingScreen` | `/register` | Flujo de 5 pasos: nombre, telefono, email, contrasena, confirmar contrasena |
| `OtpVerifyScreen` | `/otp?email=` | 6 cajas de digito, auto-submit, reenvio con cooldown de 60 s |
| `ForgotPasswordScreen` | `/forgot-password` | Envia email de recuperacion |

### Shell principal (bottom navigation)

| Pantalla | Ruta | Descripcion |
|----------|------|-------------|
| `HomeScreen` | `/home` | Balance, lista de prestamos activos, FAB para crear prestamo |
| `ActivityScreen` | `/activity` | Historial de transacciones del usuario |
| `ContactsScreen` | `/contacts` | Contactos con cuenta en Wayqui |
| `ProfileScreen` | `/profile` | Datos del usuario, estadisticas, cerrar sesion |

### Modales

| Pantalla | Ruta | Descripcion |
|----------|------|-------------|
| `CreateLoanScreen` | `/create-loan` | Crear prestamo con busqueda de deudor por telefono |
| `LoanDetailScreen` | `/loan/:loanId` | Detalle con progreso, botones Yape/Plin, timeline de pagos |

---

## Seguridad

### Autenticacion

- Supabase Auth con sesiones JWT almacenadas en `flutter_secure_storage` (Keychain en iOS, Keystore en Android).
- Confirmacion de registro mediante OTP de 6 digitos (`OtpType.signup`).
- Nunca se usa la `SERVICE_ROLE_KEY` en el cliente. Solo `ANON_KEY`.

### Integridad de datos

Cada prestamo se crea con un checksum SHA-256 calculado sobre los campos criticos (`creditor_id`, `debtor_id`, `amount`, `description`, `created_at`). Esto permite detectar modificaciones directas en la base de datos fuera del flujo de la aplicacion.

```dart
// core/utils/checksum_util.dart
static String computeLoanChecksum({...}) {
  final raw = '$creditorId|$debtorId|$amount|$description|$createdAt';
  return sha256.convert(utf8.encode(raw)).toString();
}
```

### Row Level Security

RLS verificado mediante tests de penetracion automatizados:

```bash
dart test test/security/rls_penetration_test.dart --reporter expanded
```

Los tests crean dos usuarios reales via Admin API, intentan acceder a los datos del usuario A siendo usuario B, y verifican que todas las operaciones no autorizadas devuelvan errores o resultados vacios.

### Variables de entorno

Las credenciales de Supabase se cargan desde un archivo `.env` que **no se incluye en el repositorio**. Ver [Configuracion del entorno](#configuracion-del-entorno).

---

## Configuracion del entorno

### Prerrequisitos

- Flutter SDK `>= 3.x` (verificar con `flutter --version`)
- Dart SDK `>= 3.9`
- Cuenta en [Supabase](https://supabase.com)
- Android SDK / Xcode (segun plataforma objetivo)

### Variables de entorno

Crear el archivo `.env` en la raiz del proyecto:

```dotenv
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=<anon-key>
SUPABASE_SERVICE_ROLE_KEY=<service-role-key>   # Solo para tests de RLS
```

> El archivo `.env` esta declarado como asset en `pubspec.yaml` para que `flutter_dotenv` lo pueda cargar en tiempo de ejecucion. Asegurarse de que `.env` este en `.gitignore`.

### Plantilla de email en Supabase

Para que el OTP de confirmacion llegue como un codigo de 6 digitos (no como magic link), actualizar la plantilla **"Confirm signup"** en:

`Supabase Dashboard > Authentication > Email Templates > Confirm signup`

```html
<h2>Confirma tu registro en Wayqui</h2>
<p>Tu codigo de verificacion es:</p>
<h1 style="letter-spacing: 10px; font-size: 40px; font-family: monospace;">
  {{ .Token }}
</h1>
<p>El codigo expira en <strong>1 hora</strong>. No lo compartas con nadie.</p>
<hr>
<p style="font-size: 12px; color: #888;">
  Si no creaste esta cuenta, ignora este mensaje.
</p>
```

---

## Instalacion y ejecucion

```bash
# 1. Clonar el repositorio
git clone <repo-url>
cd wayqui

# 2. Instalar dependencias
flutter pub get

# 3. Crear el archivo .env (ver seccion anterior)

# 4. Ejecutar en modo debug
flutter run

# 5. Build de release (Android)
flutter build apk --release

# 6. Build de release (iOS)
flutter build ipa --release
```

### Orientacion

La aplicacion esta bloqueada en orientacion vertical (`portraitUp` y `portraitDown`) para garantizar consistencia en los layouts financieros.

---

## Tests

### Tests de seguridad RLS

```bash
dart test test/security/rls_penetration_test.dart --reporter expanded
```

Requiere las tres variables de entorno en `.env`. Los tests:

1. Crean dos usuarios reales mediante la Admin API (service role).
2. Autentican a usuario A y crean un prestamo.
3. Autentican a usuario B e intentan leer los prestamos de A.
4. Intentan insertar transacciones en prestamos ajenos.
5. Eliminan los usuarios de prueba al finalizar.

### Tests de widgets

```bash
flutter test
```

---

## Roadmap

### v1.1 — Pagos y comprobantes

- [ ] `RegisterPaymentScreen`: el deudor registra un pago con monto, metodo y comprobante fotografico
- [ ] Subida de comprobantes a Supabase Storage con validacion de tamano (max 10 MB)
- [ ] Vista de comprobante en `LoanDetailScreen`
- [ ] Estado `pending` → `confirmed` / `rejected` por parte del acreedor

### v1.2 — Tiempo real

- [ ] Supabase Realtime: actualizaciones en vivo de prestamos y transacciones via WebSocket
- [ ] Indicador visual de nuevas notificaciones en el shell de navegacion
- [ ] Push notifications (FCM) para pagos registrados y confirmaciones

### v1.3 — Perfil y personalizacion

- [ ] Edicion de nombre y numero de telefono en `ProfileScreen`
- [ ] Subida y recorte de avatar (Supabase Storage)
- [ ] Seleccion de moneda (PEN / USD)
- [ ] Cambio de contrasena desde la app

### v1.4 — Seguridad avanzada

- [ ] Autenticacion biometrica (Face ID / Huella dactilar) via `local_auth`
- [ ] Obfuscacion de codigo para builds de produccion (`--obfuscate --split-debug-info`)
- [ ] Deteccion de root / jailbreak
- [ ] Certificate pinning para las llamadas a Supabase

### v2.0 — Funcionalidades avanzadas

- [ ] Recordatorios automaticos de vencimiento (notificacion programada)
- [ ] Exportacion de historial a PDF
- [ ] Soporte para grupos de deuda (prestamos con multiples acreedores)
- [ ] Estadisticas avanzadas: graficos de tendencia, prestamos por mes
- [ ] Soporte iOS completo (TestFlight / App Store)

---

## Convenciones de codigo

- Todos los colores via `Theme.of(context).colorScheme.*` o `WayquiColors`.
- Espaciados exclusivamente desde `AppConstants.spacing*` (multiplos de 8).
- Sin elevation distinta de `0.0`.
- Opacidad siempre con `.withValues(alpha: x)`.
- Los campos de formulario usan `GoogleFonts.nunito()` para evitar el renderizado en mayusculas de la fuente Bangers.
- Riverpod: `AsyncNotifierProvider` para auth, `AutoDisposeAsyncNotifierProvider` para recursos con ciclo de vida acotado.

---

<p align="center">
  Wayqui — Hecho con cuidado para el mercado peruano.
</p>
