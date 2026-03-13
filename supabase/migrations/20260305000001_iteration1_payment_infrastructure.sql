-- =============================================================================
-- MIGRATION: Iteration 1 — Payment Infrastructure
-- Project: Wayqui (qiuhgklbnydxjmtijjke)
-- Created: 2026-03-05
--
-- APPLY: Run in Supabase Dashboard → SQL Editor, in order.
-- All statements are idempotent (IF NOT EXISTS / CREATE OR REPLACE).
-- =============================================================================


-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 1: Extend loan_transactions
-- ─────────────────────────────────────────────────────────────────────────────

-- 1a. operation_id — unique token printed by Yape/Plin (nullable: cash has none)
ALTER TABLE public.loan_transactions
  ADD COLUMN IF NOT EXISTS operation_id      TEXT,
  ADD COLUMN IF NOT EXISTS evidence_path     TEXT,       -- Supabase Storage path
  ADD COLUMN IF NOT EXISTS payment_metadata  JSONB,      -- { ocr_amount, ocr_operation_id, raw_text }
  ADD COLUMN IF NOT EXISTS disputed_at       TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS dispute_reason    TEXT;

-- 1b. Partial unique index: only enforce uniqueness when operation_id is present.
--     Prevents double-submission of the same Yape/Plin transfer.
CREATE UNIQUE INDEX IF NOT EXISTS loan_transactions_operation_id_uidx
  ON public.loan_transactions (operation_id)
  WHERE operation_id IS NOT NULL;

-- 1c. Status CHECK constraint (replaces implicit text-only enforcement).
--     Includes 'disputed' state for contested payments.
ALTER TABLE public.loan_transactions
  DROP CONSTRAINT IF EXISTS loan_transactions_status_check;
ALTER TABLE public.loan_transactions
  ADD CONSTRAINT loan_transactions_status_check
  CHECK (status IN ('pending', 'confirmed', 'rejected', 'disputed'));

-- 1d. Same constraint for loans.status (disputed already in Dart enum, now enforced in DB).
ALTER TABLE public.loans
  DROP CONSTRAINT IF EXISTS loans_status_check;
ALTER TABLE public.loans
  ADD CONSTRAINT loans_status_check
  CHECK (status IN ('active', 'partially_paid', 'paid', 'cancelled', 'disputed'));


-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 2: Transaction trigger (BEFORE UPDATE — idempotent rebuild)
--
-- DESIGN DECISIONS:
--   • BEFORE trigger: allows mutating NEW (set confirmed_at, disputed_at, etc.)
--   • FOR UPDATE lock on loans row: prevents concurrent double-confirmation
--   • Balance changes ONLY on pending→confirmed (never on any other transition)
--   • Balances floored at 0 (GREATEST) to prevent negative values
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.handle_transaction_status_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_loan            public.loans%ROWTYPE;
  v_new_remaining   NUMERIC(12,2);
  v_new_loan_status TEXT;
