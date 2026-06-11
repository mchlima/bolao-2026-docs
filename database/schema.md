# Schema — Bolão 2026

Modelo relacional (Postgres via Prisma). Inglês em todos os nomes. O schema Prisma comentado
canônico vive em `bolao-2026-api/prisma/schema.prisma`; este documento descreve o domínio e o ER.

## Entidades

### User
- `id`, `name`, `email` (único), `passwordHash` (nullable — login social futuro)
- `role: UserRole` (`USER`/`ADMIN`), `isActive: boolean` (desativar acesso)
- `createdAt`, `updatedAt`

### Tournament
- `id`, `name`, `logoUrl`, `startDate`, `endDate`
- `status: TournamentStatus` (inclui `DRAFT`)
- **Entidade simples** — sem formato/fases/grupos/chaves.

### Team
- `id`, `name`, `shortName` (sigla), `type: TeamType` (`NATIONAL_TEAM`/`CLUB`)
- Seleção: `countryCode` + `continent`
- Clube: `country` + `logoUrl`

### Stadium
- `id`, `name`, `city`, `state` (estado/região), `country`
- Referenciado pela `Match` (cidade/estado/país inferidos).

### Match
- `id`, `tournamentId`, `homeTeamId?`, `awayTeamId?`, `stadiumId?`, `kickoffAt`
- **`homeTeamId`/`awayTeamId` são nullable** — confrontos de mata-mata ficam "a definir" até o
  chaveamento resolver (desvio consciente do briefing, que assumia time obrigatório; ver
  DECISIONS #13).
- `homeSourceLabel?`/`awaySourceLabel?` — texto do slot quando o time é TBD ("Vencedor Grupo A",
  "Vencedor Jogo 73", "2º Grupo C").
- `status: MatchStatus` (`SCHEDULED`/`LIVE`/`FINISHED`/`CANCELLED`)
- `homeScore`, `awayScore` (nullable até haver placar)
- `phaseLabel` (texto livre: "Fase de Grupos", "Oitavas de final"…)
- `groupName?` ("A".."L"), `matchNumber?` (nº oficial 1..N)
- **`@@unique([tournamentId, matchNumber])`** — seed idempotente de partidas.

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
User 1──* Prediction *──1 Match *──1 Tournament
                              │ *──1 Stadium
                   Match.home/away ──* Team
User 1──* AuditLog
```

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
