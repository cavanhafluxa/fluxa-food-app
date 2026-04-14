-- ============================================================
-- Flüxa Kitchen — Etapa 1 & 2 Migrations
-- Data: 2026-04-14
-- ============================================================

-- ── food_push_subscriptions ──────────────────────────────────
-- Armazena subscriptions Web Push por staff para notificações
-- server-side quando a aba está fechada.
CREATE TABLE IF NOT EXISTS public.food_push_subscriptions (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  company_id  uuid NOT NULL REFERENCES public.food_companies(id) ON DELETE CASCADE,
  staff_id    uuid NOT NULL REFERENCES public.food_staff(id) ON DELETE CASCADE,
  endpoint    text NOT NULL,
  p256dh      text NOT NULL,
  auth        text NOT NULL,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now(),
  UNIQUE (staff_id)
);

-- RLS: staff só vê as próprias subscriptions; service_role vê tudo (Edge Function)
ALTER TABLE public.food_push_subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "staff_own_push" ON public.food_push_subscriptions
  FOR ALL TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- ── food_companies: campos adicionais Etapa 1 & 2 ────────────
-- n8n_webhook: webhook dedicado por restaurante (não compartilhado)
ALTER TABLE public.food_companies
  ADD COLUMN IF NOT EXISTS n8n_webhook text;

-- stripe_customer_id: vínculo com cliente no Stripe (usado pelo webhook)
ALTER TABLE public.food_companies
  ADD COLUMN IF NOT EXISTS stripe_customer_id text;

-- ── food_commission_log: garantir commission_value ────────────
-- Adiciona coluna caso não exista; gerada como order_total * commission_pct / 100
ALTER TABLE public.food_commission_log
  ADD COLUMN IF NOT EXISTS commission_value numeric(10,2);

-- Backfill: calcula commission_value para registros existentes sem o campo
UPDATE public.food_commission_log
SET commission_value = ROUND((order_total * commission_pct / 100)::numeric, 2)
WHERE commission_value IS NULL;

-- ── food_stripe_invoices: campo stripe_invoice_id para upsert ─
ALTER TABLE public.food_stripe_invoices
  ADD COLUMN IF NOT EXISTS stripe_invoice_id text;

CREATE UNIQUE INDEX IF NOT EXISTS food_stripe_invoices_stripe_id
  ON public.food_stripe_invoices (stripe_invoice_id)
  WHERE stripe_invoice_id IS NOT NULL;
