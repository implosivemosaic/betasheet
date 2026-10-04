# Beta Sheet

Find your next climb. A small Phoenix LiveView site over a curated catalogue of competitions,
socials, classes and camps gathered from gyms across Ontario and the Ontario Climbing Federation.

- Live: https://betasheet.ca
- Data and research (private): https://github.com/implosivemosaic/betasheet-data
- Start with `AGENTS.md`; then `docs/research-rules.md`, `docs/weekly-refresh.md`, `docs/operations.md`
- App design: `docs/features.md`, `docs/architecture-c1c2.md`, `docs/architecture-c3.md`

## Quick start

```
source bin/ex-env.sh
mix setup
python3 research/run.py dev         # local database = newest production snapshot (needs betasheet-data)
PORT=4200 mix phx.server
```
