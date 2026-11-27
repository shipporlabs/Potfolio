/**
 * Real trading on Base mainnet.
 *
 *  GET  /trade/quote?side=buy|sell&token=0x…&amount=<raw sell amount>&taker=0x…
 *       Firm 0x Swap API v2 (AllowanceHolder) quote: an unsigned transaction the
 *       user's own wallet signs. Only Coinbase tokenized stocks <-> USDC.
 *  POST /gas/topup  (auth)  { address }
 *       Sends a tiny amount of ETH for network fees from Potfolio's gas wallet,
 *       so users who only hold USDC can still trade. Rate-limited.
 */
import { createPublicClient, createWalletClient, http, parseEther, isAddress, getAddress } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { base } from 'viem/chains';

export interface TradeEnv {
  KV: KVNamespace;
  ZEROX_API_KEY?: string; // secret, from dashboard.0x.org
  GAS_WALLET_KEY?: string; // secret, 0x… private key of a wallet holding a little ETH on Base
  BASE_RPC_URL?: string; // optional, defaults to https://mainnet.base.org
  SWAP_FEE_BPS?: string; // optional Potfolio fee, e.g. "25" = 0.25%
  FEE_RECIPIENT?: string; // optional address that receives the fee (in USDC)
}

export const USDC_BASE = '0x833589fcd6edb6e08f4c7c32d4f71b54bda02913';
const TOKENIZED = 'https://api.coinbase.com/v1/tokenized-stocks';

// Gas top-up policy: top up below MIN, send TOPUP, at most PER_USER per 30 days and DAILY overall.
const MIN_ETH = parseEther('0.00002');
const TOPUP_ETH = parseEther('0.00005');
const PER_USER = 12;
const DAILY = 300;

export class TradeError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

const rpc = (env: TradeEnv) => env.BASE_RPC_URL || 'https://mainnet.base.org';

/** Contract addresses of Coinbase tokenized stocks, cached for 10 minutes. */
async function tokenAllowlist(env: TradeEnv): Promise<Set<string>> {
  const cached = await env.KV.get('trade:tokens');
  if (cached) return new Set(JSON.parse(cached));
  const r = await fetch(`${TOKENIZED}?page_size=500`);
  if (!r.ok) throw new TradeError(502, 'Couldn’t load the tokenized stock list. Try again.');
  const body: any = await r.json();
  const recs: any[] = Array.isArray(body) ? body : (Object.values(body).find((v) => Array.isArray(v)) as any[]) ?? [];
  const list = recs.map((x) => String(x.contract_address ?? '').toLowerCase()).filter((a) => isAddress(a));
  await env.KV.put('trade:tokens', JSON.stringify(list), { expirationTtl: 600 });
  return new Set(list);
}

