# Contratos de API — Bolão 2026

Contratos compartilhados entre `bolao-2026-api` e `bolao-2026-web`. **Inglês** em todos os
identificadores; mensagens de UI traduzidas no front.

## Base

- Base URL (prod): `https://api-bolao2026.kratinho.com.br`
- Prefixo global: `/api` (a confirmar)
- Auth: `Authorization: Bearer <jwt>`
- Content-Type: `application/json`

## Enums

```
UserRole         = USER | ADMIN
TournamentStatus = DRAFT | UPCOMING | ONGOING | FINISHED      # confirmar conjunto final
TeamType         = NATIONAL_TEAM | CLUB
MatchStatus      = SCHEDULED | LIVE | FINISHED | CANCELLED
ScoreTier        = EXACT | ONE_TEAM_SCORE | OUTCOME | GOAL_DIFF | NONE
AuditActorType   = USER | SYSTEM
```

## Formato de erro

Erro padrão com **código legível por máquina** (NestJS exception filter):

```json
{
  "statusCode": 422,
  "code": "VALIDATION_ERROR",
  "message": "Mensagem legível (pt-BR ok no texto).",
  "details": [{ "field": "email", "code": "INVALID" }],
  "timestamp": "2026-06-11T12:00:00.000Z",
  "path": "/api/auth/register"
}
```

`code` é estável e em UPPER_SNAKE. Exemplos: `UNAUTHENTICATED`, `FORBIDDEN`, `NOT_FOUND`,
`VALIDATION_ERROR`, `CONFLICT`, `PREDICTION_LOCKED`, `MATCH_NOT_OPEN`.

## Paginação

Duas estratégias, por tipo de tela (decisão registrada em [`../DECISIONS.md`](../DECISIONS.md)):

### Offset/limit com total — listagens **admin** (paginação "avançada": ir para página, primeira/última)

Request: `?page=1&pageSize=20&search=&sort=createdAt:desc`

```json
{
  "data": [ /* ... */ ],
  "pagination": { "page": 1, "pageSize": 20, "total": 137, "totalPages": 7 }
}
```

### Cursor — feeds/listas longas públicas

Request: `?cursor=<opaque>&limit=20`

```json
{
  "data": [ /* ... */ ],
  "pagination": { "nextCursor": "<opaque>|null", "hasMore": true }
}
```

## Rankings

- **Ranking do torneio:** soma de pontos no torneio; **top 100** + **posição do usuário logado**
  mesmo fora do top 100 (linha sticky).
- **Ranking da partida:** pontos naquela partida; durante `LIVE` é **provisório** (recalcula com
  o placar); top 100 + posição do usuário.
- **Engajamento (admin):** total de palpites por partida + **distribuição por placar palpitado**
  (`GROUP BY home_score, away_score` com percentuais).

## Polling (telas LIVE, sem WebSocket)

- Endpoints de leitura: placar da partida + ranking provisório da partida.
- Intervalo de polling: ver [`../DECISIONS.md`](../DECISIONS.md) (a definir).

## Regra de pontuação

Ver [`scoring.md`](./scoring.md). Lógica centralizada num único `ScoringService` no backend.

## Endpoints (esboço — detalhar por módulo)

```
POST   /api/auth/register
POST   /api/auth/login
GET    /api/auth/me

GET    /api/tournaments
GET    /api/tournaments/:id
GET    /api/tournaments/:id/ranking          # top 100 + posição do usuário

GET    /api/matches
GET    /api/matches/:id
GET    /api/matches/:id/ranking              # provisório no LIVE
GET    /api/matches/:id/score                # leve, para polling

POST   /api/predictions                      # upsert por (user, match), bloqueia por status
GET    /api/predictions/me

# Admin (role=ADMIN)
CRUD   /api/admin/tournaments
CRUD   /api/admin/teams
CRUD   /api/admin/stadiums
CRUD   /api/admin/matches
PATCH  /api/admin/matches/:id/score          # incremento de placar (LIVE)
PATCH  /api/admin/matches/:id/status
GET    /api/admin/matches/:id/engagement     # distribuição de palpites
CRUD   /api/admin/users                       # ativar/desativar, promover, gerar nova senha
GET    /api/admin/audit-log
```
