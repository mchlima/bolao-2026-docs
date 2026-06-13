# Schema — Bolão 2026

Modelo relacional (Postgres via Prisma). Inglês em todos os nomes. O schema Prisma comentado
canônico vive em `bolao-2026-api/prisma/schema.prisma`; este documento descreve o domínio e o ER.

## Entidades

### User
- `id`, `name`, `email` (único), `passwordHash` (nullable — login social futuro)
- `role: UserRole` (`USER`/`ADMIN`), `isActive: boolean` (desativar acesso)
- `createdAt`, `updatedAt`

### Competition
- `id`, `name` ("Copa do Mundo FIFA", "Brasileirão Série A"), `slug` (único), `type: CompetitionType`
  (`LEAGUE`/`CUP`/`LEAGUE_CUP`), `country?`, `confederation?`, `logoUrl?`
- **`espnLeagueSlug?`** — slug da liga na API ESPN; o robô monta a URL do scoreboard com ele (um motor,
  N torneios). Ex.: `fifa.world`, `bra.1`, `conmebol.libertadores`.
- Entidade **atemporal** — agrupa N edições (`Season`).

### Season (era `Tournament`)
- `id`, `competitionId`, `name` (nome de exibição da edição), `seasonLabel?` ("2026"), `logoUrl`,
  `startDate`, `endDate`, `status: SeasonStatus` (`DRAFT`/`UPCOMING`/`ONGOING`/`FINISHED`)
- `format: SeasonFormat` (`LEAGUE`/`GROUPS`/`KNOCKOUT`/`GROUPS_KNOCKOUT`), `winnerTeamId?`
- **Uma edição** de uma `Competition`. É a quem o `Pool` (bolão) se vincula. Dona da estrutura abaixo.

### Stage
- `id`, `seasonId`, `name` ("Fase de Grupos"/"Mata-mata"/"Pontos Corridos"), `format: StageFormat`
  (`LEAGUE`/`GROUP`/`KNOCKOUT`), `order`
- `tiebreakPreset: TiebreakPreset` (`FIFA`/`BRASILEIRAO`/`UEFA`/`CONMEBOL`/`GENERIC`), `tiebreakOverride? (Json)`,
  `hasThirdPlace`
- **Fase-formato** de uma Season; decide se produz tabela (LEAGUE/GROUP) ou bracket (KNOCKOUT).

### Group + GroupTeam
- `Group`: `id`, `stageId`, `name` ("A".."L" ou o nome da liga), `order`.
- `GroupTeam` (join): `groupId`, `teamId`, `seed?` — único por `(groupId, teamId)`. Fixa o elenco do grupo
  (tabela renderiza mesmo sem jogos). **Classificação é calculada** (não armazenada).

### Round
- `id`, `stageId`, `number?` (rodada 1..38), `name?` ("Oitavas de final"), `legs` (1 ou 2), `order`.
- Fatia do Stage: rodada/matchday numa liga/grupo, ou fase de mata-mata nomeada. Round é atributo **do
  jogo** — adiar uma partida mantém a rodada, muda só a data.

### Tie
- `id`, `roundId`, `order`, `homeTeamId?`, `awayTeamId?` (null = TBD), `aggregateHome?`, `aggregateAway?`,
  `winnerTeamId?`, `resolution? (TieResolution)` (`AGGREGATE`/`AWAY_GOALS`/`EXTRA_TIME`/`PENALTIES`).
- **`homeSource?`/`awaySource?` (Json)** + `homeSourceLabel?`/`awaySourceLabel?` (display fallback) — feeder
  tipado do slot TBD: `{GROUP_POSITION, groupId, position}`, `{BEST_RANKED, stageId, eligibleGroups, position}`,
  `{MATCH_WINNER, tieId}`, `{MATCH_LOSER, tieId}`.
- **Nó do bracket** acima de 1 (jogo único) ou 2 (ida/volta) `Match`. `SlotResolverService` resolve os
  feeders e calcula agregado/pênaltis/vencedor; admin pode sobrescrever (melhor-3º da Copa 2026 fica manual).

### Classificação (tabela de pontos)
- **Calculada** (não armazenada como verdade) pelo `StandingsService` a partir dos `Match` `FINISHED`:
  `P/J/V/E/D/GP/GC/SG/% (aproveitamento) + últimos-5`, ordenada pelo preset de desempate do Stage (com
  acesso ao subconjunto confronto-direto). `% = pontos/(jogos×3)`, só display.

### Team
- `id`, `name`, `shortName` (sigla), `type: TeamType` (`NATIONAL_TEAM`/`CLUB`)
- Seleção: `countryCode` + `continent`
- Clube: `country` + `logoUrl`

### Stadium
- `id`, `name`, `city`, `state` (estado/região), `country`
- Referenciado pela `Match` (cidade/estado/país inferidos).

### Match
- `id`, `seasonId`, `homeTeamId?`, `awayTeamId?`, `stadiumId?`, `kickoffAt`
- **Links de estrutura** (nullable): `stageId?`, `groupId?` (LEAGUE/GROUP), `roundId?`, `tieId?` (KNOCKOUT),
  `leg?` (1=ida, 2=volta).