export async function tradeQuote(url: URL, env: TradeEnv) {
  if (!env.ZEROX_API_KEY) throw new TradeError(503, 'Trading isn’t switched on yet.');
  const side = url.searchParams.get('side');
  const token = (url.searchParams.get('token') ?? '').toLowerCase();
  const amount = url.searchParams.get('amount') ?? '';
  const taker = url.searchParams.get('taker') ?? '';
  if (side !== 'buy' && side !== 'sell') throw new TradeError(400, 'side must be buy or sell');
  if (!isAddress(token) || !isAddress(taker)) throw new TradeError(400, 'Bad token or wallet address');
  if (!/^[0-9]{1,40}$/.test(amount) || BigInt(amount) <= 0n) throw new TradeError(400, 'Bad amount');
  if (!(await tokenAllowlist(env)).has(token)) throw new TradeError(400, 'Only tokenized stocks can be traded here.');

  const q = new URLSearchParams({
    chainId: '8453',
    sellToken: side === 'buy' ? USDC_BASE : token,
    buyToken: side === 'buy' ? token : USDC_BASE,
    sellAmount: amount,
    taker: getAddress(taker),
    slippageBps: '100',
  });
  const fee = Number(env.SWAP_FEE_BPS ?? '0');
  if (fee > 0 && env.FEE_RECIPIENT && isAddress(env.FEE_RECIPIENT)) {
    q.set('swapFeeBps', String(Math.min(fee, 100)));
    q.set('swapFeeRecipient', env.FEE_RECIPIENT);
    q.set('swapFeeToken', USDC_BASE); // fee always taken in USDC
  }
  const r = await fetch(`https://api.0x.org/swap/allowance-holder/quote?${q}`, {
    headers: { '0x-api-key': env.ZEROX_API_KEY, '0x-version': 'v2' },
  });
  const body: any = await r.json().catch(() => ({}));
  if (!r.ok) {
    const reason = body?.data?.details?.[0]?.reason ?? body?.message ?? body?.name;
    throw new TradeError(r.status === 400 ? 400 : 502, reason ? `Quote failed: ${reason}` : 'Couldn’t get a price. Try again.');
  }
  if (body?.liquidityAvailable === false) throw new TradeError(409, 'Not enough liquidity for this trade right now. Try a smaller amount.');
  const tx = body?.transaction ?? {};
  return {
    side,
    token,
    sellToken: body.sellToken,
    buyToken: body.buyToken,
    sellAmount: body.sellAmount,
    buyAmount: body.buyAmount,
    minBuyAmount: body.minBuyAmount,
    allowanceSpender: body?.issues?.allowance?.spender ?? null,
    allowanceActual: body?.issues?.allowance?.actual ?? null,
    balanceIssue: body?.issues?.balance ?? null,
    fees: body.fees ?? null,
    route: (body?.route?.fills ?? []).map((f: any) => f.source),
    transaction: { to: tx.to, data: tx.data, value: tx.value ?? '0', gas: tx.gas, gasPrice: tx.gasPrice },
  };
}

export async function gasTopup(uid: string, body: any, env: TradeEnv) {
  if (!env.GAS_WALLET_KEY) throw new TradeError(503, 'Network fees aren’t covered yet.');
  const address = String(body?.address ?? '');
  if (!isAddress(address)) throw new TradeError(400, 'Bad wallet address');
  const addr = getAddress(address);

  // A user's first wallet is locked to their account, so one account can't fund many wallets.
  const bound = await env.KV.get(`gas:wallet:${uid}`);
  if (bound && bound !== addr) throw new TradeError(403, 'This account is linked to a different wallet.');
  if (!bound) await env.KV.put(`gas:wallet:${uid}`, addr);

  const client = createPublicClient({ chain: base, transport: http(rpc(env)) });
  const bal = await client.getBalance({ address: addr });
  if (bal >= MIN_ETH) return { sent: false, balance: bal.toString() };

  const userKey = `gas:count:${uid}`;
  const used = Number((await env.KV.get(userKey)) ?? '0');
  if (used >= PER_USER) throw new TradeError(429, 'You’ve used your free network fees for now. Add a little ETH on Base to keep trading.');
  const day = `gas:day:${new Date().toISOString().slice(0, 10)}`;
  const today = Number((await env.KV.get(day)) ?? '0');
  if (today >= DAILY) throw new TradeError(429, 'Free network fees are paused for today. Try again tomorrow.');

  const account = privateKeyToAccount(env.GAS_WALLET_KEY.trim() as `0x${string}`);
  const wallet = createWalletClient({ account, chain: base, transport: http(rpc(env)) });
  const hash = await wallet.sendTransaction({ to: addr, value: TOPUP_ETH });
  await env.KV.put(userKey, String(used + 1), { expirationTtl: 60 * 60 * 24 * 30 });
  await env.KV.put(day, String(today + 1), { expirationTtl: 60 * 60 * 48 });
  // Wait so the app's next transaction can use the ETH.
  await client.waitForTransactionReceipt({ hash, timeout: 30_000 }).catch(() => undefined);
  return { sent: true, hash };
}
