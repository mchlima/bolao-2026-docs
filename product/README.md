# Produto — Bolão 2026

> **Placeholder.** A especificação funcional + visual completa (o "documento de produto") deve
> ser colada/importada aqui: telas, fluxos, regras de pontuação descritas para o usuário,
> identidade visual "Estádio 26".

## Referência canônica de visual

Protótipo Claude Design ("Amigos do Bolão"):
<https://api.anthropic.com/v1/design/h/uH_LKnJREAkR8Mw4s0jG9g?open_file=Amigos+do+Bol%C3%A3o.dc.html>

O frontend (`bolao-2026-web`) deve seguir este protótipo como referência de layout, componentes
e identidade visual. Em divergência texto×protótipo, o **protótipo prevalece para o visual**.

## Identidade visual "Estádio 26"

- Paleta e tokens: ver protótipo.
- Temas: **dark / light / system** (toggle no menu do avatar, preferência persistida).
- **Mobile-first em todo o app**, inclusive admin.

## Imagens

- **Seleções:** bandeiras via lib `country-flag-icons` (SVG inline). Sem upload.
- **Clubes:** escudo via `logoUrl` (upload pelo admin → storage de objetos).
- **Torneios:** logo via upload.
- **Fallback:** avatar com iniciais.
