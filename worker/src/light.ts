import type { Env } from './index';

/** Light (Sendlight) API helpers. Write requests are Ed25519-signed:
 *  message = METHOD \n PATH?QUERY \n TIMESTAMP \n IDEMPOTENCY-KEY \n sha256hex(body)
 *  header  Light-Signature: v1=<base64 signature>
 *  Docs: https://docs.sendlight.xyz/docs/signing-requests.md
 */
let cachedKey: CryptoKey | null = null;

const PKCS8_ED25519_PREFIX = [0x30, 0x2e, 0x02, 0x01, 0x00, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x04, 0x22, 0x04, 0x20];

/** Accepts the private key as PKCS#8 PEM (openssl genpkey), the PEM body alone,
 *  an OpenSSH key (ssh-keygen -t ed25519), or a raw 32/64-byte key in base64 or hex.
 *  Gives a clear error for the common mistakes (empty, public key, one PEM line). */
export function toPkcs8(input: string): Uint8Array {
  const text = (input ?? '').replace(/\\n/g, '\n').trim();
  if (!text) throw new Error('LIGHT_SIGNING_KEY is not set. Run: npx wrangler secret put LIGHT_SIGNING_KEY < light_private.pem');
  if (/PUBLIC KEY/.test(text)) throw new Error('LIGHT_SIGNING_KEY holds the public key. Store the private key; the public key goes in the Light dashboard.');
  const body = text.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  if (!body) throw new Error('LIGHT_SIGNING_KEY only has the PEM header line. Pipe the whole file: npx wrangler secret put LIGHT_SIGNING_KEY < light_private.pem');
  let raw: Uint8Array;
  if (/^[0-9a-fA-F]+$/.test(body) && (body.length === 64 || body.length === 128)) {
    raw = Uint8Array.from(body.match(/../g)!.map((h) => parseInt(h, 16)));
  } else {
    try {
      raw = Uint8Array.from(atob(body.replace(/-/g, '+').replace(/_/g, '/')), (c) => c.charCodeAt(0));
    } catch {
      throw new Error('LIGHT_SIGNING_KEY is not valid base64/PEM.');
    }
  }
  const seedToPkcs8 = (seed: Uint8Array) => Uint8Array.from([...PKCS8_ED25519_PREFIX, ...seed]);
  if (raw.length === 48 && raw[0] === 0x30) return raw; // PKCS#8 Ed25519
  if (raw.length === 44 && raw[0] === 0x30) throw new Error('LIGHT_SIGNING_KEY holds the public key, not the private key.');
  if (raw.length === 32) return seedToPkcs8(raw);
  if (raw.length === 64) return seedToPkcs8(raw.slice(0, 32));
  const magic = new TextDecoder().decode(raw.slice(0, 14));
  if (magic === 'openssh-key-v1') {
    // The private section ends with the 64-byte key (seed + public key) right after the
    // second copy of the public key, preceded by its length (0x00000040).
    for (let i = raw.length - 68; i > 0; i--) {
      if (raw[i] === 0 && raw[i + 1] === 0 && raw[i + 2] === 0 && raw[i + 3] === 0x40) return seedToPkcs8(raw.slice(i + 4, i + 36));
    }
  }
  throw new Error(`LIGHT_SIGNING_KEY is not an Ed25519 private key (got ${raw.length} bytes).`);
}

async function signingKey(pem: string): Promise<CryptoKey> {
  if (cachedKey) return cachedKey;
  cachedKey = await crypto.subtle.importKey('pkcs8', toPkcs8(pem), { name: 'Ed25519' }, false, ['sign']);
  return cachedKey;
}

/** Light errors are RFC 9457 problem documents: { type, title, status, code, detail, param, request_id }. */
function problemMessage(data: any, status: number, fallback: string): string {
  const p = data?.error && typeof data.error === 'object' ? data.error : data;
  const text = p?.detail ?? p?.title ?? p?.message ?? `${fallback} ${status}`;
  const code = p?.code ? ` (${p.code}${p?.param ? `: ${p.param}` : ''})` : '';
  const rid = p?.request_id ? ` · ${p.request_id}` : '';
  return `${text}${code}${rid}`;
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
  if (!r.ok) {
    console.error('Light', method, path, r.status, JSON.stringify(data));
    throw new Error(problemMessage(data, r.status, 'Light error'));
  }
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
  if (!r.ok) {
    console.error('Light checkout', method, path, r.status, JSON.stringify(data));
    throw new Error(problemMessage(data, r.status, 'Checkout error'));
  }
  return data;
}
