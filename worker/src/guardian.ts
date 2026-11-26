import type { Env } from './index';

type Req = { goal: string; amount: number; universe: { symbol: string; name: string; sector: string }[] };

const SYSTEM = `You are the Potfolio Guardian, an educational assistant that builds example stock portfolios.
Rules:
- Use ONLY symbols from the provided universe.
- Pick 3 to 6 stocks. Weights are whole numbers that add up to exactly 100.
- Give each pick one short plain-English reason (max 12 words) about what it adds to the mix.
- List 1 to 3 risks (concentration, sector, single-stock weight). Never predict prices.
- Never say "buy", "sell", "will rise" or give personal financial advice.
Reply with JSON only: {"summary": string, "allocations": [{"symbol": string, "weight": number, "reason": string}], "risks": [string]}`;

const BANNED = /\b(will (rise|go up|moon)|guaranteed|you should buy|must buy|sell now)\b/i;

export async function runGuardian(req: Req, env: Env) {
  const universe = (req.universe ?? []).slice(0, 60);
  const symbols = new Set(universe.map((u) => u.symbol));
  const prompt = `Goal: ${req.goal}. Amount: $${Number(req.amount) || 0}.
Universe (symbol | name | sector):
${universe.map((u) => `${u.symbol} | ${u.name} | ${u.sector}`).join('\n')}`;

  for (let attempt = 0; attempt < 2; attempt++) {
    const out: any = await env.AI.run('@cf/meta/llama-3.1-8b-instruct' as any, {
      messages: [
        { role: 'system', content: SYSTEM },
        { role: 'user', content: prompt },
      ],
      max_tokens: 600,
      temperature: 0.4,
    });
    const text: string = typeof out === 'string' ? out : out?.response ?? '';
    const m = text.match(/\{[\s\S]*\}/);
    if (!m) continue;
    try {
      const j = JSON.parse(m[0]);
      const allocations = ((j.allocations ?? []) as any[])
        .filter((a) => symbols.has(String(a.symbol)))
        .map((a) => ({ symbol: String(a.symbol), weight: Math.max(0, Math.round(Number(a.weight) || 0)), reason: String(a.reason ?? '').slice(0, 90) }))
        .filter((a) => a.weight > 0);
      const unique = allocations.filter((a, i) => allocations.findIndex((b) => b.symbol === a.symbol) === i);
      if (unique.length < 3 || unique.length > 6) continue;
      const total = unique.reduce((s, a) => s + a.weight, 0);
      const scaled = unique.map((a) => ({ ...a, weight: Math.round((a.weight / total) * 100) }));
      scaled[0].weight += 100 - scaled.reduce((s, a) => s + a.weight, 0);
      const risks = ((j.risks ?? []) as any[]).map((r) => String(typeof r === 'object' ? r.message ?? '' : r)).filter((r) => r && !BANNED.test(r)).slice(0, 3);
      const summary = String(j.summary ?? '').slice(0, 200);
      if (BANNED.test(summary) || scaled.some((a) => BANNED.test(a.reason))) continue;
      return { summary, allocations: scaled, risks };
    } catch {
      continue;
    }
  }
  // The app falls back to its own transparent rules when this is empty.
  return { summary: '', allocations: [], risks: [] };
}
