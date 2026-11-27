/**
 * Potfolio API — Cloudflare Worker (free plan friendly).
 *
 *  GET  /stocks?market=US|NG|EU|UK|KE   stock lists (+ live prices where available)
 *  GET  /history?symbol=&market=        daily closes (needs TWELVE_DATA_KEY)
 *  GET  /logo?u=<image url>              logo proxy with CORS, so Flutter web can draw it
 *  POST /share               (auth)      save a public read-only pot snapshot, returns { id }
 *  GET  /share/:id                       read a shared pot snapshot
 *  POST /guardian                        AI allocation via Workers AI, validated
 *  POST /checkout/sessions   (auth)      create a Light checkout session (signed)
 *  GET  /checkout/view/:secret           proxy Light public checkout view
 *  POST /checkout/pay/:secret            proxy Light public checkout pay
 *  POST /webhooks/light                  credit balances on checkout_session.completed
 *  GET  /balance             (auth)      USDC credited to the signed-in user
 *  GET  /trade/quote                     0x quote to buy/sell a tokenized stock with USDC (Base mainnet)
 *  POST /gas/topup           (auth)      tiny ETH top-up so USDC-only wallets can pay network fees
 */
import { verifyFirebaseToken } from './auth';
import { lightFetch, lightPublic } from './light';
import { getStocks, getHistory } from './stocks';
import { runGuardian } from './guardian';
import { tradeQuote, gasTopup, TradeError, type TradeEnv } from './trade';

export interface Env extends TradeEnv {
  AI: Ai;
  KV: KVNamespace;
  FIREBASE_PROJECT_ID: string;
  LIGHT_BASE_URL: string; // https://sandbox.sendlight.xyz or https://live.sendlight.xyz
  LIGHT_API_KEY: string; // secret: lk_test_… / lk_live_…
  LIGHT_SIGNING_KEY: string; // secret: Ed25519 private key, PEM (PKCS#8)
  TWELVE_DATA_KEY?: string; // optional secret for non-US prices and charts
  ALLOWED_ORIGINS?: string; // comma separated, '*' by default
}

const json = (data: unknown, status = 200, extra: HeadersInit = {}) =>
  new Response(JSON.stringify(data), { status, headers: { 'content-type': 'application/json', ...extra } });

function cors(req: Request, env: Env): Record<string, string> {
  const origin = req.headers.get('origin') ?? '*';
  const allowed = (env.ALLOWED_ORIGINS ?? '*').split(',').map((s) => s.trim());
  const ok = allowed.includes('*') || allowed.includes(origin);
  return {
    'access-control-allow-origin': ok ? origin : allowed[0],
    'access-control-allow-methods': 'GET,POST,OPTIONS',
    'access-control-allow-headers': 'content-type,authorization',
    'access-control-max-age': '86400',
    vary: 'origin',
  };
}

async function requireUser(req: Request, env: Env): Promise<string> {
  const h = req.headers.get('authorization') ?? '';
  const token = h.startsWith('Bearer ') ? h.slice(7) : '';
  if (!token) throw new HttpError(401, 'Sign in required');
  try {
    return await verifyFirebaseToken(token, env.FIREBASE_PROJECT_ID);
  } catch {
    throw new HttpError(401, 'Invalid session');
  }
}

const LOGO_HOSTS = ['api.coinbase.com', 'www.google.com', 'icons.duckduckgo.com'];

/** Fetches a company logo server-side and returns it with CORS headers, cached for a week.
 *  Only a few known image hosts are allowed, so this can't be used as an open proxy. */
