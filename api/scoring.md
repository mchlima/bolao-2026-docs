# Regra de pontuação — Bolão 2026

Calculada **somente sobre o palpite de placar** (`Prediction` home/away) versus o **resultado
final** da `Match`. Retorna **apenas o tier mais alto atingido** — em **camadas, não cumulativo**.

> **Centralizar** num único `ScoringService`. Três visões consomem dela e **não podem divergir**:
> ranking do torneio (acumulado), ranking da partida (por jogo, provisório no LIVE) e o
> "engajamento do bolão" (agregação no admin). **Uma fonte só.**

## Camadas (do maior para o menor)

| # | Tier (`ScoreTier`) | Condição | Pontos |
|---|---|---|---|
| 1 | `EXACT` | Cravou o placar exato (home e away corretos) | **TBD** |
| 2 | `ONE_TEAM_SCORE` | Acertou os gols de **um** dos times (home OU away) | **TBD** |
| 3 | `OUTCOME` | Acertou o vencedor (ou o empate) | **TBD** |
| 4 | `GOAL_DIFF` | Acertou a diferença de gols | **TBD** |
| 5 | `NONE` | Nada | **0** |

Retorna o **primeiro** tier satisfeito nesta ordem (o mais alto). Não soma camadas.

> Os **valores numéricos** de cada tier estão em [`../DECISIONS.md`](../DECISIONS.md) (a definir;
> parametrizável é desejável).

## Regras adicionais

- Partida `CANCELLED` → **não gera pontos** (ignorada em todos os rankings).
- Pontuação só é definitiva quando a partida está `FINISHED`. Em `LIVE`, o cálculo é **provisório**
  usando o placar parcial atual.
- Palpite é único por `(user, match)` e bloqueado conforme `MatchStatus` (não aceitar/alterar após
  o kickoff — regra de bloqueio a definir no produto).

## Pseudocódigo (referência — implementação real no `ScoringService`)

```ts
function scoreTier(pred: {home: number; away: number},
                   result: {home: number; away: number}): ScoreTier {
  if (pred.home === result.home && pred.away === result.away) return 'EXACT';
  if (pred.home === result.home || pred.away === result.away) return 'ONE_TEAM_SCORE';
  if (sign(pred.home - pred.away) === sign(result.home - result.away)) return 'OUTCOME';
  if ((pred.home - pred.away) === (result.home - result.away)) return 'GOAL_DIFF';
  return 'NONE';
}
// pontos = TIER_VALUES[scoreTier(...)]
```

> Nota: `OUTCOME` (mesmo sinal da diferença) já cobre empate (sign 0). `GOAL_DIFF` cobre o caso
> raro de mesma diferença mas vencedor oposto — impossível salvo empate, então na prática o tier 4
> só é atingido quando o sinal difere mas a magnitude da diferença coincide. **Validar a ordem e
> semântica exatas com o produto antes de fixar os valores.**