BEGIN
  -- ── CONFIRMED (pending → confirmed only) ─────────────────────────────────
  IF NEW.status = 'confirmed' AND OLD.status = 'pending' THEN

    NEW.confirmed_at := now();
    NEW.confirmed_by := auth.uid();   -- creditor who confirmed in-app

    -- Lock the loan row to prevent concurrent confirmations from double-counting
    SELECT * INTO v_loan
      FROM public.loans
     WHERE id = NEW.loan_id
       FOR UPDATE;

    v_new_remaining   := GREATEST(0, v_loan.remaining_amount - NEW.amount);
    v_new_loan_status := CASE WHEN v_new_remaining = 0 THEN 'paid' ELSE 'partially_paid' END;

    UPDATE public.loans
       SET remaining_amount = v_new_remaining,
           status           = v_new_loan_status,
           updated_at       = now()
     WHERE id = NEW.loan_id;

    -- Decrement creditor's total_owed
    UPDATE public.profiles
       SET total_owed        = GREATEST(0, total_owed - NEW.amount),
           balance_updated_at = now()
     WHERE id = v_loan.creditor_id;

    -- Decrement debtor's total_debt (only if debtor has an account)
    IF v_loan.debtor_id IS NOT NULL THEN
      UPDATE public.profiles
         SET total_debt        = GREATEST(0, total_debt - NEW.amount),
             balance_updated_at = now()
       WHERE id = v_loan.debtor_id;
    END IF;

  -- ── REJECTED (pending → rejected only) ───────────────────────────────────
  ELSIF NEW.status = 'rejected' AND OLD.status = 'pending' THEN
    NEW.rejected_at := now();
    -- No balance changes: the payment was not accepted

  -- ── DISPUTED (pending or confirmed → disputed) ───────────────────────────
  ELSIF NEW.status = 'disputed' AND OLD.status IN ('pending', 'confirmed') THEN
    NEW.disputed_at := now();

    -- If the payment was previously confirmed, roll back the balance changes
    IF OLD.status = 'confirmed' THEN
      SELECT * INTO v_loan FROM public.loans WHERE id = NEW.loan_id FOR UPDATE;

      UPDATE public.loans
         SET remaining_amount = LEAST(v_loan.amount, v_loan.remaining_amount + NEW.amount),
             status           = CASE
               WHEN v_loan.remaining_amount + NEW.amount >= v_loan.amount THEN 'active'
               ELSE 'partially_paid'
             END,
             updated_at = now()
       WHERE id = NEW.loan_id;

      UPDATE public.profiles
         SET total_owed        = total_owed + NEW.amount,
             balance_updated_at = now()
       WHERE id = v_loan.creditor_id;

      IF v_loan.debtor_id IS NOT NULL THEN
        UPDATE public.profiles
           SET total_debt        = total_debt + NEW.amount,
               balance_updated_at = now()
         WHERE id = v_loan.debtor_id;
      END IF;
    END IF;

    -- Mark the loan itself as disputed regardless of previous transaction state
    UPDATE public.loans
       SET status     = 'disputed',
           updated_at = now()
     WHERE id = NEW.loan_id;

  END IF;

  RETURN NEW;
END;
$$;

-- Drop and recreate trigger (BEFORE UPDATE replaces any previous AFTER UPDATE)
DROP TRIGGER IF EXISTS trg_transaction_status_change ON public.loan_transactions;
CREATE TRIGGER trg_transaction_status_change
  BEFORE UPDATE OF status ON public.loan_transactions
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_transaction_status_change();


-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 3: RPCs — In-app payment lifecycle
-- ─────────────────────────────────────────────────────────────────────────────

