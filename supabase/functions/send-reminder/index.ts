// =============================================================================
// send-reminder — Wayqui Edge Function
// Invocada directamente desde Flutter por el acreedor.
//
// ── Por qué verify_jwt = false ────────────────────────────────────────────────
//   El Gateway de Supabase rechaza con 401 (apikey vacío) cuando functions.invoke()
//   de Flutter no envía el header `apikey` correctamente en algunas versiones del SDK.
//   Con verify_jwt = false, el Gateway pasa la request a nuestro código, que valida
//   el JWT manualmente vía auth.getUser(token) — igualmente seguro, más explícito.
//   Ver: supabase.com/docs/guides/functions/function-configuration
//
//   Capas de seguridad con verify_jwt = false:
//     1. auth.getUser(token)     → 401 si JWT inválido o ausente
//     2. RLS en .from('loans')   → 404 si el usuario no es acreedor/deudor
//     3. creditor_id === user.id → 403 si no es el acreedor específico
//     4. debtor_id existe        → 400 si el deudor no tiene cuenta Wayqui
//
// ── Decisiones técnicas ───────────────────────────────────────────────────────
//   • Resend vía fetch nativo (patrón oficial Supabase + Resend docs).
//     No se usa npm:resend: crashea la inicialización del módulo en Deno.
//   • RESEND_FROM default = "Wayqui <onboarding@resend.dev>" (dominio compartido
//     de Resend, no requiere verificación). Cuando tengas dominio propio,
//     configura el secret RESEND_FROM en el Dashboard.
//   • Admin client SOLO para leer perfiles de terceros que RLS bloquearía.
//
// ── DEPLOY ────────────────────────────────────────────────────────────────────
//   supabase functions deploy send-reminder --no-verify-jwt
//
// ── SECRETS (Dashboard → Edge Functions → Secrets) ───────────────────────────
//   RESEND_API_KEY   re_xxxxxxxxxxxxxxxxxxxxxxxx          ← REQUERIDO
//   RESEND_FROM      Wayqui <hola@tudominio.com>          ← opcional (tras verificar dominio)
//   APP_URL          https://wayqui.app                   ← opcional
//
// AUTO-INYECTADOS por Supabase runtime:
//   SUPABASE_URL · SUPABASE_ANON_KEY · SUPABASE_SERVICE_ROLE_KEY
// =============================================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import type { Loan, Profile } from '../_shared/types.ts';

// ─── Configuración ────────────────────────────────────────────────────────────

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? '';
// onboarding@resend.dev: dominio compartido de Resend, no requiere verificación.
// Cambia este valor a tu sender cuando verifiques tu dominio en Resend.
const RESEND_FROM    = Deno.env.get('RESEND_FROM') ?? 'Wayqui <onboarding@resend.dev>';
const APP_URL        = Deno.env.get('APP_URL')     ?? 'https://wayqui.app';

// ─── CORS headers ─────────────────────────────────────────────────────────────

const CORS = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type, apikey, x-client-info',
};

// ─── Helpers de respuesta ─────────────────────────────────────────────────────

function ok(data: unknown): Response {
  return new Response(JSON.stringify(data), {
    status:  200,
    headers: { 'Content-Type': 'application/json', ...CORS },
  });
}

function err(message: string, status = 400, detail?: unknown): Response {
  return new Response(
    JSON.stringify({ ok: false, error: message, ...(detail !== undefined ? { detail } : {}) }),
    { status, headers: { 'Content-Type': 'application/json', ...CORS } },
  );
}

// ─── Clientes Supabase ────────────────────────────────────────────────────────

/** User-scoped: valida JWT vía auth.getUser() + aplica RLS. */
function userClient(authorization: string) {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authorization } }, auth: { persistSession: false } },
  );
}

/** Admin: bypasea RLS para lecturas privilegiadas (perfiles de otros usuarios). */
function adminClient() {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );
}

// ─── Template de email ────────────────────────────────────────────────────────

function reminderHtml(p: {
  debtorName:   string;
  creditorName: string;
  description:  string;
  remaining:    number;
  currency:     string;
}): string {
  return `<!DOCTYPE html>
<html lang="es">
<body style="font-family:sans-serif;max-width:520px;margin:auto;padding:24px;background:#fafafa">
  <div style="background:#fff;border-radius:12px;padding:32px;border:1px solid #e5e7eb">
    <h2 style="color:#1a1a2e;margin:0 0 8px">Recordatorio de pago</h2>
    <p style="color:#6b7280;font-size:14px;margin:0 0 24px">Enviado a través de Wayqui</p>
    <p style="color:#374151">Hola <strong>${p.debtorName}</strong>,</p>
    <p style="color:#374151">
      <strong>${p.creditorName}</strong> te recuerda que tienes un saldo
      pendiente en el préstamo <em>"${p.description}"</em>.
    </p>
    <div style="background:#f3f4f6;border-radius:8px;padding:16px;margin:20px 0;text-align:center">
      <p style="color:#6b7280;font-size:13px;margin:0 0 4px">Saldo pendiente</p>
      <p style="color:#1a1a2e;font-size:28px;font-weight:700;margin:0">
        ${p.currency} ${p.remaining.toFixed(2)}
      </p>
    </div>
    <a href="${APP_URL}"
       style="display:inline-block;background:#6c63ff;color:#fff;padding:13px 28px;
              border-radius:8px;text-decoration:none;font-weight:600;font-size:15px">
      Registrar pago en Wayqui
    </a>
    <p style="color:#9ca3af;font-size:12px;margin-top:24px;line-height:1.6">
      Recordatorio enviado por un usuario de Wayqui.<br>
      Si ya pagaste, puedes ignorar este mensaje.
    </p>
  </div>
</body>
</html>`;
}

