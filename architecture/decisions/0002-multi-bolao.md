# 2. Plataforma de Bolões (N:N usuário↔bolão)

Date: 2026-06-12

## Status

Accepted

## Context

O app nasceu como **um pool global**: todos os usuários veem a Copa e os dois rankings (partida e
torneio) somam todos os cadastrados. O produto desejado é **entre amigos** — vários grupos privados,
cada um disputando seu próprio ranking sobre um torneio do catálogo. Isso exige uma relação **N:N
usuário↔bolão** que hoje não existe (`Prediction` é único por `(userId, matchId)`, sem noção de
grupo).

A dúvida central era **onde mora o palpite**. Consideramos palpite por bolão (opção B) e um híbrido
(default na conta + override por bolão), mas a escolha final foi a mais simples: **palpite único e
global**, com o bolão atuando só como **grupo que escopa o ranking**.

## Decision

Virar para **N bolões**, onde `Bolão = (torneio do catálogo global) + (grupo de membros)`. Decisões:

- **Palpite único/global:** `Prediction` fica **inalterado** (`@@unique([userId, matchId])`). O bolão
  **não tem palpite próprio** — palpita-se 1x na página do torneio e vale em todos os bolões daquele
  torneio. (Descartados: opção por-bolão e o híbrido com `PredictionOverride` — o usuário optou pela
  simplicidade.)
- **Bolão = grupo que filtra o ranking:** o ranking do bolão é o mesmo do torneio com a entrada
  filtrada aos membros; `RankingsService.buildResponse` ganha um filtro opcional de `memberUserIds`.
  A visão **global** (todos) permanece na página do torneio. `ScoringService` intacto.
- **Convite por links nomeados** (entidade `PoolInvite`, estilo WhatsApp): o dono/admin cria e
  administra N links (nome + `code` revogável), não um código fixo no bolão. Futuro: QR code e
  e-mail entram na mesma entidade.
- **Papéis OWNER/ADMIN/MEMBER:** o dono promove/rebaixa admin; admin gere membros, links e metadados
  do bolão; só o dono deleta/transfere. Matriz completa em `architecture/multi-bolao.md`.
- **Nomenclatura:** a UI em pt-BR diz "bolão"; no código/banco a entidade é **`Pool`** (regionalismo
  BR → termo neutro). Tabelas `pools`/`pool_members`/`pool_invites`.
- **Copa global atual:** nada a migrar — a visão global permanece na página do torneio; um bolão é
  opt-in/aditivo (a turma cria um se quiser um grupo privado).
- **Privado por padrão** (só convite) no MVP; `visibility` deixa a porta aberta p/ públicos.

Catálogo de torneios continua global/administrado pelo admin (usuário cria bolão *sobre* torneios,
não cria torneio). Detalhe e fases em `architecture/multi-bolao.md`.

## Consequences

- Novos modelos `Pool`, `PoolMember` e `PoolInvite`; `Prediction` **inalterado** (sem tabela de
  override, sem troca de unique). Migração **puramente aditiva** (cria 3 tabelas) — não toca palpites
  (risco baixo no Supabase compartilhado).
- Backend: `PoolModule` + autorização por membro; `RankingsService` ganha filtro opcional de
  membros. `PredictionsService` **não muda**.
- Frontend: "meus bolões" vira a home; página do bolão = ranking escopado; o palpitar continua na
  página do torneio. Roteamento `/b/:id`.
- Reaproveitado sem mudança: palpites, motor de scoring, algoritmo de ranking, todo o admin, robô
  ESPN/SSE.
- Supersedido o pressuposto de "pool global único" do briefing original.
