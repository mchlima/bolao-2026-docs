# Pendências técnicas a decidir

Registradas ao longo do design. Resolver e mover para os contratos/ADRs correspondentes.

| # | Pendência | Status | Decisão |
|---|---|---|---|
| 1 | **Valores numéricos** de cada tier de pontuação. | ✅ Resolvida | `EXACT`=10, `ONE_TEAM_SCORE`=5, `GOAL_DIFF`=4, `OUTCOME`=3, `NONE`=0 (saldo acima de vencedor). Parametrizável via env `SCORING_*`. Ver `api/scoring.md` |
| 2 | **Estilo de paginação por tela**: offset+total (admin) vs cursor (feeds). | ⏳ Aberta | Esboço em `api/contracts.md` |
| 3 | **Intervalo de polling** das telas LIVE (placar + ranking provisório). | ⏳ Aberta | — |
| 4 | **"Gerar nova senha"**: exibir senha temporária **ou** disparar fluxo de redefinição. | 🟡 Parcial | MVP: **gera senha temporária** retornada 1x ao admin (sem serviço de e-mail ainda). Senha **não** vai para o audit log. Migrar p/ fluxo de reset-link quando houver e-mail. |
| 5 | **Pódio no ranking da partida**: condicionar a um nº mínimo de participantes (evitar "pódio" com poucos palpites). | ⏳ Aberta | — |
| 6 | **Política de uso de escudos de clubes** (marca/IP). Fora do escopo técnico; registrar. | ⏳ Aberta | — |
| 7 | **Conjunto final de `TournamentStatus`** (além de `DRAFT`). | ⏳ Aberta | — |
| 8 | **Storage de objetos**: Cloudflare R2 vs S3. | ✅ Resolvida | **Cloudflare R2** (S3-compatible). Backend gera URLs e otimiza imagens (`sharp`→WebP). Vars `STORAGE_*` no `.env`. |
| 9 | **Nome final do app** ("Amigos do Bolão" a confirmar). | ⏳ Aberta | — |
| 10 | **Versão do Nuxt**: briefing pede Nuxt 3; tooling atual já default p/ Nuxt 4. Scaffold feito em **Nuxt 3** — confirmar se mantém. | ⏳ Aberta | Scaffold = Nuxt 3 |
| 11 | **Hash de senha**: bcrypt vs argon2. | ✅ Resolvida | **bcryptjs** (JS puro, 10 rounds) — sem compilação nativa, mantém a imagem Docker `node:slim` enxuta |
| 12 | **Regra de bloqueio de palpite** por `MatchStatus` (até kickoff? até LIVE?). | ✅ Resolvida | Trava no **início da partida**: aceita só se `SCHEDULED` E `now < kickoffAt` E ambos os times definidos. Códigos `PREDICTION_LOCKED` / `MATCH_NOT_OPEN` |
| 13 | **Times da partida nullable** (briefing assumia obrigatório). Necessário p/ mata-mata "a definir". | ✅ Resolvida | `homeTeamId`/`awayTeamId` nullable + `homeSourceLabel`/`awaySourceLabel` (slot TBD). Palpite só liberado quando os dois times estão definidos. |
| 14 | **Horários de kickoff da Copa** (grupos derivados/fuso; mata-mata placeholder). | ⏳ Aberta | Revisar contra FIFA antes do go-live |