// ─── Envío de email via Resend REST API ───────────────────────────────────────

interface ResendOk  { id: string }
interface ResendErr { name: string; message: string; statusCode: number }

async function sendEmail(payload: {
  to:      string;
  subject: string;
  html:    string;
}): Promise<{ emailId: string } | { resendError: ResendErr }> {
  const res = await fetch('https://api.resend.com/emails', {
    method:  'POST',
    headers: {
      'Authorization': `Bearer ${RESEND_API_KEY}`,
      'Content-Type':  'application/json',
    },
    body: JSON.stringify({
      from:    RESEND_FROM,
      to:      [payload.to],
      subject: payload.subject,
      html:    payload.html,
    }),
  });

  const body = await res.json();

  if (!res.ok) {
    return { resendError: body as ResendErr };
  }
  return { emailId: (body as ResendOk).id };
}

// ─── Handler principal ────────────────────────────────────────────────────────

Deno.serve(async (req: Request): Promise<Response> => {
  console.log(`[send-reminder] ${req.method} ${new URL(req.url).pathname}`);

  // ── CORS preflight ─────────────────────────────────────────────────────────
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS });
  }

  if (req.method !== 'POST') {
    return err('Method Not Allowed', 405);
  }

  try {
    // ── 1. Validar JWT (patrón oficial Supabase) ────────────────────────────
    const authorization = req.headers.get('Authorization');
    if (!authorization) {
      return err('Authorization header requerido', 401);
    }

    const token = authorization.replace(/^Bearer\s+/i, '');
    const uc    = userClient(authorization);

    const { data: { user }, error: authErr } = await uc.auth.getUser(token);
    if (authErr || !user) {
      console.warn('[send-reminder] JWT inválido:', authErr?.message);
      return err('Sesión inválida o expirada. Vuelve a iniciar sesión.', 401);
    }

    console.log('[send-reminder] usuario autenticado:', user.id);

    // ── 2. Parsear body ─────────────────────────────────────────────────────
    let loanId: string;
    try {
      const body = await req.json() as Record<string, unknown>;
      const raw  = body['loan_id'];
      if (typeof raw !== 'string' || !raw.trim()) throw new TypeError('bad');
      loanId = raw.trim();
    } catch {
      return err('loan_id es requerido y debe ser un string no vacío');
    }

    // ── 3. Obtener préstamo (RLS: solo acreedor/deudor puede leerlo) ────────
    const { data: loanRow, error: loanErr } = await uc
      .from('loans')
      .select('id, creditor_id, debtor_id, debtor_name, description, remaining_amount, currency, status')
      .eq('id', loanId)
      .single();

    if (loanErr || !loanRow) {
      console.warn('[send-reminder] préstamo no encontrado:', loanErr?.message);
      return err('Préstamo no encontrado', 404);
    }

    const loan = loanRow as Loan;
    console.log('[send-reminder] préstamo:', loan.id, 'status:', loan.status);

    // ── 4. Autorización de negocio ──────────────────────────────────────────
    if (loan.creditor_id !== user.id) {
      return err('Solo el acreedor puede enviar un recordatorio', 403);
    }
    if (loan.status === 'paid' || loan.status === 'cancelled') {
      return err('El préstamo ya está saldado o cancelado', 400);
    }
    if (!loan.debtor_id) {
      return err('El deudor no tiene cuenta Wayqui — usa WhatsApp para recordarle', 400);
    }

    // ── 5. Obtener perfiles (admin bypasea RLS en filas de terceros) ────────
    const ac = adminClient();
    const [debtorRes, creditorRes] = await Promise.all([
      ac.from('profiles').select('id, email, full_name').eq('id', loan.debtor_id).single(),
      ac.from('profiles').select('id, email, full_name').eq('id', loan.creditor_id).single(),
    ]);

    const debtor   = debtorRes.data   as Profile | null;
    const creditor = creditorRes.data as Profile | null;

    if (!debtor?.email) {
      return err('No se encontró el correo del deudor', 400);
    }

    // ── 6. Guardia RESEND_API_KEY ───────────────────────────────────────────
    if (!RESEND_API_KEY) {
      console.error('[send-reminder] RESEND_API_KEY no configurado');
      return err('Servicio de correo no configurado. Contacta al administrador.', 503);
    }

    // ── 7. Enviar email ─────────────────────────────────────────────────────
    console.log('[send-reminder] enviando email a:', debtor.email);

    const result = await sendEmail({
      to:      debtor.email,
      subject: `${creditor?.full_name ?? 'Tu acreedor'} te recuerda: debes ${loan.currency} ${loan.remaining_amount.toFixed(2)}`,
      html:    reminderHtml({
        debtorName:   debtor.full_name    ?? loan.debtor_name ?? 'Usuario',
        creditorName: creditor?.full_name ?? 'Tu acreedor',
        description:  loan.description,
        remaining:    loan.remaining_amount,
        currency:     loan.currency,
      }),
    });

    if ('resendError' in result) {
      console.error('[send-reminder] Resend error:', JSON.stringify(result.resendError));
      // Devuelve el error completo de Resend → Flutter lo muestra en SnackBar
      return err(
        `Resend: ${result.resendError.message}`,
        502,
        result.resendError,
      );
    }

    console.log('[send-reminder] email enviado — id:', result.emailId);
    return ok({ ok: true, emailId: result.emailId });

  } catch (e) {
    // Captura inesperada — siempre loguear antes de responder
    console.error('[send-reminder] error inesperado:', e);
    return err(`Error interno: ${e instanceof Error ? e.message : String(e)}`, 500);
  }
});
