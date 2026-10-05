# Research agent prompts

Used by [`docs/weekly-refresh.md`](../../docs/weekly-refresh.md). Fill the `{{…}}` placeholders and save each rendered prompt beside the run's outputs.

- `collector.md` + `exemplar.md`: collect what each gym published since the last refresh. Append the exemplar to the rendered prompt.
- `ocf.md`: reconcile every OCF competition with the Climb Ontario calendar, once per run.
- `importer.md`: turn each gym's capture into catalogue changes and import them into dev, gym by gym.

Keep prompts short: goal first, then the few rules that matter. When an agent goes wrong, add one concrete line or example rather than a long prohibition list.
