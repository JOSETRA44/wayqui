-- =============================================================================
-- MIGRATION: Iteration 2 — Payment Lifecycle v2
-- Project: Wayqui (qiuhgklbnydxjmtijjke)
-- Created: 2026-03-05
--
-- SECTION 1: Extend loan_transactions
-- SECTION 2: Trigger function (handle_transaction_status_change)
-- SECTION 3: RPCs (register_payment, confirm_transaction, dispute_transaction, reject_transaction)
-- SECTION 4: RLS policies on loan_transactions
-- SECTION 5: Grants
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 1: Extend loan_transactions
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.loan_transactions
  ADD COLUMN IF NOT EXISTS operation_id      TEXT,
  ADD COLUMN IF NOT EXISTS evidence_path     TEXT,
  ADD COLUMN IF NOT EXISTS payment_metadata  JSONB,
  ADD COLUMN IF NOT EXISTS disputed_at       TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS dispute_reason    TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS loan_transactions_operation_id_uidx
  ON public.loan_transactions (operation_id)
  WHERE operation_id IS NOT NULL;

ALTER TABLE public.loan_transactions
  DROP CONSTRAINT IF EXISTS loan_transactions_status_check;
ALTER TABLE public.loan_transactions
  ADD CONSTRAINT loan_transactions_status_check
  CHECK (status IN ('pending', 'confirmed', 'rejected', 'disputed'));

ALTER TABLE public.loans
  DROP CONSTRAINT IF EXISTS loans_status_check;
ALTER TABLE public.loans
  ADD CONSTRAINT loans_status_check
  CHECK (status IN ('active', 'partially_paid', 'paid', 'cancelled', 'disputed'));

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 2: Trigger function
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.handle_transaction_status_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_loan            public.loans%ROWTYPE;
  v_new_remaining   NUMERIC(12,2);
  v_new_loan_status TEXT;
BEGIN
  IF NEW.status = 'confirmed' AND OLD.status = 'pending' THEN
    NEW.confirmed_at := now();
    NEW.confirmed_by := auth.uid();
    SELECT * INTO v_loan FROM public.loans WHERE id = NEW.loan_id FOR UPDATE;
    v_new_remaining   := GREATEST(0, v_loan.remaining_amount - NEW.amount);
    v_new_loan_status := CASE WHEN v_new_remaining = 0 THEN 'paid' ELSE 'partially_paid' END;
    UPDATE public.loans SET remaining_amount = v_new_remaining, status = v_new_loan_status, updated_at = now() WHERE id = NEW.loan_id;
    UPDATE public.profiles SET total_owed = GREATEST(0, total_owed - NEW.amount), balance_updated_at = now() WHERE id = v_loan.creditor_id;
    IF v_loan.debtor_id IS NOT NULL THEN
      UPDATE public.profiles SET total_debt = GREATEST(0, total_debt - NEW.amount), balance_updated_at = now() WHERE id = v_loan.debtor_id;
    END IF;
  ELSIF NEW.status = 'rejected' AND OLD.status = 'pending' THEN
    NEW.rejected_at := now();
  ELSIF NEW.status = 'disputed' AND OLD.status IN ('pending', 'confirmed') THEN
    NEW.disputed_at := now();
    IF OLD.status = 'confirmed' THEN
      SELECT * INTO v_loan FROM public.loans WHERE id = NEW.loan_id FOR UPDATE;
      UPDATE public.loans
         SET remaining_amount = LEAST(v_loan.amount, v_loan.remaining_amount + NEW.amount),
             status           = CASE WHEN v_loan.remaining_amount + NEW.amount >= v_loan.amount THEN 'active' ELSE 'partially_paid' END,
             updated_at = now()
       WHERE id = NEW.loan_id;
      UPDATE public.profiles SET total_owed = total_owed + NEW.amount, balance_updated_at = now() WHERE id = v_loan.creditor_id;
      IF v_loan.debtor_id IS NOT NULL THEN
        UPDATE public.profiles SET total_debt = total_debt + NEW.amount, balance_updated_at = now() WHERE id = v_loan.debtor_id;
      END IF;
    END IF;
    UPDATE public.loans SET status = 'disputed', updated_at = now() WHERE id = NEW.loan_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_transaction_status_change ON public.loan_transactions;