async function proxyLogo(target: string, ctx: ExecutionContext): Promise<Response> {
  let u: URL;
  try {
    u = new URL(target);
  } catch {
    throw new HttpError(400, 'Bad logo url');
  }
  if (u.protocol !== 'https:' || !LOGO_HOSTS.includes(u.hostname)) throw new HttpError(400, 'Logo host not allowed');
  const cache = caches.default;
  const key = new Request(`https://cache.potfolio/logo/${encodeURIComponent(u.toString())}`);
  const hit = await cache.match(key);
  if (hit) return new Response(hit.body, hit);
  let r = await fetch(u.toString(), { headers: { accept: 'image/*,application/json' }, cf: { cacheTtl: 604800 } } as RequestInit);
  let type = r.headers.get('content-type') ?? '';
  if (r.ok && type.includes('json')) {
    // Some image endpoints answer with JSON that points at the real file.
    const j: any = await r.json().catch(() => ({}));
    const next = j?.url ?? j?.image_url ?? j?.data?.url ?? j?.data?.image_url;
    if (typeof next !== 'string' || !next.startsWith('https://')) throw new HttpError(404, 'Logo not found');
    r = await fetch(next, { headers: { accept: 'image/*' }, cf: { cacheTtl: 604800 } } as RequestInit);
    type = r.headers.get('content-type') ?? '';
  }
  if (!r.ok || !type.startsWith('image/')) throw new HttpError(404, 'Logo not found');
  const buf = await r.arrayBuffer();
  const out = new Response(buf, { headers: { 'content-type': type, 'cache-control': 'public, max-age=2592000, immutable' } });
  ctx.waitUntil(cache.put(key, out.clone()));
  return out;
}

/** Short, unguessable id for share links. */
function shareId(): string {
  const a = 'abcdefghijkmnopqrstuvwxyz23456789';
  const b = crypto.getRandomValues(new Uint8Array(10));
  return [...b].map((x) => a[x % a.length]).join('');
}

/** Keep only the fields the public page shows, with sane limits. Amounts only when the owner chose to show them. */
function cleanShare(b: any) {
  const str = (v: unknown, n: number) => (typeof v === 'string' ? v.slice(0, n) : undefined);
  const num = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) ? Math.round(v * 100) / 100 : undefined);
  const show = b?.showAmounts === true;
  const allocations = (Array.isArray(b?.allocations) ? b.allocations : []).slice(0, 10).map((a: any) => ({
    symbol: str(a?.symbol, 12) ?? '',
    name: str(a?.name, 60) ?? '',
    weight: Math.max(0, Math.min(100, Math.round(Number(a?.weight) || 0))),
    logo: typeof a?.logo === 'string' && a.logo.startsWith('https://') ? a.logo.slice(0, 500) : undefined,
  }));
  const progress = num(b?.progress);
  return {
    name: str(b?.name, 60) ?? 'My pot',
    goal: str(b?.goal, 30),
    template: str(b?.template, 20),
    frequency: b?.frequency === 'weekly' ? 'weekly' : b?.frequency === 'monthly' ? 'monthly' : undefined,
    targetDate: str(b?.targetDate, 40),
    createdAt: str(b?.createdAt, 40),
    progress: progress === undefined ? undefined : Math.max(0, Math.min(1, progress)),
    reached: b?.reached === true,
    showAmounts: show,
    target: show ? num(b?.target) : undefined,
    invested: show ? num(b?.invested) : undefined,
    perPeriod: show ? num(b?.perPeriod) : undefined,
    value: show ? num(b?.value) : undefined,
    allocations,
  };
}

class HttpError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