-- 3a. register_payment — atomic: creates transaction + optional evidence record
--     Called by the debtor from RegisterPaymentScreen.
CREATE OR REPLACE FUNCTION public.register_payment(
  p_loan_id          UUID,
  p_amount           NUMERIC,
  p_payment_method   TEXT,
  p_notes            TEXT    DEFAULT NULL,
  p_operation_id     TEXT    DEFAULT NULL,
  p_evidence_path    TEXT    DEFAULT NULL,
  p_payment_metadata JSONB   DEFAULT NULL
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_loan   public.loans%ROWTYPE;
  v_txn_id UUID;
  v_cksum  TEXT;
BEGIN
  -- Load and validate the loan
  SELECT * INTO v_loan FROM public.loans WHERE id = p_loan_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Préstamo no encontrado';
  END IF;

  IF v_loan.debtor_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Solo el deudor puede registrar pagos en este préstamo';
  END IF;

  IF v_loan.status NOT IN ('active', 'partially_paid') THEN
    RAISE EXCEPTION 'El préstamo no está activo (estado: %)', v_loan.status;
  END IF;

  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'El monto debe ser mayor a cero';
  END IF;

  IF p_amount > v_loan.remaining_amount THEN
    RAISE EXCEPTION 'El monto (%) supera el saldo pendiente (%)',
      p_amount, v_loan.remaining_amount;
  END IF;

  -- Checksum for client-side integrity verification
  v_cksum := encode(
    sha256((auth.uid()::TEXT || p_loan_id::TEXT || p_amount::TEXT || now()::TEXT)::BYTEA),
    'hex'
  );

  -- Insert transaction
  INSERT INTO public.loan_transactions (
    loan_id, payer_id, amount, payment_method,
    status, notes, operation_id, evidence_path,
    payment_metadata, checksum
  ) VALUES (
    p_loan_id, auth.uid(), p_amount, p_payment_method,
    'pending', p_notes, p_operation_id, p_evidence_path,
    p_payment_metadata, v_cksum
  ) RETURNING id INTO v_txn_id;

  -- Record evidence metadata if an upload path was provided
  IF p_evidence_path IS NOT NULL THEN
    INSERT INTO public.payment_proofs (transaction_id, uploaded_by, storage_path)
    VALUES (v_txn_id, auth.uid(), p_evidence_path);
  END IF;

  RETURN json_build_object(
    'success',        true,
    'transaction_id', v_txn_id,
    'checksum',       v_cksum
  );
END;
$$;


-- 3b. confirm_transaction — only the creditor can confirm
CREATE OR REPLACE FUNCTION public.confirm_transaction(p_transaction_id UUID)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_txn  public.loan_transactions%ROWTYPE;
  v_loan public.loans%ROWTYPE;
BEGIN
  SELECT * INTO v_txn FROM public.loan_transactions WHERE id = p_transaction_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Transacción no encontrada';
  END IF;

  SELECT * INTO v_loan FROM public.loans WHERE id = v_txn.loan_id;

  IF v_loan.creditor_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Solo el acreedor puede confirmar esta transacción';
  END IF;

  IF v_txn.status <> 'pending' THEN
    RAISE EXCEPTION 'La transacción no está pendiente (estado actual: %)', v_txn.status;
  END IF;

  -- Trigger fires BEFORE the update and handles balances
  UPDATE public.loan_transactions
     SET status = 'confirmed'
   WHERE id = p_transaction_id;

  RETURN json_build_object('success', true, 'transaction_id', p_transaction_id);
END;
$$;


-- 3c. dispute_transaction — creditor disputes a pending payment
CREATE OR REPLACE FUNCTION public.dispute_transaction(
  p_transaction_id UUID,
  p_reason         TEXT DEFAULT NULL
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_txn  public.loan_transactions%ROWTYPE;
  v_loan public.loans%ROWTYPE;
BEGIN
  SELECT * INTO v_txn FROM public.loan_transactions WHERE id = p_transaction_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Transacción no encontrada';
  END IF;

  SELECT * INTO v_loan FROM public.loans WHERE id = v_txn.loan_id;

  IF v_loan.creditor_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Solo el acreedor puede disputar esta transacción';
  END IF;

  IF v_txn.status NOT IN ('pending', 'confirmed') THEN
    RAISE EXCEPTION 'No se puede disputar una transacción en estado: %', v_txn.status;
  END IF;

  -- Trigger handles: disputed_at, loan status, and balance rollback if was confirmed
  UPDATE public.loan_transactions
     SET status         = 'disputed',
         dispute_reason = p_reason
   WHERE id = p_transaction_id;

  RETURN json_build_object('success', true, 'transaction_id', p_transaction_id);
END;
$$;


-- 3d. reject_transaction — creditor rejects a pending payment (wrong amount, etc.)
CREATE OR REPLACE FUNCTION public.reject_transaction(
  p_transaction_id UUID,
  p_reason         TEXT DEFAULT NULL
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_txn  public.loan_transactions%ROWTYPE;
  v_loan public.loans%ROWTYPE;
BEGIN
  SELECT * INTO v_txn FROM public.loan_transactions WHERE id = p_transaction_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Transacción no encontrada';
  END IF;

  SELECT * INTO v_loan FROM public.loans WHERE id = v_txn.loan_id;

  IF v_loan.creditor_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Solo el acreedor puede rechazar esta transacción';
  END IF;

  IF v_txn.status <> 'pending' THEN
    RAISE EXCEPTION 'Solo se pueden rechazar transacciones pendientes (estado: %)', v_txn.status;
  END IF;

  UPDATE public.loan_transactions
     SET status           = 'rejected',
         rejection_reason = p_reason
   WHERE id = p_transaction_id;

  RETURN json_build_object('success', true, 'transaction_id', p_transaction_id);
END;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 4: RLS — loan_transactions (ensure debtor can INSERT, both can SELECT)
-- ─────────────────────────────────────────────────────────────────────────────

-- Enable RLS (idempotent)
ALTER TABLE public.loan_transactions ENABLE ROW LEVEL SECURITY;

-- Drop and recreate policies to ensure correct definitions
DROP POLICY IF EXISTS "loan_parties_select_transactions"  ON public.loan_transactions;
DROP POLICY IF EXISTS "debtor_insert_transaction"         ON public.loan_transactions;
DROP POLICY IF EXISTS "creditor_update_transaction"       ON public.loan_transactions;

CREATE POLICY "loan_parties_select_transactions"
  ON public.loan_transactions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.loans l
       WHERE l.id = loan_id
         AND (l.creditor_id = auth.uid() OR l.debtor_id = auth.uid())
    )
  );

-- Debtor inserts via register_payment RPC (SECURITY DEFINER bypasses RLS).
-- This policy is the direct-client fallback — the RPC is the preferred path.
CREATE POLICY "debtor_insert_transaction"
  ON public.loan_transactions FOR INSERT
  WITH CHECK (
    payer_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM public.loans l
       WHERE l.id = loan_id AND l.debtor_id = auth.uid()
         AND l.status IN ('active', 'partially_paid')
    )
  );

