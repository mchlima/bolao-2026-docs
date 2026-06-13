# Spike: cartões da ESPN → desempate automático (fair play)

**Data:** 2026-06-13 · **Status:** ✅ **IMPLEMENTADO** (2026-06-13). Investigação confirmada viável e
construída — schema, robô, `StandingsService` e `bestThirdLetter` já usam fair play. Ver "Implementação" no fim.

## Pergunta

O ranking dos **terceiros colocados** da Copa (e o desempate de grupo em geral) hoje vai só até
`pontos → saldo → gols → nome`. A Decisão #19 deixou **cartões e ranking-FIFA fora do modelo**
(override manual do admin no empate raro). Este spike responde: **o feed da ESPN entrega cartões
suficientes p/ automatizar o critério de _fair play_ da FIFA?**

Critério FIFA p/ ranquear os 8 melhores terceiros (e desempate de grupo), na ordem:
1. Pontos → 2. Saldo de gols → 3. Gols pró → **4. Pontos de fair play (disciplina)** → 5. Sorteio/ranking FIFA.

Pontos de fair play (por jogador, somados): amarelo simples **−1**, segundo amarelo (vermelho
indireto) **−3**, vermelho direto **−4**, amarelo + vermelho direto **−5**. Menos negativo = melhor.

## Achados

**1. Os cartões JÁ vêm no scoreboard que o robô lê a cada 15 s — sem chamada extra.**
`competition.details[]` (no mesmo `…/soccer/<slug>/scoreboard` que o `live-ingest` poll) traz cada
cartão com flags limpas:
```
{ type:{id:"94|93"}, yellowCard:true|false, redCard:true|false,
  team:{id}, athletesInvolved:[{ id, displayName, … }], clock, ... }
```
`type.id` 94 = amarelo, 93 = vermelho. (O `summary?event=` tem o mesmo em `keyEvents`, mais rico,
mas é uma chamada por jogo — desnecessário.)

**2. O `boxscore`/`standings` da ESPN NÃO agregam cartões.** O `standings` traz só
`gamesPlayed/wins/ties/losses/points/pointDifferential/rank` — **sem fair play**. Ou seja, a ESPN
não ranqueia disciplina por nós; **temos de computar**. (É exatamente a lacuna a fechar.)

**3. Segundo amarelo é inferível por jogador.** A ESPN não distingue "2º amarelo" de "vermelho
direto" pelo `type` (ambos viram `redCard:true`, id 93). Mas `athletesInvolved[].id` permite
rastrear a sequência por atleta: `Y` depois `R` no mesmo id = 2ª advertência (**−3**); `R` solto =
vermelho direto (**−4**); `Y` solto = **−1**. (O caso raro amarelo+vermelho-direto = −5 fica como
override admin.)

**4. Validado contra 4 jogos reais finalizados** (Copa, 2026-06-11/12), computando fair play do
feed:

| Jogo | Time | Amarelos | Vermelhos | Fair play |
|---|---|---|---|---|
| RSA @ MEX | MEX | 1 | 1 | −5 |
| RSA @ MEX | RSA | 2 | 2 | −10 |
| CZE @ KOR | KOR | 1 | 0 | −1 |
| BIH @ CAN | CAN | 2 | 0 | −2 |
| BIH @ CAN | BIH | 3 | 0 | −3 |
| PAR @ USA | PAR | 5 | 0 | −5 |
| PAR @ USA | USA | 1 | 0 | −1 |

(Sem 2º amarelo nesta amostra — todos os vermelhos foram diretos; a lógica por-atleta cobre o 2º
amarelo quando ocorrer.)

## Veredito

**Viável e barato.** Custo zero de chamadas extra à ESPN. A única peça que falta no nosso lado é
**persistir cartões por time/partida** (o schema do `Match` não tem campo de cartão hoje).

## Implementação (feita 2026-06-13)

1. **Schema** — `Match` ganhou `homeYellow/homeRed/awayYellow/awayRed` (cru, p/ exibir) e
   `homeFairPlay/awayFairPlay` (pontos FIFA, ≤ 0), todos `Int @default(0)`. Migração aditiva
   `20260613060000_match_cards_fairplay` (NOT NULL default 0 → segura p/ linhas e código antigos),
   aplicada no dev via `migrate deploy`.
2. **`EspnService`** — `parseDiscipline()` varre `competition.details[]`, mapeia `team.id`→sigla pelos
   competidores, agrupa por `athletesInvolved[].id` e soma `playerFairPlay(amarelos, vermelhos)` por time
   (amarelo simples −1, 2ª advertência/`Y+R` mesmo jogador −3, vermelho direto −4). Ambos exportados e
   testados (incl. fixture do RSA@MEX real → MEX −5, RSA −10).
3. **`LiveIngestService`** — no mesmo tick que já lê o scoreboard, grava cartões+fair play (chaveado por
   `espnAbbr`) quando o jogo está `in`/`post`. Sem chamada extra; idempotente (só escreve no que mudou).
4. **`StandingsService`** — `Criterion FAIR_PLAY` adicionado ao fim de **todos** os presets (lugar correto:
   após overall+H2H, antes do sorteio/nome); o `StandingsRow` agora expõe `yellowCards/redCards/fairPlay`.
5. **`bestThirdLetter`** — ranqueia os 12 terceiros por `pontos → saldo → gols → **fair play** → nome`,
   alimentado pelo `row.fairPlay`.
6. **Override admin permanece** p/ o que a ESPN não desambigua (amarelo + vermelho **direto** = −5) e o
   critério final (ranking-FIFA / sorteio).

**Verificado e2e (2026-06-13):** feed ao vivo da ESPN (4 jogos da Copa) → `parseDiscipline` → gravado no
Supabase de dev → `GET /seasons/:id/standings` expõe os cartões; e o **desempate reordenou de verdade**
(Grupo B: Canadá `fair −2` ficou à frente da Bósnia `fair −3`, empatados em tudo e contra a ordem
alfabética). Dados de teste **limpos depois** (zerados). 42 testes passam.

## Limites

- Depende da granularidade do feed da ESPN (em ligas menores os `details` podem faltar — degradar
  p/ contagem 0 + override).
- O −5 (amarelo + vermelho **direto** no mesmo jogador) não é distinguível do 2º amarelo só pelo
  feed; assumimos 2º amarelo (−3) e deixamos o admin corrigir o caso raro.
