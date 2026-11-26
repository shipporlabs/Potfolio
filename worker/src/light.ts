import type { Env } from './index';

/** Light (Sendlight) API helpers. Write requests are Ed25519-signed:
 *  message = METHOD \n PATH?QUERY \n TIMESTAMP \n IDEMPOTENCY-KEY \n sha256hex(body)
 *  header  Light-Signature: v1=<base64 signature>
 *  Docs: https://docs.sendlight.xyz/docs/signing-requests.md
 */
let cachedKey: CryptoKey | null = null;

async function signingKey(pem: string): Promise<CryptoKey> {
  if (cachedKey) return cachedKey;
  const b64 = pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const der = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  cachedKey = await crypto.subtle.importKey('pkcs8', der, { name: 'Ed25519' }, false, ['sign']);
  return cachedKey;
}

const hex = (buf: ArrayBuffer) => [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
const b64 = (buf: ArrayBuffer) => btoa(String.fromCharCode(...new Uint8Array(buf)));

export async function lightFetch(env: Env, method: string, path: string, body?: unknown): Promise<unknown> {
  const headers: Record<string, string> = { authorization: `Bearer ${env.LIGHT_API_KEY}` };
  let raw = '';
  if (method !== 'GET') {
    raw = body === undefined ? '' : JSON.stringify(body);
    const idem = crypto.randomUUID();
    const ts = String(Math.floor(Date.now() / 1000));
    const bodyHash = hex(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(raw)));
    const msg = [method.toUpperCase(), path, ts, idem, bodyHash].join('\n');
    const sig = await crypto.subtle.sign({ name: 'Ed25519' }, await signingKey(env.LIGHT_SIGNING_KEY), new TextEncoder().encode(msg));
    Object.assign(headers, {
      'content-type': 'application/json',
      'idempotency-key': idem,
      'light-timestamp': ts,
      'light-signature': `v1=${b64(sig)}`,
    });
  }
  const r = await fetch(`${env.LIGHT_BASE_URL}${path}`, { method, headers, body: method === 'GET' ? undefined : raw });
  const data = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error((data as any)?.error?.message ?? (data as any)?.message ?? `Light error ${r.status}`);
  return data;
}

/** Public checkout endpoints (client secret, no API key). Proxied so browsers
 *  don't need their origin on Light's allow-list. */
export async function lightPublic(env: Env, method: 'GET' | 'POST', path: string, body?: unknown): Promise<unknown> {
  const r = await fetch(`${env.LIGHT_BASE_URL}${path}`, {
    method,
    headers: method === 'POST' ? { 'content-type': 'application/json', 'idempotency-key': crypto.randomUUID() } : {},
    body: method === 'POST' ? JSON.stringify(body ?? {}) : undefined,
  });
  const data = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error((data as any)?.error?.message ?? (data as any)?.message ?? `Checkout error ${r.status}`);
  return data;
}