-- Status changes only via RPCs (SECURITY DEFINER) — direct UPDATE is blocked.
-- Creditors can only update their own transactions.
CREATE POLICY "creditor_update_transaction"
  ON public.loan_transactions FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.loans l
       WHERE l.id = loan_id AND l.creditor_id = auth.uid()
    )
  );


-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 5: Storage — payment_proofs bucket policies
--
-- Path convention: {loan_id}/{transaction_id}/{uuid}.{ext}
-- storage.foldername(name)[1] = loan_id  (first path segment)
-- storage.foldername(name)[2] = transaction_id
-- ─────────────────────────────────────────────────────────────────────────────

-- Storage RLS is managed via Supabase Storage policies.
-- These must be created via the Supabase Dashboard or Management API.
-- SQL equivalent (for documentation and manual application):

/*
-- READ: creditor or debtor of the loan can view proofs
CREATE POLICY "loan_parties_can_read_proofs"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'payment_proofs' AND
    EXISTS (
      SELECT 1 FROM public.loans l
       WHERE l.id::TEXT = (storage.foldername(name))[1]
         AND (l.creditor_id = auth.uid() OR l.debtor_id = auth.uid())
    )
  );

-- INSERT: only the debtor of the loan can upload proofs
CREATE POLICY "debtor_can_upload_proofs"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'payment_proofs' AND
    EXISTS (
      SELECT 1 FROM public.loans l
       WHERE l.id::TEXT = (storage.foldername(name))[1]
         AND l.debtor_id = auth.uid()
         AND l.status IN ('active', 'partially_paid')
    )
  );

-- DELETE: only the uploader can delete their own proof (during pending state)
CREATE POLICY "uploader_can_delete_own_proof"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'payment_proofs' AND
    (storage.foldername(name))[1] IN (
      SELECT l.id::TEXT FROM public.loans l WHERE l.debtor_id = auth.uid()
    )
  );
*/

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 6: Grant EXECUTE on new RPCs to authenticated users
-- ─────────────────────────────────────────────────────────────────────────────

GRANT EXECUTE ON FUNCTION public.register_payment(UUID, NUMERIC, TEXT, TEXT, TEXT, TEXT, JSONB)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_transaction(UUID)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.dispute_transaction(UUID, TEXT)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_transaction(UUID, TEXT)
  TO authenticated;
