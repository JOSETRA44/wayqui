-- =============================================================================
-- MIGRATION: Notifications System
-- Project: Wayqui (qiuhgklbnydxjmtijjke)
-- Created: 2026-03-06
--
-- APPLY: Run in Supabase Dashboard → SQL Editor.
-- All statements are idempotent (IF NOT EXISTS / CREATE OR REPLACE).
-- =============================================================================


-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 1: notification_type enum
-- ─────────────────────────────────────────────────────────────────────────────

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_type') THEN
    CREATE TYPE public.notification_type AS ENUM (
      'payment_registered',
      'payment_confirmed',
      'payment_rejected',
      'payment_disputed',
      'payment_requested'
    );
  END IF;
END
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 2: notifications table
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.notifications (
  id             UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID              NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title          TEXT              NOT NULL,
  body           TEXT              NOT NULL,
  type           public.notification_type NOT NULL,
  loan_id        UUID              REFERENCES public.loans(id) ON DELETE SET NULL,
  transaction_id UUID              REFERENCES public.loan_transactions(id) ON DELETE SET NULL,
  is_read        BOOLEAN           NOT NULL DEFAULT FALSE,
  created_at     TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON public.notifications (user_id, is_read, created_at DESC);


-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 3: Row Level Security
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Read own notifications
DROP POLICY IF EXISTS "users_read_own_notifications" ON public.notifications;
CREATE POLICY "users_read_own_notifications" ON public.notifications
  FOR SELECT
  USING (auth.uid() = user_id);

-- Update own notifications (mark as read)
DROP POLICY IF EXISTS "users_update_own_notifications" ON public.notifications;
CREATE POLICY "users_update_own_notifications" ON public.notifications
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- SECURITY DEFINER functions insert on behalf of any user
DROP POLICY IF EXISTS "service_insert_notifications" ON public.notifications;
CREATE POLICY "service_insert_notifications" ON public.notifications
  FOR INSERT
  WITH CHECK (true);   -- restricted by SECURITY DEFINER functions calling INSERT


-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 4: Enable Realtime
-- ─────────────────────────────────────────────────────────────────────────────

-- Adds the table to the default Supabase realtime publication.
-- Safe to run multiple times (publication member check done by Supabase).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
     WHERE pubname   = 'supabase_realtime'
       AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 5: trigger — auto-notify on loan_transaction changes
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.notify_on_transaction()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_loan          public.loans%ROWTYPE;
  v_creditor_name TEXT;
  v_debtor_name   TEXT;
  v_amount_text   TEXT;
BEGIN
  SELECT * INTO v_loan FROM public.loans WHERE id = NEW.loan_id;
  IF NOT FOUND THEN RETURN NEW; END IF;

  SELECT COALESCE(full_name, 'Tu acreedor') INTO v_creditor_name
    FROM public.profiles WHERE id = v_loan.creditor_id;

  SELECT COALESCE(full_name, v_loan.debtor_name, 'Tu deudor') INTO v_debtor_name
    FROM public.profiles WHERE id = v_loan.debtor_id;

  v_amount_text := 'S/. ' || to_char(NEW.amount, 'FM99999990.00');

  IF TG_OP = 'INSERT' THEN
    -- Debtor registered a payment → notify creditor
    IF v_loan.creditor_id IS NOT NULL AND v_loan.creditor_id != NEW.payer_id THEN
      INSERT INTO public.notifications
        (user_id, title, body, type, loan_id, transaction_id)
      VALUES (
        v_loan.creditor_id,
        'Pago registrado',
        COALESCE(v_debtor_name, 'Tu deudor') || ' registró un pago de ' || v_amount_text ||
          '. Revísalo para confirmarlo.',
        'payment_registered',
        NEW.loan_id,
        NEW.id
      );
    END IF;

  ELSIF TG_OP = 'UPDATE' THEN

    IF NEW.status = 'confirmed' AND OLD.status != 'confirmed' THEN
      -- Notify debtor: payment was confirmed
      IF v_loan.debtor_id IS NOT NULL THEN
        INSERT INTO public.notifications
          (user_id, title, body, type, loan_id, transaction_id)
        VALUES (
          v_loan.debtor_id,
          '¡Pago confirmado!',
          v_creditor_name || ' confirmó tu pago de ' || v_amount_text || '. ¡Gracias!',
          'payment_confirmed',
          NEW.loan_id,
          NEW.id
        );
      END IF;

    ELSIF NEW.status = 'rejected' AND OLD.status != 'rejected' THEN
      -- Notify debtor: payment was rejected
      IF v_loan.debtor_id IS NOT NULL THEN
        INSERT INTO public.notifications
          (user_id, title, body, type, loan_id, transaction_id)
        VALUES (
          v_loan.debtor_id,
          'Pago rechazado',
          v_creditor_name || ' rechazó tu pago de ' || v_amount_text ||
            COALESCE('. Motivo: ' || NEW.rejection_reason, ''),
          'payment_rejected',
          NEW.loan_id,
          NEW.id
        );
      END IF;

    ELSIF NEW.status = 'disputed' AND OLD.status != 'disputed' THEN
      -- Notify debtor: payment is disputed
      IF v_loan.debtor_id IS NOT NULL THEN
        INSERT INTO public.notifications
          (user_id, title, body, type, loan_id, transaction_id)
        VALUES (
          v_loan.debtor_id,
          'Pago en disputa',
          'El pago de ' || v_amount_text || ' está siendo disputado' ||
            COALESCE('. Motivo: ' || NEW.dispute_reason, '') || '.',
          'payment_disputed',
          NEW.loan_id,
          NEW.id
        );
      END IF;

    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_transaction ON public.loan_transactions;
CREATE TRIGGER trg_notify_on_transaction
  AFTER INSERT OR UPDATE OF status ON public.loan_transactions
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_transaction();


-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 6: RPC — request_payment (creditor solicita pago al deudor)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.request_payment(p_loan_id UUID)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_loan          public.loans%ROWTYPE;
  v_creditor_name TEXT;
  v_notif_id      UUID;
BEGIN
  SELECT * INTO v_loan FROM public.loans WHERE id = p_loan_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Préstamo no encontrado';
  END IF;

  IF v_loan.creditor_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Solo el acreedor puede solicitar pagos';
  END IF;

  IF v_loan.status NOT IN ('active', 'partially_paid') THEN
    RAISE EXCEPTION 'El préstamo no está activo (estado: %)', v_loan.status;
  END IF;

  IF v_loan.debtor_id IS NULL THEN
    RAISE EXCEPTION 'El deudor no tiene cuenta en Wayqui; usa WhatsApp';
  END IF;

  SELECT COALESCE(full_name, 'Tu acreedor') INTO v_creditor_name
    FROM public.profiles WHERE id = auth.uid();

  INSERT INTO public.notifications
    (user_id, title, body, type, loan_id)
  VALUES (
    v_loan.debtor_id,
    'Solicitud de pago',
    v_creditor_name || ' te solicita registrar tu pago de S/. ' ||
      to_char(v_loan.remaining_amount, 'FM99999990.00') ||
      ' para "' || v_loan.description || '".',
    'payment_requested',
    p_loan_id
  )
  RETURNING id INTO v_notif_id;

  RETURN json_build_object(
    'success',         true,
    'notification_id', v_notif_id
  );
END;
$$;
