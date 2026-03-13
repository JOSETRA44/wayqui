// ─────────────────────────────────────────────────────────────────────────────
// Shared types for Wayqui Edge Functions
// ─────────────────────────────────────────────────────────────────────────────

export interface LoanTransaction {
  id: string;
  loan_id: string;
  payer_id: string;
  amount: number;
  payment_method: 'yape' | 'plin' | 'cash' | 'bank_transfer' | 'other';
  status: 'pending' | 'confirmed' | 'rejected' | 'disputed';
  notes: string | null;
  operation_id: string | null;
  evidence_path: string | null;
  payment_metadata: Record<string, unknown> | null;
  checksum: string;
  created_at: string;
  confirmed_at: string | null;
  rejected_at: string | null;
  disputed_at: string | null;
  confirmed_by: string | null;
  rejection_reason: string | null;
  dispute_reason: string | null;
}

export interface Loan {
  id: string;
  creditor_id: string;
  debtor_id: string | null;
  debtor_name: string | null;
  debtor_phone: string | null;
  amount: number;
  remaining_amount: number;
  currency: string;
  description: string;
  due_date: string | null;
  status: 'active' | 'partially_paid' | 'paid' | 'cancelled' | 'disputed';
  created_at: string;
}

export interface Profile {
  id: string;
  email: string;
  full_name: string | null;
  phone_number: string | null;
}

// Webhook payload from Supabase Database Webhooks
export interface DatabaseWebhookPayload<T = Record<string, unknown>> {
  type: 'INSERT' | 'UPDATE' | 'DELETE';
  table: string;
  schema: string;
  record: T | null;      // null on DELETE
  old_record: T | null;  // null on INSERT
}

// Email notification types
export interface PaymentRegisteredEmail {
  to: string;            // creditor's email
  creditorName: string;
  debtorName: string;
  amount: number;
  currency: string;
  loanDescription: string;
  operationId: string | null;
  paymentMethod: string;
  transactionId: string;
}

export interface PaymentConfirmedEmail {
  to: string;            // debtor's email
  debtorName: string;
  creditorName: string;
  amount: number;
  currency: string;
  remainingAmount: number;
  transactionId: string;
}

export interface PaymentDisputedEmail {
  to: string;            // debtor's email
  debtorName: string;
  creditorName: string;
  amount: number;
  reason: string | null;
  transactionId: string;
}
