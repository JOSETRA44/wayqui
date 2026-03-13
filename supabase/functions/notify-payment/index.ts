// =============================================================================
// Ghost Notifier — Wayqui Edge Function
// Triggered by: Supabase Database Webhook on loan_transactions (INSERT + UPDATE)
//
// SETUP IN SUPABASE DASHBOARD:
//   1. Project → Edge Functions → Deploy this function
//   2. Project → Database → Webhooks → New webhook:
//        Name:    notify-payment
//        Table:   public.loan_transactions
//        Events:  INSERT, UPDATE
//        Method:  POST
//        URL:     https://<project-ref>.supabase.co/functions/v1/notify-payment
//        Headers: { "Authorization": "Bearer <service-role-key>" }
//   3. Project → Settings → Edge Functions → Secrets:
//        RESEND_API_KEY   = re_xxxxxxxxxxxxxxxxxxxxxxxx
//        APP_URL          = https://wayqui.app  (or your domain)
//        SUPABASE_URL     = https://<project-ref>.supabase.co  (auto-injected)
//        SUPABASE_SERVICE_ROLE_KEY = <service-role-key>  (auto-injected)
// =============================================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import type {
  DatabaseWebhookPayload,
  LoanTransaction,
  Loan,
  Profile,
  PaymentRegisteredEmail,
  PaymentConfirmedEmail,
  PaymentDisputedEmail,
} from '../_shared/types.ts';

// ─── Resend email client ──────────────────────────────────────────────────────

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? '';
const APP_URL        = Deno.env.get('APP_URL') ?? 'https://wayqui.app';

