# Climb Ontario

What's on in Ontario climbing, near you. A small Phoenix LiveView site over a curated catalogue
of competitions, socials, classes and camps gathered from 54 gyms and the Ontario Climbing Federation.

- Tailnet preview: https://dot-keith.taild1c720.ts.net:8445/
- Docs: `docs/architecture-c1c2.md`, `docs/architecture-c3.md`, `docs/operations.md`, `docs/features.md`
- Agent notes: `AGENTS.md`

## Quick start

```
source bin/ex-env.sh
mix setup
mix catalogue.build
PORT=4200 mix phx.server
```
