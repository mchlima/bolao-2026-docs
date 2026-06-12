# Milestone — Plataforma de Bolões (N:N)

**Status:** ativo (retomado 2026-06-12). Antes só discutido; design abaixo aprovado.
**ADR:** ver `decisions/0002-multi-bolao.md`. **Toca os 3 repos** (api/web/docs).

## A virada

Hoje o app é **1 pool global**: todo usuário vê a Copa e os dois rankings (partida e torneio) somam
**todos** os usuários cadastrados. Queremos **N bolões**, onde cada bolão é:

```
Bolão = (um torneio do catálogo global do admin) + (um grupo de membros)
```

O **palpite continua único e global** (na conta do usuário, um por partida — feito na página do
torneio). O bolão **não muda o palpite**: ele é apenas um **grupo que escopa o cálculo dos dois
rankings** (partida e torneio) aos seus membros. Surge a relação **N:N usuário↔bolão**: um usuário
participa de N bolões; um bolão tem N membros.

A visão **global continua existindo na própria página do torneio** (ranking de todos). Cada bolão é
uma **lente** sobre os mesmos palpites: o ranking do bolão reflete direto os palpites dos membros, sem
nenhuma cópia ou palpite paralelo. Casa com a landing `/inicio` ("entre amigos, dispute o topo com a
galera").

O catálogo de torneios **continua global e administrado pelo admin** — o usuário cria um bolão *sobre*
um torneio existente, nunca cria torneio. Todo o admin atual fica intacto.

## Decisões (fechadas 2026-06-12)

| # | Decisão | Escolha |
|---|---------|---------|
| Palpite | Onde mora o palpite | **Único e global** (`Prediction` inalterado, `@@unique([userId, matchId])`). O bolão NÃO tem palpite próprio — palpita-se 1x na página do torneio e vale em todos os bolões daquele torneio. (Descartado: opção por-bolão e o híbrido com override — o usuário optou pela simplicidade.) |
| Ranking | Escopo do bolão | Bolão = **grupo que filtra os rankings** aos seus membros. `buildResponse` recebe a lista de membros e filtra a entrada; motor de scoring (`ScoringService`) e algoritmo de ranking **zero mudança**. A visão global (todos) permanece na página do torneio. |
| Convite | Como o membro entra | **Links nomeados** geridos pelo dono/admin (estilo WhatsApp) — não um código fixo. Criar o bolão NÃO gera link automático; o dono cria N links (cada um com nome + token, revogáveis). Entidade própria `PoolInvite`. Sem dependência de e-mail (decisão #4). **Futuro aqui:** QR code + envio por e-mail. |
| Papéis | Hierarquia no bolão | **OWNER → ADMIN → MEMBER.** O dono pode promover um membro a **admin** (e rebaixar). Admin gere membros, links **e metadados do bolão**; dono mantém o exclusivo (deletar, transferir posse). Ver matriz abaixo. |
| Copa atual | Os 7 usuários já palpitando | **Nada a migrar** nos palpites — a visão global da Copa permanece na página do torneio (ranking de todos). Um bolão é **opt-in/aditivo**: se a turma quiser um grupo privado, criam um sobre a Copa (não é obrigatório). |
| Visibilidade | Descoberta | **Privado por padrão (só convite)** no MVP — sem vitrine pública nem busca/moderação. `visibility` no schema deixa a porta aberta p/ públicos depois. |

## Modelo de dados

Três modelos novos (`Pool`, `PoolMember`, `PoolInvite`). **`Prediction` NÃO muda** — o palpite
segue global. (`User` ganha as relações inversas: bolões que possui, participações e convites criados.)

```prisma
model Pool {
  id           String          @id @default(cuid())
  name         String
  tournamentId String
  ownerId      String
  visibility   PoolVisibility @default(PRIVATE)
  createdAt    DateTime        @default(now())
  updatedAt    DateTime        @updatedAt

  tournament Tournament    @relation(fields: [tournamentId], references: [id])
  owner      User          @relation("PoolOwner", fields: [ownerId], references: [id])
  members    PoolMember[]
  invites    PoolInvite[]

  @@index([tournamentId])
  @@map("pools")
}

model PoolMember {
  id       String          @id @default(cuid())
  poolId  String
  userId   String
  role     PoolMemberRole @default(MEMBER)      // OWNER | ADMIN | MEMBER
  joinedAt DateTime        @default(now())

  pool Pool @relation(fields: [poolId], references: [id], onDelete: Cascade)
  user User  @relation(fields: [userId], references: [id])

  @@unique([poolId, userId])
  @@index([userId])
  @@map("pool_members")
}

// Link de convite nomeado e revogável (estilo WhatsApp). N por bolão.
model PoolInvite {
  id          String   @id @default(cuid())
  poolId     String
  name        String                       // rótulo do link ("Turma do trabalho", "WhatsApp")
  code        String   @unique             // token usado na URL /b/join/<code>
  createdById String                       // membro (dono/admin) que criou
  isActive    Boolean  @default(true)      // revogar sem apagar histórico
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
  // futuro: expiresAt, maxUses, useCount, QR code

  pool      Pool @relation(fields: [poolId], references: [id], onDelete: Cascade)
  createdBy User @relation(fields: [createdById], references: [id])

  @@index([poolId])
  @@map("pool_invites")
}

// Prediction (existente) = PALPITE ÚNICO/GLOBAL DA CONTA. Inalterado: @@unique([userId, matchId]).
// NÃO tem vínculo com Pool — o bolão só FILTRA quais usuários entram no ranking.
```

`enum PoolVisibility { PRIVATE PUBLIC }` (só `PRIVATE` usado no MVP).
`enum PoolMemberRole { OWNER ADMIN MEMBER }`.

> **Nomenclatura:** a UI em pt-BR diz **bolão/bolões**; no código e no banco a entidade é **`Pool`**
> (`pools`/`pool_members`/`pool_invites`). "Bolão" é regionalismo BR — `Pool` é o termo neutro/i18n.

### Papéis e ações (matriz fechada)

| Ação | OWNER | ADMIN | MEMBER |
|------|:-:|:-:|:-:|
| Ver bolão + ranking dos membros | ✅ | ✅ | ✅ |
| Criar/revogar links de convite | ✅ | ✅ | — |
| Expulsar membro comum | ✅ | ✅ | — |
| Promover/rebaixar admin | ✅ | — | — |
| Renomear / editar metadados do bolão | ✅ | ✅ | — |
| Deletar bolão / transferir posse | ✅ | — | — |
| Sair do bolão | — | ✅ | ✅ |

O dono não "sai" — transfere a posse ou deleta o bolão.

### Ranking escopado (a regra central)

O ranking de um bolão é o **mesmo** ranking do torneio, com a entrada **filtrada aos membros**:

```
ranking(bolão) = buildResponse(partidas do torneio, palpites SÓ dos userIds membros do bolão)
ranking(global) = buildResponse(partidas do torneio, palpites de TODOS)   // continua na pág. do torneio
```

- `RankingsService` ganha um filtro **opcional** de `memberUserIds` (derivado do `poolId`). Sem
  bolão = comportamento global de hoje. Com bolão = filtra os participantes.
- **`PredictionsService` não muda** — palpite é global; o bolão não escreve nem lê palpite próprio.
- Sem `PredictionOverride`, sem "palpite efetivo", sem `COALESCE`.

### Migração de dados

**Nenhuma migração de palpites.** A migração é **puramente aditiva** (cria as tabelas `pools`,
`pool_members` e `pool_invites` + enums). A visão global da Copa segue intacta na página do torneio.
Criar um "bolão padrão" para os 7 amigos é **opcional** (eles podem criar pelo fluxo normal).

## Reaproveitado (barato — não muda)

- **Palpites** (`Prediction` + `PredictionsService`): zero mudança — palpite segue global.
- **Motor de scoring** (`ScoringService`): zero mudança.
- **Algoritmo de ranking** (`buildResponse`): só ganha um filtro opcional de membros na entrada.
- **TODO o admin**: torneio = catálogo global, intacto.
- **Robô ESPN / SSE / multi-torneio** + catálogo de 1.538 times: intactos.
- **Auth** + regra de fechamento de palpite no kickoff/fusos: intactas.

## Fases (check-in entre cada uma)

| Fase | Escopo | Tamanho |
|------|--------|---------|
| **F1 — Modelo + migração** | Schema (`Pool`/`PoolMember`/`PoolInvite` + enums) — `Prediction` intacto. Migração **aditiva** (cria 3 tabelas, não toca palpites). Geração de `code` de convite. Verificar contra o Supabase real, limpar dados de teste. | S |
| **F2 — Backend escopado** | `PoolModule`: CRUD do bolão, **links de convite nomeados** (criar/listar/revogar), entrar por `code`, listar "meus bolões", gestão de membros (**promover/rebaixar admin, expulsar**) com a matriz de papéis. `RankingsService` aceita filtro de membros (via `poolId`). Guards por papel. `PredictionsService` intacto. | M |
| **F3 — Frontend** | "Meus bolões" vira a home/seção. Criar bolão / entrar por link / **gerir links nomeados** + **membros (promover/expulsar)**. Página do bolão = **ranking escopado aos membros** (partida + torneio); o palpitar **continua na página do torneio** (global). Roteamento `/b/:id`, join `/b/join/:code`. | M |
| **F4 — Tempo real + polimento** | Ranking do bolão reativo via SSE (reusa as salas do torneio, filtra membros no cliente/servidor), vazios/erros, polimento. | S |

## Em aberto (resolver na fase que tocar)

- **Públicos** (vitrine/busca/moderação): fora do MVP; `visibility` já deixa a porta aberta.
- **Detalhes de papéis** (OWNER/ADMIN/MEMBER + matriz já definidos): confirmar na F2 — limite de
  membros e fluxo de transferência de posse.
- **Convite por QR code e e-mail**: somar à entidade `PoolInvite` quando houver (QR code já cabe no
  `code`; e-mail depende do serviço — decisão #4).
- **Ranking de partida no bolão**: o ranking da partida também filtra por membros (mesma regra);
  confirmar a UI na F3.

Relacionado: `database/schema.md`, `architecture/contracts.md`, `scoring.md`, ADR `0002`.
