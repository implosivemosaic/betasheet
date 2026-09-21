# Beta Sheet

Find your next climb. A small Phoenix LiveView site over a curated catalogue of competitions,
socials, classes and camps gathered from gyms across Ontario and the Ontario Climbing Federation.

- Live: https://betasheet.ca
- Data and research (private): https://github.com/implosivemosaic/betasheet-data
- Docs: `docs/architecture-c1c2.md`, `docs/architecture-c3.md`, `docs/operations.md`, `docs/features.md`
- Agent notes: `AGENTS.md`

## Quick start

```
source bin/ex-env.sh
mix setup
mix catalogue.seed                  # venues + unpublished skeletons
mix run priv/repo/examples.exs      # the three agreed example listings
PORT=4200 mix phx.server
```
