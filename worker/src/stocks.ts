import type { Env } from './index';
import US from '../data/stocks_us.json';
import NG from '../data/stocks_ng.json';
import EU from '../data/stocks_eu.json';
import UK from '../data/stocks_uk.json';
import KE from '../data/stocks_ke.json';

type Stock = { symbol: string; name: string; exchange: string; sector: string; domain?: string; td?: string; tdExchange?: string; contract?: string; price?: number; changePct?: number; priceAt?: string; logo?: string };

const LISTS: Record<string, Stock[]> = { US: US as Stock[], NG: NG as Stock[], EU: EU as Stock[], UK: UK as Stock[], KE: KE as Stock[] };
const TOKENIZED = 'https://api.coinbase.com/v1/tokenized-stocks';

/** Coinbase tokenized tickers carry a lowercase suffix (AAPLc, older AAPLx).
 *  Strip it so they match the plain exchange ticker in our lists. */
const norm = (t: string) => {
  let x = t.trim();
  if (x.length > 1 && /[a-z]$/.test(x) && /[A-Z]/.test(x.slice(0, -1))) x = x.slice(0, -1);
  return x.toUpperCase().replace(/[^A-Z0-9]/g, '');
};

async function cached<T>(key: string, ttl: number, ctx: ExecutionContext, fn: () => Promise<T>): Promise<T> {
  const cache = caches.default;
  const req = new Request(`https://cache.potfolio/${key}`);
  const hit = await cache.match(req);
  if (hit) return (await hit.json()) as T;
  const data = await fn();
  ctx.waitUntil(cache.put(req, new Response(JSON.stringify(data), { headers: { 'cache-control': `max-age=${ttl}` } })));
  return data;
}

export async function getStocks(market: string, env: Env, ctx: ExecutionContext): Promise<Stock[]> {
  const base = LISTS[market];
  if (!base) return [];
  return cached(`stocks-${market}`, 180, ctx, async () => {
    if (market === 'US') return mergeTokenized(base);
    return env.TWELVE_DATA_KEY ? withQuotes(base, env.TWELVE_DATA_KEY) : base;
  });
}

/** Coinbase tokenized stocks on Base: contract + Chainlink reference price. */
async function mergeTokenized(base: Stock[]): Promise<Stock[]> {
  try {
    const r = await fetch(`${TOKENIZED}?page_size=500`);
    if (!r.ok) return base;
    const body: any = await r.json();
    const recs: any[] = Array.isArray(body) ? body : (Object.values(body).find((v) => Array.isArray(v)) as any[]) ?? [];
    const by = new Map<string, any>();
    for (const rec of recs) by.set(norm(String(rec.ticker ?? rec.symbol ?? '')), rec);
    const merged = base.map((s) => {
      const rec = by.get(norm(s.symbol));
      if (!rec) return s;
      const nav = Number(typeof rec.nav_price === 'object' ? rec.nav_price?.value : rec.nav_price);
      return { ...s, contract: String(rec.contract_address ?? '').toLowerCase(), price: nav > 0 ? nav : s.price, priceAt: rec.nav_price_updated_at, logo: `${TOKENIZED}/images/${rec.symbol ?? s.symbol}` };
    });
    // Tokenized stocks not in our curated list still appear, so the list stays complete.
    const known = new Set(base.map((s) => norm(s.symbol)));
    for (const [t, rec] of by) {
      if (known.has(t) || !rec.contract_address) continue;
      const nav = Number(typeof rec.nav_price === 'object' ? rec.nav_price?.value : rec.nav_price);
      merged.push({ symbol: t, name: String(rec.name ?? t), exchange: 'US', sector: 'other', contract: String(rec.contract_address).toLowerCase(), price: nav > 0 ? nav : undefined, priceAt: rec.nav_price_updated_at, logo: `${TOKENIZED}/images/${rec.symbol ?? t}` });
    }
    return merged;
  } catch {
    return base;
  }
}

/** Optional delayed quotes for non-US markets (Twelve Data free tier). */
async function withQuotes(base: Stock[], key: string): Promise<Stock[]> {
  const groups = new Map<string, Stock[]>();
  for (const s of base) {
    if (!s.td) continue;
    const g = s.tdExchange ?? '';
    groups.set(g, [...(groups.get(g) ?? []), s]);
  }
  const quotes = new Map<string, any>();
  await Promise.all(
    [...groups].map(async ([exchange, list]) => {
      const u = new URL('https://api.twelvedata.com/quote');
      u.searchParams.set('symbol', list.map((s) => s.td).join(','));
      if (exchange) u.searchParams.set('exchange', exchange);
      u.searchParams.set('apikey', key);
      try {
        const r = await fetch(u);
        const j: any = await r.json();
        if (list.length === 1) quotes.set(list[0].td!, j);
        else for (const s of list) if (j?.[s.td!]) quotes.set(s.td!, j[s.td!]);
      } catch {}
    }),
  );
  return base.map((s) => {
    const q = s.td ? quotes.get(s.td) : undefined;
    const price = Number(q?.close);
    const ch = Number(q?.percent_change);
    return q && price > 0 ? { ...s, price, changePct: Number.isFinite(ch) ? ch : undefined, priceAt: q?.datetime } : s;
  });
}

export async function getHistory(symbol: string, market: string, env: Env): Promise<{ points: number[]; reason?: string }> {
  if (!env.TWELVE_DATA_KEY) return { points: [], reason: 'no_key' };
  if (!symbol) return { points: [], reason: 'no_data' };
  const s = (LISTS[market] ?? []).find((x) => x.symbol === symbol);
  const u = new URL('https://api.twelvedata.com/time_series');
  u.searchParams.set('symbol', s?.td ?? symbol);
  if (s?.tdExchange) u.searchParams.set('exchange', s.tdExchange);
  u.searchParams.set('interval', '1day');
  u.searchParams.set('outputsize', '30');
  u.searchParams.set('apikey', env.TWELVE_DATA_KEY);
  try {
    const j: any = await (await fetch(u)).json();
    const points = ((j?.values ?? []) as any[]).map((v) => Number(v.close)).filter((n) => n > 0).reverse();
    return points.length ? { points } : { points, reason: j?.code === 429 ? 'rate_limited' : 'no_data' };
  } catch {
    return { points: [], reason: 'no_data' };
  }
}
