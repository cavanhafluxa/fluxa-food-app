// Supabase Edge Function — Stripe Webhook Handler
// Deploy: supabase functions deploy stripe-webhook
// Configurar secret: supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_xxx
//
// Eventos tratados:
//   invoice.payment_succeeded  → marca fatura como paga, atualiza stripe_status = 'active'
//   invoice.payment_failed     → atualiza stripe_status = 'past_due'
//   customer.subscription.updated → atualiza plano/preço/próxima cobrança

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const STRIPE_WEBHOOK_SECRET = Deno.env.get('STRIPE_WEBHOOK_SECRET') ?? ''
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

// Verifica assinatura HMAC-SHA256 do Stripe
async function verifyStripeSignature(payload: string, sigHeader: string, secret: string): Promise<boolean> {
  const parts = sigHeader.split(',')
  const ts = parts.find(p => p.startsWith('t='))?.split('=')[1]
  const v1 = parts.find(p => p.startsWith('v1='))?.split('=')[1]
  if (!ts || !v1) return false

  const signed = `${ts}.${payload}`
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']
  )
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(signed))
  const computed = Array.from(new Uint8Array(sig)).map(b => b.toString(16).padStart(2, '0')).join('')
  return computed === v1
}

serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 })

  const body = await req.text()
  const sigHeader = req.headers.get('stripe-signature') ?? ''

  // Verificar assinatura em produção
  if (STRIPE_WEBHOOK_SECRET) {
    const valid = await verifyStripeSignature(body, sigHeader, STRIPE_WEBHOOK_SECRET)
    if (!valid) return new Response('Invalid signature', { status: 400 })
  }

  const event = JSON.parse(body)
  const db = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

  try {
    switch (event.type) {

      case 'invoice.payment_succeeded': {
        const inv = event.data.object
        const customerId = inv.customer
        const periodStart = inv.period_start ? new Date(inv.period_start * 1000).toISOString() : null
        const periodEnd = inv.period_end ? new Date(inv.period_end * 1000).toISOString() : null

        // Busca empresa pelo stripe_customer_id
        const { data: company } = await db
          .from('food_companies')
          .select('id')
          .eq('stripe_customer_id', customerId)
          .single()

        if (company) {
          // Upsert invoice em food_stripe_invoices
          await db.from('food_stripe_invoices').upsert({
            company_id: company.id,
            stripe_invoice_id: inv.id,
            amount: (inv.amount_paid ?? 0) / 100,
            status: 'paid',
            period_start: periodStart,
            period_end: periodEnd,
            invoice_pdf: inv.invoice_pdf ?? null,
            updated_at: new Date().toISOString()
          }, { onConflict: 'stripe_invoice_id' })

          // Atualiza status da empresa para ativo
          await db.from('food_companies').update({
            stripe_status: 'active',
            inadimplente: false,
            inadimplente_motivo: null,
            stripe_next_billing: periodEnd
          }).eq('id', company.id)
        }
        break
      }

      case 'invoice.payment_failed': {
        const inv = event.data.object
        const customerId = inv.customer

        const { data: company } = await db
          .from('food_companies')
          .select('id')
          .eq('stripe_customer_id', customerId)
          .single()

        if (company) {
          await db.from('food_stripe_invoices').upsert({
            company_id: company.id,
            stripe_invoice_id: inv.id,
            amount: (inv.amount_due ?? 0) / 100,
            status: 'pending',
            invoice_pdf: inv.invoice_pdf ?? null,
            updated_at: new Date().toISOString()
          }, { onConflict: 'stripe_invoice_id' })

          await db.from('food_companies').update({
            stripe_status: 'past_due',
            inadimplente: true,
            inadimplente_motivo: 'Pagamento da fatura falhou. Atualize seu método de pagamento.'
          }).eq('id', company.id)
        }
        break
      }

      case 'customer.subscription.updated': {
        const sub = event.data.object
        const customerId = sub.customer
        const planId = sub.items?.data?.[0]?.price?.lookup_key ?? null
        const priceMonthly = sub.items?.data?.[0]?.price?.unit_amount
          ? sub.items.data[0].price.unit_amount / 100
          : null
        const nextBilling = sub.current_period_end
          ? new Date(sub.current_period_end * 1000).toISOString()
          : null

        const { data: company } = await db
          .from('food_companies')
          .select('id')
          .eq('stripe_customer_id', customerId)
          .single()

        if (company) {
          const updatePayload: Record<string, unknown> = {
            stripe_status: sub.status,
            stripe_next_billing: nextBilling
          }
          if (planId) updatePayload.stripe_plan = planId
          if (priceMonthly) updatePayload.stripe_price_monthly = priceMonthly

          await db.from('food_companies').update(updatePayload).eq('id', company.id)
        }
        break
      }

      case 'customer.subscription.deleted': {
        const sub = event.data.object
        const { data: company } = await db
          .from('food_companies')
          .select('id')
          .eq('stripe_customer_id', sub.customer)
          .single()
        if (company) {
          await db.from('food_companies').update({ stripe_status: 'canceled' }).eq('id', company.id)
        }
        break
      }
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { 'Content-Type': 'application/json' }
    })
  } catch (err) {
    console.error('[stripe-webhook]', err)
    return new Response('Internal Error', { status: 500 })
  }
})
