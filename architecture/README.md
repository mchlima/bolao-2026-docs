# Arquitetura — Bolão 2026

App web de bolão esportivo multi-torneio. Três repositórios independentes (owner `mchlima`):
`bolao-2026-docs`, `bolao-2026-api`, `bolao-2026-web`.

## Infraestrutura

```
              Cloudflare (DNS + proxy)
                       │
        ┌──────────────┴───────────────┐
        │                              │
  bolao2026.kratinho.com.br     api-bolao2026.kratinho.com.br
   (Vercel — Nuxt 3)              (VPS Locaweb — NestJS/Docker)
                                       │
                                  Supabase (Postgres)
                                  via Prisma + pooler
```

### Domínios

- **Web:** `bolao2026.kratinho.com.br` → Vercel (CNAME).
- **API:** `api-bolao2026.kratinho.com.br` → IP do VPS Locaweb (registro A).
- **Zona DNS:** Cloudflare (`kratinho.com.br`).
- **SSL mode no Cloudflare:** **Full (strict)** — evita `ERR_TOO_MANY_REDIRECTS` (há histórico
  desse problema; usar Configuration Rules por hostname se necessário).
- **CORS:** API libera origem `https://bolao2026.kratinho.com.br`. Cookies/JWT considerando o
  cross-subdomain.

### Componentes

- **Frontend (Vercel):** Nuxt 3, deploy automático via integração GitHub de `bolao-2026-web`.
- **Backend (VPS Locaweb, 2GB RAM):** NestJS **containerizado com Docker**, atrás de Nginx
  (reverse proxy). Como o banco saiu para o Supabase, o VPS hospeda **apenas a aplicação**.
- **Banco (Supabase):** apenas Postgres gerenciado. **Sem** Supabase Auth/Realtime/Storage —
  auth fica no NestJS.
- **Storage de imagens:** objeto (Cloudflare R2 ou S3) para escudos de clubes e logos de
  torneio. Backend gera URLs e otimiza imagens (`sharp` → WebP).

## Decisões transversais

- Auth próprio: JWT + `passwordHash` (bcrypt/argon2). Sem Supabase Auth.
- Atualização "ao vivo" **sem WebSocket**: front faz **polling/refetch** nas telas LIVE.
  Domínio desenhado para reintroduzir realtime depois sem reescrita.
- **Audit log** para ações sensíveis do admin (imutável, com ator e diffs de campo).
- Regra de pontuação **centralizada** num único `ScoringService` (ver [`../api/scoring.md`](../api/scoring.md)).

## ADRs

Decisões arquiteturais registradas em [`decisions/`](./decisions).