CREATE TRIGGER trg_transaction_status_change
  BEFORE UPDATE OF status ON public.loan_transactions
  FOR EACH ROW EXECUTE FUNCTION public.handle_transaction_status_change();

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 3: RPCs
-- ─────────────────────────────────────────────────────────────────────────────

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
  SELECT * INTO v_loan FROM public.loans WHERE id = p_loan_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Préstamo no encontrado'; END IF;
  IF v_loan.debtor_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Solo el deudor puede registrar pagos'; END IF;
  IF v_loan.status NOT IN ('active', 'partially_paid') THEN RAISE EXCEPTION 'El préstamo no está activo (estado: %)', v_loan.status; END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'El monto debe ser mayor a cero'; END IF;
  IF p_amount > v_loan.remaining_amount THEN RAISE EXCEPTION 'El monto (%) supera el saldo pendiente (%)', p_amount, v_loan.remaining_amount; END IF;
  v_cksum := encode(sha256((auth.uid()::TEXT || p_loan_id::TEXT || p_amount::TEXT || now()::TEXT)::BYTEA), 'hex');
  INSERT INTO public.loan_transactions (
    loan_id, payer_id, amount, payment_method,
    status, notes, operation_id, evidence_path,
    payment_metadata, checksum
  ) VALUES (
    p_loan_id, auth.uid(), p_amount, p_payment_method,
    'pending', p_notes, p_operation_id, p_evidence_path,
    p_payment_metadata, v_cksum
  ) RETURNING id INTO v_txn_id;
  IF p_evidence_path IS NOT NULL THEN
    INSERT INTO public.payment_proofs (transaction_id, uploaded_by, storage_path)
    VALUES (v_txn_id, auth.uid(), p_evidence_path);
  END IF;
  RETURN json_build_object('success', true, 'transaction_id', v_txn_id, 'checksum', v_cksum);
END;
$$;

CREATE OR REPLACE FUNCTION public.confirm_transaction(p_transaction_id UUID)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_txn  public.loan_transactions%ROWTYPE;
  v_loan public.loans%ROWTYPE;
BEGIN
  SELECT * INTO v_txn FROM public.loan_transactions WHERE id = p_transaction_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Transacción no encontrada'; END IF;
  SELECT * INTO v_loan FROM public.loans WHERE id = v_txn.loan_id;
  IF v_loan.creditor_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Solo el acreedor puede confirmar esta transacción'; END IF;
  IF v_txn.status <> 'pending' THEN RAISE EXCEPTION 'La transacción no está pendiente (estado: %)', v_txn.status; END IF;
  UPDATE public.loan_transactions SET status = 'confirmed' WHERE id = p_transaction_id;
  RETURN json_build_object('success', true, 'transaction_id', p_transaction_id);
END;
$$;

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
  IF NOT FOUND THEN RAISE EXCEPTION 'Transacción no encontrada'; END IF;
  SELECT * INTO v_loan FROM public.loans WHERE id = v_txn.loan_id;
  IF v_loan.creditor_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Solo el acreedor puede disputar esta transacción'; END IF;
  IF v_txn.status NOT IN ('pending', 'confirmed') THEN RAISE EXCEPTION 'No se puede disputar en estado: %', v_txn.status; END IF;
  UPDATE public.loan_transactions SET status = 'disputed', dispute_reason = p_reason WHERE id = p_transaction_id;
  RETURN json_build_object('success', true, 'transaction_id', p_transaction_id);
END;
$$;

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
  IF NOT FOUND THEN RAISE EXCEPTION 'Transacción no encontrada'; END IF;
  SELECT * INTO v_loan FROM public.loans WHERE id = v_txn.loan_id;
  IF v_loan.creditor_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Solo el acreedor puede rechazar esta transacción'; END IF;
  IF v_txn.status <> 'pending' THEN RAISE EXCEPTION 'Solo se pueden rechazar transacciones pendientes (estado: %)', v_txn.status; END IF;
  UPDATE public.loan_transactions SET status = 'rejected', rejection_reason = p_reason WHERE id = p_transaction_id;
  RETURN json_build_object('success', true, 'transaction_id', p_transaction_id);
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 4: RLS policies on loan_transactions
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.loan_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "loan_parties_select_transactions" ON public.loan_transactions;
DROP POLICY IF EXISTS "debtor_insert_transaction"        ON public.loan_transactions;
DROP POLICY IF EXISTS "creditor_update_transaction"      ON public.loan_transactions;

CREATE POLICY "loan_parties_select_transactions"
  ON public.loan_transactions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.loans l
       WHERE l.id = loan_id
         AND (l.creditor_id = auth.uid() OR l.debtor_id = auth.uid())
    )
  );

CREATE POLICY "debtor_insert_transaction"
  ON public.loan_transactions FOR INSERT
  WITH CHECK (
    payer_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM public.loans l
       WHERE l.id = loan_id
         AND l.debtor_id = auth.uid()
         AND l.status IN ('active', 'partially_paid')
    )
  );

CREATE POLICY "creditor_update_transaction"
  ON public.loan_transactions FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.loans l
       WHERE l.id = loan_id AND l.creditor_id = auth.uid()
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 5: Grants
-- ─────────────────────────────────────────────────────────────────────────────

GRANT EXECUTE ON FUNCTION public.register_payment(UUID, NUMERIC, TEXT, TEXT, TEXT, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_transaction(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.dispute_transaction(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_transaction(UUID, TEXT) TO authenticated;
