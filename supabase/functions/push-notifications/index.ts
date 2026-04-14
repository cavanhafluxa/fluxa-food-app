// Supabase Edge Function — Web Push Notifications
// Deploy: supabase functions deploy push-notifications
// Configurar secrets:
//   supabase secrets set VAPID_PRIVATE_KEY=L5C1ldh7HEGu1ByAZuThW4RDuWrPl20BMd93qb0sAN4
//   supabase secrets set VAPID_SUBJECT=mailto:suporte@fluxa.app
//
// Trigger: Database Webhook no INSERT de food_orders
//   URL: https://<project>.supabase.co/functions/v1/push-notifications

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const VAPID_PUBLIC_KEY = 'BO0MNhPJHveGMcaT8aIzVM_3gnFrr4fhN5whwRfq4YNNEe98_wri2OFqD7AwYa4Q969Ihq1rYNvZmmYjhvCFVj0'
const VAPID_PRIVATE_KEY = Deno.env.get('VAPID_PRIVATE_KEY') ?? ''
const VAPID_SUBJECT = Deno.env.get('VAPID_SUBJECT') ?? 'mailto:suporte@fluxa.app'
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

// Converte base64url para Uint8Array
function b64uToUint8(b64u: string): Uint8Array {
  const pad = '='.repeat((4 - b64u.length % 4) % 4)
  const b64 = (b64u + pad).replace(/-/g, '+').replace(/_/g, '/')
  const raw = atob(b64)
  return Uint8Array.from([...raw].map(c => c.charCodeAt(0)))
}

// Gera JWT VAPID para autenticação de push
async function generateVAPIDJWT(audience: string): Promise<string> {
  const header = { typ: 'JWT', alg: 'ES256' }
  const payload = {
    aud: audience,
    exp: Math.floor(Date.now() / 1000) + 12 * 3600,
    sub: VAPID_SUBJECT
  }
  const encode = (obj: object) => btoa(JSON.stringify(obj)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
  const unsigned = `${encode(header)}.${encode(payload)}`

  const privKey = await crypto.subtle.importKey(
    'raw', b64uToUint8(VAPID_PRIVATE_KEY),
    { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']
  )
  const sig = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' }, privKey, new TextEncoder().encode(unsigned)
  )
  const sigB64u = btoa(String.fromCharCode(...new Uint8Array(sig))).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
  return `${unsigned}.${sigB64u}`
}

// Envia push para uma subscription
async function sendPush(subscription: { endpoint: string; p256dh: string; auth: string }, payload: string): Promise<boolean> {
  try {
    const url = new URL(subscription.endpoint)
    const audience = `${url.protocol}//${url.host}`
    const jwt = await generateVAPIDJWT(audience)

    const res = await fetch(subscription.endpoint, {
      method: 'POST',
      headers: {
        'Authorization': `vapid t=${jwt},k=${VAPID_PUBLIC_KEY}`,
        'Content-Type': 'application/octet-stream',
        'Content-Encoding': 'aes128gcm',
        'TTL': '86400'
      },
      body: new TextEncoder().encode(payload)
    })
    return res.status < 300
  } catch (e) {
    console.error('[push] Erro ao enviar:', e)
    return false
  }
}

serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 })

  let body: { record?: { company_id?: string; order_number?: string; cliente_nome?: string }; company_id?: string; title?: string; message?: string }
  try { body = await req.json() } catch { return new Response('Bad Request', { status: 400 }) }

  // Suporte a Database Webhook (record direto) ou chamada manual
  const company_id = body.record?.company_id ?? body.company_id
  if (!company_id) return new Response('company_id required', { status: 400 })

  const title = body.title ?? 'Flüxa Kitchen'
  const message = body.message ?? (body.record
    ? `Novo pedido #${body.record.order_number} de ${body.record.cliente_nome}!`
    : 'Novo pedido recebido!')

  const db = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

  // Busca todas as subscriptions ativas para o restaurante
  const { data: subs } = await db
    .from('food_push_subscriptions')
    .select('endpoint, p256dh, auth')
    .eq('company_id', company_id)

  if (!subs?.length) {
    return new Response(JSON.stringify({ sent: 0 }), { headers: { 'Content-Type': 'application/json' } })
  }

  const pushPayload = JSON.stringify({ title, body: message, icon: '/icon-192.png' })
  let sent = 0
  await Promise.all(subs.map(async (sub) => {
    const ok = await sendPush(sub, pushPayload)
    if (ok) sent++
  }))

  return new Response(JSON.stringify({ sent, total: subs.length }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