- **`homeTeamId`/`awayTeamId` são nullable** — confrontos de mata-mata ficam "a definir" até o
  chaveamento resolver (ver DECISIONS #13). `homeSourceLabel?`/`awaySourceLabel?` = display fallback do
  feeder (o feeder tipado vive na `Tie`).
- `status: MatchStatus` (`SCHEDULED`/`LIVE`/`FINISHED`/`CANCELLED`)
- `homeScore`, `awayScore` (default 0). **Mata-mata:** `homePenalties?`, `awayPenalties?`,
  `winner? (MatchWinner)`, `duration? (MatchDuration: REGULAR/EXTRA_TIME/PENALTY_SHOOTOUT)`.
- `phaseLabel?`, `groupName?` ("A".."L"), `matchNumber?` (nº oficial 1..N) — texto livre mantido p/
  back-compat/display; a estrutura formal agora vive nos FKs acima.
- **`@@unique([seasonId, matchNumber])`** — seed idempotente de partidas.
- Ao finalizar (admin ou robô), dispara o `SlotResolverService` (resolve feeders / agrega ties).

### Prediction
- `id`, `userId`, `matchId`, `homeScore`, `awayScore`
- **Único por `(userId, matchId)`**.
- Pontuação **derivada** (não armazenada como verdade) via `ScoringService`.

### Materialização de pontos (rankings)
Para performance dos rankings, considerar tabelas/materialized views:
- pontos por `(user, tournament)` — ranking do torneio
- pontos por `(user, match)` — ranking da partida
Atualizadas quando o placar/status da partida muda. **Fonte da regra: `ScoringService` único.**

### AuditLog
- `id`, `actorType: AuditActorType` (`USER`/`SYSTEM`), `actorUserId` (nullable)
- `action`, `entityType`, `entityId`, `diff` (JSON de campos antes/depois)
- `createdAt` — **imutável** (sem update/delete).
- Cobre: gerar senha, promover admin, desativar usuário, alterar placar/status de partida.

## Diagrama ER (alto nível)

```
Competition 1──* Season 1──* Stage 1──* Group 1──* GroupTeam *──1 Team
                     │              └──* Round 1──* Tie ──* Match
                     │ 1──* Pool
User 1──* Prediction *──1 Match *──1 Season
                              │ *──1 Stadium
                   Match.home/away ──* Team
User 1──* AuditLog
```
Classificação (P/J/V/E/D/GP/GC/SG/%) é **derivada** dos `Match` (não é tabela) — `StandingsService`.

## Constraints únicas (para seed idempotente)

- `Team.countryCode` é `@unique` (sparse — `NULL` permitido para clubes). Permite upsert de
  seleções por `countryCode`.
- `Stadium @@unique([name, city])`. Permite upsert de estádios por nome+cidade.

## Seed (`prisma/seed.ts` + `prisma db seed`)

Idempotente (upsert). Popula:
- **Admin inicial** — `SEED_ADMIN_EMAIL`/`SEED_ADMIN_PASSWORD`/`SEED_ADMIN_NAME` (default
  `admin@bolao2026.local` / `admin12345` — **trocar**). Re-seed **não** reseta a senha existente.
- **211 seleções FIFA** (`prisma/data/national-teams.ts`) — `name` (pt-BR), `shortName`
  (tri-código FIFA), `countryCode` (ISO 3166-1 alpha-2; `GB-ENG/SCT/WLS/NIR` p/ Reino Unido),
  `continent` (agrupamento por confederação, em inglês).
- **16 estádios da Copa 2026** (`prisma/data/wc2026-stadiums.ts`) — EUA (11), Canadá (2), México (3).
- **Torneio "Copa do Mundo FIFA 2026" + 104 partidas** (`prisma/data/wc2026-matches.ts`) — grade
  oficial FIFA + sorteio final (05/12/2025), com cross-check (Wikipédia/ESPN). 72 partidas da fase
  de grupos com seleções reais linkadas (via `countryCode`); 32 do mata-mata como slots TBD
  (`homeSourceLabel`/`awaySourceLabel`). `kickoffAt` em UTC, convertido do horário local de cada
  estádio (offset por sede; México sem horário de verão = −06:00).
  - ⚠ **Ressalvas dos dados:** horários da fase de grupos em parte derivados por conversão de fuso
    (±minutos); **horários do mata-mata são placeholders** (`18:00` local) — confirmar na FIFA.

> Convenção dos dados de seleção: `name` em pt-BR (conteúdo exibido); `shortName`/`countryCode`/
> `continent` neutros. Kazaquistão fica em UEFA (mudou da AFC em 2002).

## Convenção Prisma + Supabase

Dual-URL obrigatório (ver `deploy/`):
- `DATABASE_URL` → pooler 6543 (`?pgbouncer=true`) — runtime.
- `DIRECT_URL` → direta 5432 — apenas `prisma migrate`/`introspect`.
