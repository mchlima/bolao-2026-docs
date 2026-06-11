# Pendências técnicas a decidir

Registradas ao longo do design. Resolver e mover para os contratos/ADRs correspondentes.

| # | Pendência | Status | Decisão |
|---|---|---|---|
| 1 | **Valores numéricos** de cada tier de pontuação. | ✅ Resolvida (revista) | **Modelo B (proximidade):** acertou o vencedor → base **4**; por time: cravou +3, errou por 1 +1; errou o vencedor → 0 (cravar = 10). Tiers viraram rótulos: `EXACT`/`ONE_TEAM_SCORE`/`CLOSE`/`OUTCOME`/`NONE`. Env `SCORING_BASE`/`TEAM_EXACT`/`TEAM_NEAR`. **Desempate:** palpite mais antigo (`createdAt`) acima. Substituiu o esquema em camadas. Ver `api/scoring.md` |
| 2 | **Estilo de paginação por tela**: offset+total (admin) vs cursor (feeds). | ⏳ Aberta | Esboço em `api/contracts.md` |
| 3 | **Intervalo de polling** das telas LIVE (placar + ranking provisório). | ✅ Resolvida (revista) | **Removido** (a pedido): o auto-refresh saiu de todas as telas; atualização ao vivo agora é manual (recarregar). `useLivePolling`/`LIVE_POLL_MS` deletados. |
| 4 | **"Gerar nova senha"**: exibir senha temporária **ou** disparar fluxo de redefinição. | 🟡 Parcial | MVP: **gera senha temporária** retornada 1x ao admin (sem serviço de e-mail ainda). Senha **não** vai para o audit log. Migrar p/ fluxo de reset-link quando houver e-mail. |
| 5 | **Pódio no ranking**: condicionar a um nº mínimo de participantes. | ✅ Resolvida | Pódio só aparece com **≥ 3 participantes** (ranking do torneio e da partida); abaixo disso, lista simples. |
| 6 | **Política de uso de escudos de clubes** (marca/IP). Fora do escopo técnico; registrar. | ⏳ Aberta | — |
| 7 | **Conjunto final de `TournamentStatus`** (além de `DRAFT`). | ⏳ Aberta | — |
| 8 | **Storage de objetos**: Cloudflare R2 vs S3. | ✅ Resolvida | **Cloudflare R2** (S3-compatible). Backend gera URLs e otimiza imagens (`sharp`→WebP). Vars `STORAGE_*` no `.env`. |
| 9 | **Nome final do app** ("Amigos do Bolão" a confirmar). | ⏳ Aberta | — |
| 10 | **Versão do Nuxt**: briefing pede Nuxt 3; tooling atual já default p/ Nuxt 4. Scaffold feito em **Nuxt 3** — confirmar se mantém. | ⏳ Aberta | Scaffold = Nuxt 3 |
| 11 | **Hash de senha**: bcrypt vs argon2. | ✅ Resolvida | **bcryptjs** (JS puro, 10 rounds) — sem compilação nativa, mantém a imagem Docker `node:slim` enxuta |
| 12 | **Regra de bloqueio de palpite** por `MatchStatus` (até kickoff? até LIVE?). | ✅ Resolvida (revista) | Automático: aceita se `SCHEDULED` E `now < kickoffAt` E times definidos. **Override manual** `Match.predictionsOpen` (true/false força aberto/fechado; null = automático), controlável no ao vivo **mesmo em LIVE**; estados terminais nunca aceitam. Códigos `PREDICTION_LOCKED` / `MATCH_NOT_OPEN` |
| 13 | **Times da partida nullable** (briefing assumia obrigatório). Necessário p/ mata-mata "a definir". | ✅ Resolvida | `homeTeamId`/`awayTeamId` nullable + `homeSourceLabel`/`awaySourceLabel` (slot TBD). Palpite só liberado quando os dois times estão definidos. |
| 14 | **Horários de kickoff da Copa** (grupos derivados/fuso; mata-mata placeholder). | 🟡 Parcial | Aplicado **+1h** em todos (estavam 1h adiantados, confirmado pelo usuário). UTC no banco; exibição no **fuso da conta** (`User.timezone`, default `America/Sao_Paulo`). Ainda best-effort — admin pode ajustar por partida. |
| 15 | **Deploy e região do banco.** | ✅ Resolvida | API em **VPS Locaweb (São Paulo)** via Docker Compose + Nginx, atrás do Cloudflare (**Flexible**); web na **Vercel**; domínios `bolao2026`/`api-bolao2026` em `kratinho.com.br`. Banco **migrado `us-east-1` → `sa-east-1`** por latência (131ms → ~2ms RTT). Ver `deploy/vps-ubuntu.md`. |
| 16 | **Placar parcial ao vivo com lado `null`.** | ✅ Resolvida | Em `LIVE`/`FINISHED`, um placar `null` conta como **0** (ex.: 1-0 com o visitante intocado) — rankings provisórios e exibição (card/detalhe) usam o placar coalescido. |
