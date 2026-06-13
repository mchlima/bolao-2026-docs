# Spike: cartões da ESPN → desempate automático (fair play)

**Data:** 2026-06-13 · **Status:** investigação concluída — viável, aguardando green-light p/ implementar.

## Pergunta

O ranking dos **terceiros colocados** da Copa (e o desempate de grupo em geral) hoje vai só até
`pontos → saldo → gols → nome`. A Decisão #19 deixou **cartões e ranking-FIFA fora do modelo**
(override manual do admin no empate raro). Este spike responde: **o feed da ESPN entrega cartões
suficientes p/ automatizar o critério de _fair play_ da FIFA?**

Critério FIFA p/ ranquear os 8 melhores terceiros (e desempate de grupo), na ordem:
1. Pontos → 2. Saldo de gols → 3. Gols pró → **4. Pontos de fair play (disciplina)** → 5. Sorteio/ranking FIFA.

Pontos de fair play (por jogador, somados): amarelo simples **−1**, segundo amarelo (vermelho
indireto) **−3**, vermelho direto **−4**, amarelo + vermelho direto **−5**. Menos negativo = melhor.

## Achados

**1. Os cartões JÁ vêm no scoreboard que o robô lê a cada 15 s — sem chamada extra.**
`competition.details[]` (no mesmo `…/soccer/<slug>/scoreboard` que o `live-ingest` poll) traz cada
cartão com flags limpas:
```
{ type:{id:"94|93"}, yellowCard:true|false, redCard:true|false,
  team:{id}, athletesInvolved:[{ id, displayName, … }], clock, ... }
```
`type.id` 94 = amarelo, 93 = vermelho. (O `summary?event=` tem o mesmo em `keyEvents`, mais rico,
mas é uma chamada por jogo — desnecessário.)

**2. O `boxscore`/`standings` da ESPN NÃO agregam cartões.** O `standings` traz só
`gamesPlayed/wins/ties/losses/points/pointDifferential/rank` — **sem fair play**. Ou seja, a ESPN
não ranqueia disciplina por nós; **temos de computar**. (É exatamente a lacuna a fechar.)

**3. Segundo amarelo é inferível por jogador.** A ESPN não distingue "2º amarelo" de "vermelho
direto" pelo `type` (ambos viram `redCard:true`, id 93). Mas `athletesInvolved[].id` permite
rastrear a sequência por atleta: `Y` depois `R` no mesmo id = 2ª advertência (**−3**); `R` solto =
vermelho direto (**−4**); `Y` solto = **−1**. (O caso raro amarelo+vermelho-direto = −5 fica como
override admin.)

**4. Validado contra 4 jogos reais finalizados** (Copa, 2026-06-11/12), computando fair play do
feed:

| Jogo | Time | Amarelos | Vermelhos | Fair play |
|---|---|---|---|---|
| RSA @ MEX | MEX | 1 | 1 | −5 |
| RSA @ MEX | RSA | 2 | 2 | −10 |
| CZE @ KOR | KOR | 1 | 0 | −1 |
| BIH @ CAN | CAN | 2 | 0 | −2 |
| BIH @ CAN | BIH | 3 | 0 | −3 |
| PAR @ USA | PAR | 5 | 0 | −5 |
| PAR @ USA | USA | 1 | 0 | −1 |

(Sem 2º amarelo nesta amostra — todos os vermelhos foram diretos; a lógica por-atleta cobre o 2º
amarelo quando ocorrer.)

## Veredito

**Viável e barato.** Custo zero de chamadas extra à ESPN. A única peça que falta no nosso lado é
**persistir cartões por time/partida** (o schema do `Match` não tem campo de cartão hoje).

## Plano de implementação (quando aprovado)

1. **Schema** — em `Match`: `homeYellow/homeRed/awayYellow/awayRed Int @default(0)` (cru, p/ exibir)
   e `homeFairPlay/awayFairPlay Int @default(0)` (pontos FIFA já computados no ingest). Migração
   aditiva, segura no Supabase compartilhado.
2. **Robô `live-ingest`** — ao reconciliar um match, varrer `competition.details[]`, agrupar por
   `athletesInvolved[].id`, derivar amarelos/vermelhos e os pontos de fair play (lógica do achado 3)
   e gravar nos campos. Roda no mesmo tick; idempotente.
3. **`StandingsService`** — novo `Criterion` `FAIR_PLAY` nos `PRESET_CRITERIA` (FIFA já o inclui,
   após gols pró e antes do nome; `BRASILEIRAO` já o cita no comentário do preset).
4. **`slot-resolver` / `bestThirdLetter`** — inserir fair play no `sort` dos terceiros
   (`pontos → saldo → gols → **fair play** → nome`), substituindo o desempate por nome/override.
5. **Override admin permanece** p/ os casos que a ESPN não desambigua (amarelo+vermelho-direto = −5;
   ranking-FIFA como critério 5). Atualizar Decisão #19.

## Limites

- Depende da granularidade do feed da ESPN (em ligas menores os `details` podem faltar — degradar
  p/ contagem 0 + override).
- O −5 (amarelo + vermelho **direto** no mesmo jogador) não é distinguível do 2º amarelo só pelo
  feed; assumimos 2º amarelo (−3) e deixamos o admin corrigir o caso raro.
