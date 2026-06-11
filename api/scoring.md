# Regra de pontuação — Bolão 2026

Calculada **somente sobre o palpite de placar** (`Prediction` home/away) versus o **resultado
final** da `Match`. Retorna **apenas o tier mais alto atingido** — em **camadas, não cumulativo**.

> **Centralizar** num único `ScoringService`. Três visões consomem dela e **não podem divergir**:
> ranking do torneio (acumulado), ranking da partida (por jogo, provisório no LIVE) e o
> "engajamento do bolão" (agregação no admin). **Uma fonte só.**

## Camadas (do maior para o menor)

| # | Tier (`ScoreTier`) | Condição | Pontos |
|---|---|---|---|
| 1 | `EXACT` | Cravou o placar exato (home e away corretos) | **10** |
| 2 | `ONE_TEAM_SCORE` | Acertou os gols de **um** dos times (home OU away) | **5** |
| 3 | `GOAL_DIFF` | Acertou o saldo de gols (⇒ mesmo resultado), sem cravar | **4** |
| 4 | `OUTCOME` | Acertou só o vencedor (ou o empate), saldo errado | **3** |
| 5 | `NONE` | Nada | **0** |

Retorna o **primeiro** tier satisfeito nesta ordem (o mais alto). Não soma camadas.

> **Decisão #1 (resolvida):** valores acima. Ordem por **especificidade** — `GOAL_DIFF` fica
> **acima** de `OUTCOME` para ser alcançável (saldo exato implica mesmo vencedor). Os valores são
> **parametrizáveis** via env `SCORING_EXACT`/`SCORING_ONE_TEAM_SCORE`/`SCORING_GOAL_DIFF`/
> `SCORING_OUTCOME`. Implementado e testado em `ScoringService` (`scoring.service.spec.ts`).

## Regras adicionais

- Partida `CANCELLED` → **não gera pontos** (ignorada em todos os rankings).
- Pontuação só é definitiva quando a partida está `FINISHED`. Em `LIVE`, o cálculo é **provisório**
  usando o placar parcial atual.
- **Bloqueio do palpite (decisão #12, resolvida):** aceita criar/alterar só enquanto
  `status === SCHEDULED` **E** `now < kickoffAt` **E** os dois times estão definidos. Caso
  contrário: `PREDICTION_LOCKED` (já começou/encerrou) ou `MATCH_NOT_OPEN` (time ainda TBD).

## Pseudocódigo (referência — implementação real no `ScoringService`)

```ts
function scoreTier(pred: {home: number; away: number},
                   result: {home: number; away: number}): ScoreTier {
  if (pred.home === result.home && pred.away === result.away) return 'EXACT';
  if (pred.home === result.home || pred.away === result.away) return 'ONE_TEAM_SCORE';
  if ((pred.home - pred.away) === (result.home - result.away)) return 'GOAL_DIFF';
  if (Math.sign(pred.home - pred.away) === Math.sign(result.home - result.away)) return 'OUTCOME';
  return 'NONE';
}
// pontos = TIER_VALUES[scoreTier(...)]
```

> `GOAL_DIFF` (saldo exato) vem **antes** de `OUTCOME` (mesmo sinal): saldo exato ⇒ mesmo
> vencedor, então precisa ser testado primeiro para ser alcançável. Empate exato cai em `EXACT`
> ou `GOAL_DIFF`. Coberto por testes em `scoring.service.spec.ts`.
