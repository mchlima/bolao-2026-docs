# bolao-2026-docs

Documentação viva do **Bolão 2026** ("Amigos do Bolão" — nome a confirmar), app web de bolão
esportivo multi-torneio (Copa do Mundo 2026, Libertadores, Brasileirão, etc.).

Este repositório é a **fonte da verdade**: `bolao-2026-api` e `bolao-2026-web` referenciam os
contratos definidos aqui (enums, formato de erro, paginação, regra de pontuação, schema).

> Convenção inegociável: **todo código e estrutura de dados em inglês** (variáveis, campos,
> enums, tabelas). Textos de UI em **português do Brasil**.

## Estrutura

| Pasta | Conteúdo |
|---|---|
| [`product/`](./product) | Especificação funcional + visual (telas, regras, identidade "Estádio 26") |
| [`architecture/`](./architecture) | Briefing técnico, diagramas, decisões (ADRs) |
| [`api/`](./api) | Contratos: enums, formato de erro, paginação, endpoints, regra de pontuação |
| [`database/`](./database) | Schema Prisma comentado + diagrama ER |
| [`deploy/`](./deploy) | Guia de deploy (Vercel, VPS Docker/Nginx, Supabase, Cloudflare DNS/SSL) |

## Topologia de repositórios

| Repo | Papel | Stack | Deploy |
|---|---|---|---|
| `bolao-2026-docs` | Documentação viva | Markdown | — |
| `bolao-2026-api` | Backend / API REST | NestJS + Prisma (Docker) | VPS Locaweb |
| `bolao-2026-web` | Frontend | Nuxt 3 | Vercel |

## Protótipo visual de referência

Claude Design (referência canônica de layout e identidade visual aprovada):
<https://api.anthropic.com/v1/design/h/uH_LKnJREAkR8Mw4s0jG9g?open_file=Amigos+do+Bol%C3%A3o.dc.html>

Quando houver divergência: o **protótipo prevalece para o visual**; o **texto/produto prevalece
para regras de negócio**.

## Pendências técnicas

Ver [`DECISIONS.md`](./DECISIONS.md).
