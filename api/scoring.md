# Regra de pontuação — Bolão 2026

Calculada **somente sobre o palpite de placar** (`Prediction` home/away) versus o **resultado**
da `Match`. **Modelo granular de mercado (estilo "dacopa"):** acertar o vencedor/empate é o portão;
dentro dele, quanto mais preciso o palpite, mais pontos — com o **saldo de gols** como critério,
igual aos bolões tradicionais (BR e mundo).

> **Centralizar** num único `ScoringService`. Três visões consomem dele e **não podem divergir**:
> ranking do torneio (acumulado), ranking da partida (por jogo, provisório no LIVE) e o
> "engajamento do bolão" (agregação no admin). **Uma fonte só.**

## Fórmula

```
errou o vencedor/empate (sinal do saldo diferente) → NONE          (0)
acertou o vencedor/empate:
  placar exato                                      → EXACT         (cravou)
  + gols do vencedor exatos                         → WINNER_GOALS
  + saldo de gols igual                             → GOAL_DIFF
  + gols do perdedor exatos                         → LOSER_GOALS
  nada além do vencedor/empate                      → OUTCOME
```

Prioridade (de cima pra baixo): `EXACT > WINNER_GOALS > GOAL_DIFF > LOSER_GOALS > OUTCOME`.
**Empate não tem vencedor/perdedor**, então um empate certo com placar diferente é sempre `OUTCOME`.

Padrões (parametrizáveis via env): **EXACT = 25**, **WINNER_GOALS = 18**, **GOAL_DIFF = 15**,
**LOSER_GOALS = 12**, **OUTCOME = 10** (`SCORING_EXACT` / `SCORING_WINNER_GOALS` /
`SCORING_GOAL_DIFF` / `SCORING_LOSER_GOALS` / `SCORING_OUTCOME`).

### Faixas e rótulo (`tier`, p/ UI)

| `tier` | Rótulo | Condição | Pontos (padrão) |
|---|---|---|---|
| `EXACT` | Cravou | placar exato | **25** |
| `WINNER_GOALS` | Gols do vencedor | vencedor certo + gols do vencedor exatos | **18** |
| `GOAL_DIFF` | Acertou o saldo | vencedor certo + saldo de gols igual | **15** |
| `LOSER_GOALS` | Gols do perdedor | vencedor certo + gols do perdedor exatos | **12** |
| `OUTCOME` | Acertou o vencedor | só o vencedor/empate | **10** |
| `NONE` | Não pontuou | errou o vencedor/empate | **0** |

Exemplos (resultado **2 × 1**): `2-1`→25 · `2-0`→18 · `3-2`→15 · `3-1`→12 · `4-2`→10 ·
`0-2`→0 · `1-1`→0. Empate **2 × 2**: `2-2`→25 · `1-1`→10 · `3-1`→0.

## Peso por fase (mata-mata)

Partidas de mata-mata valem mais, de forma **progressiva com teto** e **adaptativa ao bracket**
(sem nomes de fase hardcoded — funciona pra Copa que começa nos 16-avos, nas oitavas, etc.):

```
weight = min(1 + profundidade * PHASE_STEP, PHASE_CAP)
```

`profundidade` = posição 1-based da rodada dentro dos stages `KNOCKOUT` da temporada (fase de
grupos/liga = profundidade 0 → peso 1). `PHASE_STEP` = quanto cada rodada adiciona (+1/+2/…);
`PHASE_CAP` = teto do multiplicador (`0` = sem teto, progressão pura).

Com o padrão (`SCORING_PHASE_STEP = 1`, `SCORING_PHASE_CAP = 3`), na Copa 2026:

| Fase | Profundidade | Peso |
|---|---|---|
| Fase de grupos | 0 | 1× |
| 16-avos | 1 | 2× |
| Oitavas | 2 | 3× |
| Quartas | 3 | 3× (teto) |
| Semifinais | 4 | 3× (teto) |
| Final / 3º lugar | 5 | 3× (teto) |

**"Dobrar fixo no mata-mata"** = `PHASE_STEP = 1` + `PHASE_CAP = 2` (toda rodada eliminatória → 2×).
`PHASE_STEP = 0` (ou `PHASE_CAP = 1`) desliga o peso. O `tier` **não** muda com o peso; só os
pontos são multiplicados. Aplicado ao acumular nos rankings e na visão de palpites
(`PhaseWeightService.byRound`).

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
  const po = Math.sign(pred.home - pred.away), ro = Math.sign(result.home - result.away);
  if (po !== ro) return 'NONE';                                  // errou o vencedor/empate
  if (pred.home === result.home && pred.away === result.away) return 'EXACT';
  if (ro === 0) return 'OUTCOME';                                // empate certo, placar diferente
  const predWin = po > 0 ? pred.home : pred.away;
  const predLose = po > 0 ? pred.away : pred.home;
  const resWin = ro > 0 ? result.home : result.away;
  const resLose = ro > 0 ? result.away : result.home;
  if (predWin === resWin) return 'WINNER_GOALS';
  if (pred.home - pred.away === result.home - result.away) return 'GOAL_DIFF';
  if (predLose === resLose) return 'LOSER_GOALS';
  return 'OUTCOME';
}

function score(pred, result, weight = 1) {
  const tier = tierFor(pred, result);
  const base = tier === 'NONE' ? 0 : POINTS[tier];   // EXACT 25 / WINNER_GOALS 18 / ...
  return { tier, points: base * weight };            // weight = phaseWeight(profundidade)
}
```

Coberto por testes em `scoring.service.spec.ts`.
