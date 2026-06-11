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
- `id`, `tournamentId`, `homeTeamId`, `awayTeamId`, `stadiumId`, `kickoffAt`
- `status: MatchStatus` (`SCHEDULED`/`LIVE`/`FINISHED`/`CANCELLED`)
- `homeScore`, `awayScore` (nullable até haver placar)
- `phaseLabel` (texto livre opcional: "Rodada 1", "Oitavas"…)

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

## Convenção Prisma + Supabase

Dual-URL obrigatório (ver `deploy/`):
- `DATABASE_URL` → pooler 6543 (`?pgbouncer=true`) — runtime.
- `DIRECT_URL` → direta 5432 — apenas `prisma migrate`/`introspect`.
