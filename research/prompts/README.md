# Research agent prompts

Used by [`docs/weekly-refresh.md`](../../docs/weekly-refresh.md). Fill the `{{…}}` placeholders and save each rendered prompt beside the run's outputs.

- `collector.md` + `exemplar.md`: collect what each gym published since the last refresh. Append the exemplar to the rendered prompt.
- `ocf.md`: check the Climb Ontario index and every upcoming individual event page, once centrally per run, with separate source checkpoints and per-event coverage.
- `importer.md`: turn each gym's capture into unapproved candidates. The coordinator combines and validates them in isolation, then presents one final approval list.

Start from the private data repo's `betasheet/refresh-state.json`, including publication receipts and unresolved work. The weekly runbook owns the end-to-end process; these prompts define collector responsibilities within it.

Keep prompts short: goal first, then the few rules that matter. When an agent goes wrong, add one concrete line or example rather than a long prohibition list.