export default {
  async fetch(req: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const c = cors(req, env);
    if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: c });
    const url = new URL(req.url);
    const p = url.pathname;
    try {
      let res: Response;
      if (req.method === 'GET' && p === '/stocks') {
        res = json({ stocks: await getStocks((url.searchParams.get('market') ?? 'US').toUpperCase(), env, ctx) });
      } else if (req.method === 'GET' && p === '/history') {
        res = json(await getHistory(url.searchParams.get('symbol') ?? '', (url.searchParams.get('market') ?? 'US').toUpperCase(), env), 200, { 'cache-control': 'public, max-age=900' });
      } else if (req.method === 'GET' && p === '/logo') {
        res = await proxyLogo(url.searchParams.get('u') ?? '', ctx);
      } else if (req.method === 'POST' && p === '/share') {
        const uid = await requireUser(req, env);
        const snap = cleanShare(await req.json());
        const id = shareId();
        await env.KV.put(`share:${id}`, JSON.stringify({ ...snap, owner: uid, sharedAt: new Date().toISOString() }), { expirationTtl: 60 * 60 * 24 * 180 });
        res = json({ id });
      } else if (req.method === 'GET' && p.startsWith('/share/')) {
        const id = p.split('/').pop() ?? '';
        const raw = /^[a-z0-9]{6,16}$/.test(id) ? await env.KV.get(`share:${id}`) : null;
        if (!raw) throw new HttpError(404, 'This pot isn’t shared any more.');
        const { owner, ...pub } = JSON.parse(raw);
        res = json(pub, 200, { 'cache-control': 'public, max-age=60' });
      } else if (req.method === 'POST' && p === '/guardian') {
        res = json(await runGuardian(await req.json(), env));
      } else if (req.method === 'POST' && p === '/checkout/sessions') {
        const uid = await requireUser(req, env);
        const { amountUsd } = (await req.json()) as { amountUsd: number };
        if (!(amountUsd >= 1 && amountUsd <= 10000)) throw new HttpError(400, 'Amount must be between $1 and $10,000');
        // Short, unique reference (Light requires it unique per checkout); the uid is kept in KV.
        const reference = `pf_${crypto.randomUUID().replace(/-/g, '')}`;
        const session = (await lightFetch(env, 'POST', '/v1/checkout_sessions', {
          receive: { currency: 'USDC', amount: String(Math.round(amountUsd * 1e6)) },
          reference,
        })) as { id: string; client_secret: string };
        await env.KV.put(`session:${session.id}`, JSON.stringify({ uid, amountUsd, reference }), { expirationTtl: 60 * 60 * 24 * 30 });
        await env.KV.put(`ref:${reference}`, uid, { expirationTtl: 60 * 60 * 24 * 30 });
        res = json({ id: session.id, clientSecret: session.client_secret });
      } else if (req.method === 'GET' && p.startsWith('/checkout/view/')) {
        res = json(await lightPublic(env, 'GET', `/v1/checkout/${encodeURIComponent(p.split('/').pop()!)}`));
      } else if (req.method === 'POST' && p.startsWith('/checkout/pay/')) {
        res = json(await lightPublic(env, 'POST', `/v1/checkout/${encodeURIComponent(p.split('/').pop()!)}/pay`, await req.json()));
      } else if (req.method === 'POST' && p === '/webhooks/light') {
        ctx.waitUntil(handleWebhook(await req.json(), env));
        res = json({ received: true });
      } else if (req.method === 'GET' && p === '/balance') {
        const uid = await requireUser(req, env);
        const micro = Number((await env.KV.get(`bal:${uid}`)) ?? '0');
        res = json({ usdc: micro / 1e6 });
      } else if (req.method === 'GET' && p === '/trade/quote') {
        res = json(await tradeQuote(url, env), 200, { 'cache-control': 'no-store' });
      } else if (req.method === 'POST' && p === '/gas/topup') {
        const uid = await requireUser(req, env);
        res = json(await gasTopup(uid, await req.json(), env));
      } else if (p === '/' || p === '/health') {
        res = json({ ok: true, service: 'potfolio-api' });
      } else {
        throw new HttpError(404, 'Not found');
      }
      Object.entries(c).forEach(([k, v]) => res.headers.set(k, v));
      return res;
    } catch (e) {
      const status = e instanceof HttpError || e instanceof TradeError ? e.status : 500;
      const message = e instanceof Error ? e.message : 'Server error';
      return json({ error: message }, status, c);
    }
  },
};

/**
 * Light webhooks: never trust the payload alone. Re-read the session from
 * Light with our API key, then credit once per session (idempotent).
 */
async function handleWebhook(body: any, env: Env) {
  const type: string = body?.type ?? '';
  if (type !== 'checkout_session.completed') return;
  const obj = body?.data?.object ?? body?.data ?? {};
  const id: string | undefined = obj?.id ?? obj?.checkout_session ?? body?.checkout_session;
  if (!id) return;
  if (await env.KV.get(`credited:${id}`)) return;
  const session = (await lightFetch(env, 'GET', `/v1/checkout_sessions/${encodeURIComponent(id)}`)) as any;
  if (session?.status !== 'completed') return;
  const meta = await env.KV.get(`session:${id}`);
  const ref = String(session?.reference ?? '');
  const uid = meta ? JSON.parse(meta).uid : ((await env.KV.get(`ref:${ref}`)) ?? (ref.includes(':') ? ref.split(':')[0] : ''));
  if (!uid) return;
  const micro = Number(session?.receive?.amount ?? 0);
  const prev = Number((await env.KV.get(`bal:${uid}`)) ?? '0');
  await env.KV.put(`bal:${uid}`, String(prev + micro));
  await env.KV.put(`credited:${id}`, '1');
}
