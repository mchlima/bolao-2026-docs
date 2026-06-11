# Regra de pontuação — Bolão 2026

Calculada **somente sobre o palpite de placar** (`Prediction` home/away) versus o **resultado**
da `Match`. **Modelo B (proximidade):** acertar o vencedor é o portão; a partir dele os pontos
crescem com a proximidade de cada placar.

> **Centralizar** num único `ScoringService`. Três visões consomem dela e **não podem divergir**:
> ranking do torneio (acumulado), ranking da partida (por jogo, provisório no LIVE) e o
> "engajamento do bolão" (agregação no admin). **Uma fonte só.**

## Fórmula

```
errou o vencedor (sinal do saldo diferente)  → 0
acertou o vencedor/empate                    → BASE
  + por time:  gols exatos → TEAM_EXACT
               errou por 1 → TEAM_NEAR
               senão       → 0
```

Padrões (parametrizáveis via env): **BASE = 4**, **TEAM_EXACT = 3**, **TEAM_NEAR = 1**
(`SCORING_BASE` / `SCORING_TEAM_EXACT` / `SCORING_TEAM_NEAR`). Com eles, cravar o placar = **10**.

### Faixas e rótulo (`tier`, p/ UI)

| `tier` | Rótulo | Condição | Pontos (padrão) |
|---|---|---|---|
| `EXACT` | Cravou | placar exato | **10** |
| `ONE_TEAM_SCORE` | Acertou um placar | vencedor certo + cravou os gols de um time | **7–8** |
| `CLOSE` | Quase | vencedor certo, nenhum time cravado, cada um errou por ≤1 | **6** |
| `OUTCOME` | Acertou o vencedor | vencedor certo, placar mais distante | **4–5** |
| `NONE` | Não pontuou | errou o vencedor | **0** |

O `tier` é só um **rótulo** derivado dos mesmos fatos; os pontos vêm da fórmula acima.

Exemplos (resultado **2 × 1**): `2-1`→10 · `2-0`→8 · `3-1`→8 · `3-2`→6 · `1-0`→6 ·
`5-0`→5 · `5-3`→4 · `0-0`→0 · `1-2`→0.

## Desempate

Empate de pontos → **quem palpitou primeiro fica na frente** (`createdAt` do palpite, mais antigo
acima). No **ranking da partida** usa o palpite daquele jogo; no **ranking do torneio**, o palpite
**mais antigo** do usuário no torneio. Posições ficam **distintas** (não compartilhadas) quando o
desempate resolve.

## Regras adicionais

- Partida `CANCELLED` → **não gera pontos** (ignorada em todos os rankings).
- Pontuação só é definitiva quando a partida está `FINISHED`. Em `LIVE`, o cálculo é **provisório**
  usando o placar parcial atual (placar `null` de um lado conta como **0**, ex.: 1-0).
- **Janela de palpite:** por padrão aberto enquanto `status === SCHEDULED` **E** `now < kickoffAt`
  **E** os dois times definidos. O admin pode **sobrepor** manualmente via `Match.predictionsOpen`
  (`true`/`false`; `null` = automático) — funciona até com a partida `LIVE`. Estados terminais
  (`FINISHED`/`CANCELLED`) nunca aceitam palpite. Bloqueado → `PREDICTION_LOCKED`; time TBD →
  `MATCH_NOT_OPEN`.

## Pseudocódigo (referência — implementação real no `ScoringService`)

```ts
function tierFor(pred, result): ScoreTier {
  if (pred.home === result.home && pred.away === result.away) return 'EXACT';
  if (Math.sign(pred.home - pred.away) !== Math.sign(result.home - result.away)) return 'NONE';
  const dh = Math.abs(pred.home - result.home), da = Math.abs(pred.away - result.away);
  if (dh === 0 || da === 0) return 'ONE_TEAM_SCORE';
  if (dh <= 1 && da <= 1) return 'CLOSE';
  return 'OUTCOME';
}

function score(pred, result) {
  const tier = tierFor(pred, result);
  if (tier === 'NONE') return { tier, points: 0 };
  const per = (d) => d === 0 ? TEAM_EXACT : d === 1 ? TEAM_NEAR : 0;
  return { tier, points: BASE + per(|pred.home-result.home|) + per(|pred.away-result.away|) };
}
```

Coberto por testes em `scoring.service.spec.ts`.
