#!/usr/bin/env bash
# Bolão 2026 — VPS bootstrap (Ubuntu 24.04). Idempotent: safe to re-run.
# Provisions Fases 1–2 of deploy/vps-ubuntu.md: firewall, swap, Docker, Nginx.
# Run as root (or with sudo). Does NOT touch the app — see vps-ubuntu.md Fase 3+.
set -euo pipefail

SWAP_SIZE="${SWAP_SIZE:-2G}"
SWAPFILE="/swapfile"

log() { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root or with sudo." >&2
  exit 1
fi

# ─────────────── Fase 1a: firewall ───────────────
log "Firewall (ufw): allow OpenSSH/80/443"
apt-get update -y
apt-get install -y ufw
ufw allow OpenSSH
ufw allow 80
ufw allow 443
ufw --force enable
ufw status

# ─────────────── Fase 1b: swap ───────────────
if swapon --show | grep -q "${SWAPFILE}"; then
  log "Swap already active (${SWAPFILE}) — skipping"
elif [[ -f "${SWAPFILE}" ]]; then
  log "Swapfile exists but inactive — enabling"
  swapon "${SWAPFILE}"
else
  log "Creating ${SWAP_SIZE} swap at ${SWAPFILE}"
  fallocate -l "${SWAP_SIZE}" "${SWAPFILE}" || dd if=/dev/zero of="${SWAPFILE}" bs=1M count=2048
  chmod 600 "${SWAPFILE}"
  mkswap "${SWAPFILE}"
  swapon "${SWAPFILE}"
fi
if ! grep -q "^${SWAPFILE} " /etc/fstab; then
  echo "${SWAPFILE} none swap sw 0 0" >> /etc/fstab
fi
free -h

# ─────────────── Fase 2a: Docker + Compose plugin ───────────────
if command -v docker >/dev/null 2>&1; then
  log "Docker already installed — skipping"
else
  log "Installing Docker (+ compose plugin) via get.docker.com"
  curl -fsSL https://get.docker.com | sh
fi
systemctl enable --now docker
docker --version
docker compose version

# ─────────────── Fase 2b: Nginx ───────────────
log "Installing Nginx"
apt-get install -y nginx
systemctl enable --now nginx
systemctl is-active nginx

log "Bootstrap complete. Next: deploy/vps-ubuntu.md Fase 3 (deploy key + clone)."
