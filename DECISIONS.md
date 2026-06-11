# Pendências técnicas a decidir

Registradas ao longo do design. Resolver e mover para os contratos/ADRs correspondentes.

| # | Pendência | Status | Decisão |
|---|---|---|---|
| 1 | **Valores numéricos** de cada tier de pontuação (`EXACT`/`ONE_TEAM_SCORE`/`OUTCOME`/`GOAL_DIFF`). Parametrizável é desejável. | ⏳ Aberta | — |
| 2 | **Estilo de paginação por tela**: offset+total (admin) vs cursor (feeds). | ⏳ Aberta | Esboço em `api/contracts.md` |
| 3 | **Intervalo de polling** das telas LIVE (placar + ranking provisório). | ⏳ Aberta | — |
| 4 | **"Gerar nova senha"**: exibir senha temporária **ou** disparar fluxo de redefinição (preferir o fluxo por segurança). | ⏳ Aberta | Recomendado: fluxo de redefinição |
| 5 | **Pódio no ranking da partida**: condicionar a um nº mínimo de participantes (evitar "pódio" com poucos palpites). | ⏳ Aberta | — |
| 6 | **Política de uso de escudos de clubes** (marca/IP). Fora do escopo técnico; registrar. | ⏳ Aberta | — |
| 7 | **Conjunto final de `TournamentStatus`** (além de `DRAFT`). | ⏳ Aberta | — |
| 8 | **Storage de objetos**: Cloudflare R2 vs S3. | ⏳ Aberta | — |
| 9 | **Nome final do app** ("Amigos do Bolão" a confirmar). | ⏳ Aberta | — |
| 10 | **Versão do Nuxt**: briefing pede Nuxt 3; tooling atual já default p/ Nuxt 4. Scaffold feito em **Nuxt 3** — confirmar se mantém. | ⏳ Aberta | Scaffold = Nuxt 3 |
| 11 | **Hash de senha**: bcrypt vs argon2. | ✅ Resolvida | **bcryptjs** (JS puro, 10 rounds) — sem compilação nativa, mantém a imagem Docker `node:slim` enxuta |
| 12 | **Regra de bloqueio de palpite** por `MatchStatus` (até kickoff? até LIVE?). | ⏳ Aberta | — |
