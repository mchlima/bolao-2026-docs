# Deploy da API no VPS (Ubuntu 24.04 + Docker + Nginx)

Provisionamento passo a passo da **API** (`bolao-2026-api`) num VPS cru da Locaweb (2GB).
Stack conforme [`README.md`](./README.md): Docker Compose atrás de Nginx no host, banco
externo no Supabase, DNS/proxy no Cloudflare. A **web** vai separada na Vercel (Fase 8).

> Decisões desta configuração: **Ubuntu 24.04**, código via **deploy key (read-only)**,
> TLS de origem em **Cloudflare Flexible** (sem cert no VPS). Para endurecer depois, ver
> "Endurecer para Full (strict)" no fim.

Os comandos assumem login inicial como `root`. Em usuário comum, prefixe com `sudo`.

---

## Fase 1–2 — Bootstrap (segurança, swap, Docker, Nginx)

Automatizado em [`bootstrap.sh`](./bootstrap.sh) (idempotente, pode reexecutar):

```bash
# no VPS
curl -fsSLO https://raw.githubusercontent.com/mchlima/bolao-2026-docs/main/deploy/bootstrap.sh
# (ou scp do seu local) — então:
bash bootstrap.sh
```

O script faz: `ufw` (22/80/443), swap de 2GB, Docker + plugin Compose, e Nginx.
Conferência manual equivalente:

```bash
ufw status            # 22/80/443 allow, active
free -h               # Swap: 2.0Gi
docker compose version
systemctl is-active nginx
```

## Fase 3 — Deploy key + clone do repositório privado

```bash
ssh-keygen -t ed25519 -C "vps-bolao-deploy" -f ~/.ssh/id_ed25519 -N ""
ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
cat ~/.ssh/id_ed25519.pub          # copie a chave pública
```

No GitHub: **repo `bolao-2026-api` → Settings → Deploy keys → Add deploy key** → cole,
**sem** "Allow write access". Depois:

```bash
mkdir -p /opt && cd /opt
git clone git@github.com:mchlima/bolao-2026-api.git
cd /opt/bolao-2026-api
```

## Fase 4 — `.env` de produção

Reaproveite o `.env` local (já tem Supabase dual-URL + R2 reais). **Do seu workstation:**

```bash
scp bolao-2026-api/.env root@SEU_IP_VPS:/opt/bolao-2026-api/.env
```

No VPS, ajuste o que muda em produção:

```bash
cd /opt/bolao-2026-api
sed -i 's/^NODE_ENV=.*/NODE_ENV="production"/' .env
sed -i 's#^CORS_ORIGINS=.*#CORS_ORIGINS="https://bolao2026.kratinho.com.br"#' .env
sed -i "s#^JWT_SECRET=.*#JWT_SECRET=\"$(openssl rand -base64 36)\"#" .env
grep -E '^(NODE_ENV|CORS_ORIGINS|JWT_SECRET)=' .env
```

> O banco de produção é o **mesmo Supabase** já migrado/semeado, então `prisma migrate
> deploy` (rodado no start do container) é idempotente — **não há reseed**.

## Fase 5 — Subir a API

```bash
cd /opt/bolao-2026-api
docker compose up -d --build
docker compose logs -f          # aguarde "Nest application successfully started"
curl -s http://127.0.0.1:3000/api/health
```

## Fase 6 — Nginx (reverse proxy, porta 80)

```bash
cd /opt/bolao-2026-api
cp nginx/api.conf /etc/nginx/sites-available/bolao-api.conf
ln -sf /etc/nginx/sites-available/bolao-api.conf /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx
curl -s -H 'Host: api-bolao2026.kratinho.com.br' http://127.0.0.1/api/health
```

## Fase 7 — DNS no Cloudflare (zona `kratinho.com.br`)

- Registro **A**: `api-bolao2026` → **IP do VPS**, **proxy LIGADO (laranja)** — obrigatório
  para o Flexible aplicar o TLS público.
- **SSL/TLS → Flexible**.
- Teste externo: `curl -s https://api-bolao2026.kratinho.com.br/api/health`

## Fase 8 — Web na Vercel

- Importar `bolao-2026-web`.
- Env: `NUXT_PUBLIC_API_BASE=https://api-bolao2026.kratinho.com.br/api`
- Domínio `bolao2026.kratinho.com.br` (CNAME no Cloudflare conforme a Vercel indicar).

---

## Atualizar (deploy de nova versão)

```bash
cd /opt/bolao-2026-api
git pull
docker compose up -d --build
docker compose logs -f
```

## Endurecer para Full (strict) depois

1. Cloudflare → **Origin Server → Create Certificate** (cobre `api-bolao2026.kratinho.com.br`).
2. Salvar cert/key no VPS (ex.: `/etc/nginx/ssl/`), adicionar `listen 443 ssl;` +
   `ssl_certificate`/`ssl_certificate_key` no `api.conf`, redirect 80→443.
3. `nginx -t && systemctl reload nginx`.
4. Cloudflare **SSL/TLS → Full (strict)**.

## Troubleshooting

- **502 no Nginx:** container caiu ou ainda subindo — `docker compose ps`,
  `docker compose logs --tail=50`.
- **`ERR_TOO_MANY_REDIRECTS`:** algo forçando HTTPS na origem com Flexible — confirme que o
  `api.conf` não tem redirect 80→443 e que o app não força https.
- **CORS bloqueado:** `CORS_ORIGINS` no `.env` precisa bater com o domínio da web (https).
- **OOM no build:** confirme o swap (`free -h`); o `mem_limit: 1g` do compose preserva o Nginx.
- **Prisma "migrate" travando:** garanta que `DIRECT_URL` (5432) está no `.env`; o pooler
  6543 não serve para migrations.
