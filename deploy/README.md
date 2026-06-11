# Deploy — Bolão 2026

## Visão geral

| Componente | Onde | Como |
|---|---|---|
| Web (Nuxt 3) | Vercel | Integração GitHub de `bolao-2026-web`, deploy automático |
| API (NestJS) | VPS Locaweb (2GB) | Docker + `docker compose`, atrás de Nginx |
| Banco | Supabase | Postgres gerenciado, acessado via Prisma + pooler |
| DNS/Proxy | Cloudflare | Zona `kratinho.com.br` |
| Storage imagens | Cloudflare R2 / S3 | Escudos de clubes + logos de torneio |

## DNS (Cloudflare — zona `kratinho.com.br`)

- `bolao2026` → **CNAME** para o alvo da Vercel.
- `api-bolao2026` → **A** para o IP do VPS Locaweb (proxy do Cloudflare conforme necessário).
- **SSL mode: Full (strict)** para evitar `ERR_TOO_MANY_REDIRECTS`. Se preciso, usar
  **Configuration Rules por hostname**.

## Supabase + Prisma (dual-URL)

```
DATABASE_URL="postgres://postgres.<ref>:<pwd>@aws-0-<region>.pooler.supabase.com:6543/postgres?pgbouncer=true"
DIRECT_URL="postgres://postgres.<ref>:<pwd>@aws-0-<region>.pooler.supabase.com:5432/postgres"
```

- `DATABASE_URL` (pooler 6543, `pgbouncer=true`) → Prisma Client em runtime.
- `DIRECT_URL` (direta 5432) → **apenas** Prisma CLI (`migrate`, `introspect`). Migrations via
  6543 travam.
- `schema.prisma` → `url = env("DATABASE_URL")`, `directUrl = env("DIRECT_URL")`.
- **Prisma 6.x:** conferir se a versão lê o direct URL via `prisma.config.ts` em vez do schema.

## VPS (Docker + Nginx)

1. `git pull` (ou pull de imagem do registry).
2. `docker compose pull && docker compose up -d` (ou build no VPS).
3. **Migrations:** `prisma migrate deploy` (usa `DIRECT_URL`) no startup do container ou como
   passo de deploy. **Nunca `migrate dev` em produção.**
4. Nginx (host ou container) faz reverse proxy para a porta da API; encerra o tráfego do
   Cloudflare. Headers `X-Forwarded-*` corretos.
5. Limitar memória do container (`mem_limit`) e o pool do Prisma; considerar **swap** no VPS.

Exemplo de Nginx em `bolao-2026-api/nginx/api.conf`.

## CI/CD (sugerido)

GitHub Actions: build da imagem → push para registry → no VPS `docker compose pull && up -d`.
Alternativa: build no próprio VPS. Detalhar quando o pipeline for definido.

## Vercel (web)

- Importar `bolao-2026-web` na Vercel.
- Env: `NUXT_PUBLIC_API_BASE=https://api-bolao2026.kratinho.com.br`.
- Domínio `bolao2026.kratinho.com.br` (CNAME no Cloudflare, proxy conforme Vercel recomendar).
