# Roadmap — ideias paradas (backlog)

Ideias levantadas e **aprovadas em conceito**, mas adiadas de propósito. Não implementar sem o
usuário retomar. Quando uma virar trabalho ativo, mover o detalhe para os contratos/`DECISIONS.md`.

| # | Item | Valor | Esforço / risco | Gatilho (quando fazer) |
|---|---|---|---|---|
| ~~R1~~ | **Multi-torneio via `espnLeagueSlug`** — ✅ **ABSORVIDO** (2026-06-13, milestone de estrutura) | Alto | — | Feito |
| R2 | **Mercados extras de palpite** | Alto | Grande / médio-alto | Milestone novo, próximo torneio |
| R3 | **Desempate do ranking por mérito** | Médio | Pequeno / baixo | Início de um torneio novo |

---

## R1 — Multi-torneio via `espnLeagueSlug` — ✅ ABSORVIDO (2026-06-13)

> **Feito no milestone de estrutura de competições.** O `espnLeagueSlug` agora vive na entidade
> `Competition`; `EspnService.fetchScoreboard(slug)` monta a URL por liga e o `LiveIngestService`
> agrupa os jogos em janela por slug da competição. Um motor serve qualquer torneio. Ver DECISIONS #19.
> _(Texto original abaixo, mantido como histórico.)_

O app já é multi-torneio, mas o robô de tempo real (`live-ingest`) está **hardcoded na Copa do
Mundo** — `SCOREBOARD_URL = .../soccer/fifa.world/scoreboard` (`espn.service.ts:15`).

**Proposta:** adicionar `espnLeagueSlug` (string, opcional) ao `Tournament`; o robô monta a URL com o
slug da liga da partida em vez do fixo. Assim Brasileirão, Champions, Libertadores, eliminatórias etc.
entram **no mesmo motor** de placar/status ao vivo que já funciona, sem código novo de ingestão.

- **Toca:** `prisma/schema.prisma` (campo + migração), `espn.service.ts` (slug por chamada),
  `live-ingest.service.ts` (passar o slug da partida/torneio), admin (campo no CRUD de torneio).
- **Referência de slugs:** a mesma API ESPN cobre ~128 ligas confirmadas — ver a lista mantida na
  memória do projeto (`espn-league-slugs.md`). Padrão: `.../soccer/<SLUG>/scoreboard`.
- **Cuidado:** API ESPN é não-oficial; cobertura varia por liga (algumas não têm slug). Manter o
  override manual do admin como rede de segurança.

## R2 — Mercados extras de palpite

Hoje o palpite é **só placar**. O endpoint `summary` da ESPN
(`.../soccer/<SLUG>/summary?event=<EVENT_ID>`, onde `EVENT_ID = Match.externalId`) entrega muito mais:
estatísticas por time (`yellowCards`, `redCards`, escanteios, finalizações, posse, faltas, pênaltis…)
e gols com autor+assistência+minuto+tipo.

**Tiers por viabilidade/risco:**
- **Tier 1 — só do placar final (zero dado novo, piloto ideal):** over-under de gols (mais/menos 2,5),
  ambos marcam (BTTS), margem de vitória. Resolve com o score `FINISHED` que já temos.
- **Tier 2 — precisa do `summary` (médio):** total de cartões/escanteios, "sai vermelho?", "sai
  pênalti?". Custo: polling do summary por jogo (mais chamadas no feed não-oficial).
- **Tier 3 — nível jogador (alto):** artilheiro / marcou a qualquer momento. Exige um **modelo de
  jogadores** que não existe (só semeia times) + casar `athlete.id` da ESPN + tratar gol contra/VAR.

**Design:** vira conceito novo (mercado/aposta por jogo: tipo + resultado resolvido + escolha de cada
user) + regra de pontuação própria + UI. É feature/milestone, não ajuste. Manter override do admin na
resolução. **Não introduzir no meio de um torneio.** Começar pelo Tier 1.

## R3 — Desempate do ranking por mérito

Hoje (`rankings.service.ts` → `buildResponse`) o 1º critério de desempate é **"quem apostou primeiro"**
(premia rapidez, não mérito). Proposta:

- **Torneio:** `pontos ↓ → cravadas ↓ → acertos de resultado ↓ → apostou primeiro ↑ (último recurso)
  → nome`. Exige contador novo `correct` no acumulador.
- **Partida:** os contadores colapsam (0/1 num jogo); **empate real** = posição compartilhada quando os
  pontos são iguais (1º, 2º, 2º, 4º…), com "apostou primeiro" só ordenando dentro do empate.

**Sem migração, sem re-pontuação** (`scoring.service` intacto — é só ordenação). 1 arquivo
(`rankings.service.ts`, parametrizando `buildResponse`). **Não mudar no meio da Copa** (muda a ORDEM de
quem já viu sua posição, mesmo sem mudar pontos).

> Adendo (descartado por ora): pontuar proximidade até **2 gols** de diferença. Recomendado **não**
> (achata o ranking + re-pontua retroativo). Se um dia, fazer **graduado** (dif 0→3, 1→2, 2→1, ≥3→0),
> nunca achatado.