async function sendEmail(payload: {
  from: string;
  to: string;
  subject: string;
  html: string;
}): Promise<void> {
  if (!RESEND_API_KEY) {
    console.warn('[notify-payment] RESEND_API_KEY not set — email skipped');
    return;
  }

  const res = await fetch('https://api.resend.com/emails', {
    method:  'POST',
    headers: {
      'Authorization': `Bearer ${RESEND_API_KEY}`,
      'Content-Type':  'application/json',
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const err = await res.text();
    console.error('[notify-payment] Resend error:', err);
    // Non-fatal: log and continue — notification failure must never block DB ops
  }
}

// ─── Email templates ──────────────────────────────────────────────────────────

function paymentRegisteredHtml(data: PaymentRegisteredEmail): string {
  const method = data.paymentMethod === 'yape'
    ? 'Yape' : data.paymentMethod === 'plin' ? 'Plin' : data.paymentMethod;

  return `
<!DOCTYPE html><html lang="es"><body style="font-family:sans-serif;max-width:520px;margin:auto;padding:24px">
  <h2 style="color:#1a1a2e">Wayqui — Pago recibido</h2>
  <p>Hola <strong>${data.creditorName}</strong>,</p>
  <p><strong>${data.debtorName}</strong> ha registrado un pago por el préstamo
     <em>"${data.loanDescription}"</em>.</p>
  <table style="width:100%;border-collapse:collapse;margin:16px 0">
    <tr><td style="padding:8px;background:#f5f5f5;font-weight:bold">Monto</td>
        <td style="padding:8px">${data.currency} ${data.amount.toFixed(2)}</td></tr>
    <tr><td style="padding:8px;background:#f5f5f5;font-weight:bold">Método</td>
        <td style="padding:8px">${method}</td></tr>
    ${data.operationId ? `<tr><td style="padding:8px;background:#f5f5f5;font-weight:bold">N° operación</td>
        <td style="padding:8px;font-family:monospace">${data.operationId}</td></tr>` : ''}
  </table>
  <a href="${APP_URL}" style="display:inline-block;background:#6c63ff;color:#fff;padding:12px 24px;border-radius:8px;text-decoration:none;font-weight:bold">
    Confirmar en Wayqui
  </a>
  <p style="color:#888;font-size:12px;margin-top:24px">
    Si no reconoces este pago, puedes disputarlo desde la app.<br>
    Referencia: ${data.transactionId}
  </p>
</body></html>`;
}

function paymentConfirmedHtml(data: PaymentConfirmedEmail): string {
  return `
<!DOCTYPE html><html lang="es"><body style="font-family:sans-serif;max-width:520px;margin:auto;padding:24px">
  <h2 style="color:#1a1a2e">Wayqui — Pago confirmado</h2>
  <p>Hola <strong>${data.debtorName}</strong>,</p>
  <p><strong>${data.creditorName}</strong> ha confirmado tu pago de
     <strong>${data.currency} ${data.amount.toFixed(2)}</strong>.</p>
  <p>Saldo pendiente: <strong>${data.currency} ${data.remainingAmount.toFixed(2)}</strong>.</p>
  <a href="${APP_URL}" style="display:inline-block;background:#22c55e;color:#fff;padding:12px 24px;border-radius:8px;text-decoration:none;font-weight:bold">
    Ver en Wayqui
  </a>
  <p style="color:#888;font-size:12px;margin-top:24px">Referencia: ${data.transactionId}</p>
</body></html>`;
}

function paymentDisputedHtml(data: PaymentDisputedEmail): string {
  return `
<!DOCTYPE html><html lang="es"><body style="font-family:sans-serif;max-width:520px;margin:auto;padding:24px">
  <h2 style="color:#1a1a2e">Wayqui — Pago en disputa</h2>
  <p>Hola <strong>${data.debtorName}</strong>,</p>
  <p><strong>${data.creditorName}</strong> ha disputado tu pago de
     <strong>${data.amount.toFixed(2)}</strong>.</p>
  ${data.reason ? `<p>Motivo: <em>${data.reason}</em></p>` : ''}
  <a href="${APP_URL}" style="display:inline-block;background:#ef4444;color:#fff;padding:12px 24px;border-radius:8px;text-decoration:none;font-weight:bold">
    Ver detalles en Wayqui
  </a>
  <p style="color:#888;font-size:12px;margin-top:24px">Referencia: ${data.transactionId}</p>
</body></html>`;
}

// ─── Supabase admin client ────────────────────────────────────────────────────

function getAdminClient() {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );
}

// ─── Fetch helpers ────────────────────────────────────────────────────────────

async function fetchLoan(supabase: ReturnType<typeof createClient>, loanId: string): Promise<Loan | null> {
  const { data } = await supabase.from('loans').select('*').eq('id', loanId).single();
  return data as Loan | null;
}

async function fetchProfile(supabase: ReturnType<typeof createClient>, userId: string): Promise<Profile | null> {
  const { data } = await supabase.from('profiles').select('id,email,full_name,phone_number').eq('id', userId).single();
  return data as Profile | null;
}

// ─── Event handlers ───────────────────────────────────────────────────────────

async function handleInsert(txn: LoanTransaction): Promise<void> {
  const supabase = getAdminClient();
  const loan = await fetchLoan(supabase, txn.loan_id);
  if (!loan) return;

  const creditor = await fetchProfile(supabase, loan.creditor_id);
  const debtor   = loan.debtor_id ? await fetchProfile(supabase, loan.debtor_id) : null;
  if (!creditor) return;

  await sendEmail({
    from:    'Wayqui <notificaciones@wayqui.app>',
    to:      creditor.email,
    subject: `Pago de ${debtor?.full_name ?? 'tu deudor'} — S/ ${txn.amount.toFixed(2)}`,
    html:    paymentRegisteredHtml({
      to:              creditor.email,
      creditorName:    creditor.full_name ?? 'Usuario',
      debtorName:      debtor?.full_name ?? loan.debtor_name ?? 'Tu deudor',
      amount:          txn.amount,
      currency:        loan.currency,
      loanDescription: loan.description,
      operationId:     txn.operation_id,
      paymentMethod:   txn.payment_method,
      transactionId:   txn.id,
    }),
  });
}

async function handleUpdate(txn: LoanTransaction, oldTxn: LoanTransaction): Promise<void> {
  // Only act on actual status transitions
  if (txn.status === oldTxn.status) return;

  const supabase = getAdminClient();
  const loan = await fetchLoan(supabase, txn.loan_id);
  if (!loan) return;

  const creditor = await fetchProfile(supabase, loan.creditor_id);
  const debtor   = loan.debtor_id ? await fetchProfile(supabase, loan.debtor_id) : null;

  // confirmed → notify debtor
  if (txn.status === 'confirmed' && debtor) {
    await sendEmail({
      from:    'Wayqui <notificaciones@wayqui.app>',
      to:      debtor.email,
      subject: `Tu pago de S/ ${txn.amount.toFixed(2)} fue confirmado`,
      html:    paymentConfirmedHtml({
        to:              debtor.email,
        debtorName:      debtor.full_name ?? 'Usuario',
        creditorName:    creditor?.full_name ?? 'Tu acreedor',
        amount:          txn.amount,
        currency:        loan.currency,
        remainingAmount: loan.remaining_amount,
        transactionId:   txn.id,
      }),
    });
  }

  // disputed → notify debtor
  if (txn.status === 'disputed' && debtor) {
    await sendEmail({
      from:    'Wayqui <notificaciones@wayqui.app>',
      to:      debtor.email,
      subject: `Tu pago de S/ ${txn.amount.toFixed(2)} está en disputa`,
      html:    paymentDisputedHtml({
        to:           debtor.email,
        debtorName:   debtor.full_name ?? 'Usuario',
        creditorName: creditor?.full_name ?? 'Tu acreedor',
        amount:       txn.amount,
        reason:       txn.dispute_reason,
        transactionId: txn.id,
      }),
    });
  }
}

// ─── Entry point ─────────────────────────────────────────────────────────────

Deno.serve(async (req: Request): Promise<Response> => {
  // Validate method
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 });
  }

  let payload: DatabaseWebhookPayload<LoanTransaction>;
  try {
    payload = await req.json() as DatabaseWebhookPayload<LoanTransaction>;
  } catch {
    return new Response('Bad Request', { status: 400 });
  }

  // Only process loan_transactions events
  if (payload.table !== 'loan_transactions') {
    return new Response('OK', { status: 200 });
  }

  try {
    if (payload.type === 'INSERT' && payload.record) {
      await handleInsert(payload.record);
    } else if (payload.type === 'UPDATE' && payload.record && payload.old_record) {
      await handleUpdate(payload.record, payload.old_record);
    }
  } catch (err) {
    // Log but do not expose error details — return 200 to prevent webhook retries
    // that would otherwise loop infinitely on a permanent error.
    console.error('[notify-payment] Unhandled error:', err);
  }

  return new Response(JSON.stringify({ ok: true }), {
    status:  200,
    headers: { 'Content-Type': 'application/json' },
  });
});
