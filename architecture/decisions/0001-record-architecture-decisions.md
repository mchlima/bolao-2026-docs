# 1. Registrar decisões de arquitetura (ADRs)

Date: 2026-06-11

## Status

Accepted

## Context

O projeto envolve três repositórios e várias decisões transversais (auth, storage, polling vs
realtime, paginação, valores de pontuação). Precisamos de um registro durável e versionado das
decisões e seu racional.

## Decision

Usar ADRs (Architecture Decision Records) curtos em `architecture/decisions/`, numerados
sequencialmente, no formato Context / Decision / Consequences.

## Consequences

- Decisões ficam rastreáveis e revisáveis junto ao código de docs.
- Mudanças de rumo viram novos ADRs que supersedem os anteriores (status `Superseded by NNNN`).
