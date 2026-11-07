# Feature map template

A `verify-<app>/features/` folder holds one `README.md` index and one file per
user-facing feature. Copy the two blocks below and replace every `<...>` with
real values from the repo. The example after them shows a filled-in feature.

## `features/README.md`

```markdown
# <App> verification map

The maintained source for proving what <App> does for a user. Read this index
before you drive the app, then use the matching feature file as the recipe.

## Baseline
- Launch: see the Launch section of `../SKILL.md`. It starts on `<url / port / binary>`
  with a disposable data dir `<private run dir, e.g. RUN_DIR=$(mktemp -d)>`.
- Seed data: <what exists after Launch, e.g. user `demo@example.test`, 2 projects>.
- Run Doctor before the first drive. Drive only the instance this run started.
  If another instance holds the port or data dir (e.g. your own dev server),
  stop and ask — never stop an instance this run did not start.

## Driving rules
- Start each recipe from the baseline unless its preconditions say otherwise.
- Use stable handles (<accessible names / test IDs / routes / CLI flags>), not
  coordinates or element order.
- Treat every command as literal.
- Undo mutations to seed data after the recipe. Keep the evidence.

## Proof rules
- Capture the action and the resulting state, not only the final screen.
- Assert exact results (counts, values, exit codes), so an ignored input fails the proof.
- UI proof: <accessibility snapshot + screenshot>. CLI proof: command, stdout,
  stderr, exit code. Mutation proof: a second, read-only view of the stored value.
- Name the feature ID and the entry point on every artifact.
- Report an entry point you could not reach with the command you tried and the
  missing precondition. Never report it as proven through a different entry point.

## Feature file shape
An H1 title, one paragraph on what the user sees, a `Source:` line naming the
files that hold the feature's entry points (routes, commands — files only, no
implementation detail; maintain passes start there), then exactly these H2s in
order (`<harness>` is the tool you drive it with, e.g. `Playwright` or
`curl and the CLI`):
1. `Sub-features` — short IDs, one line each.
2. `How to get to it (user POV)` — every entry point a user has.
3. `Driving it with <harness>` — starts with `Preconditions:`, then labelled
   steps: user action → exact command → observable result.
4. `Gotchas` — traps that waste or invalidate a run.

Keep implementation detail out. Name only user paths, handles, state, commands,
and proof.

## Features
- [<Feature>](./<feature>.md) — <one line on what it covers>.
```

## `features/<feature>.md`

```markdown
# <Feature>

<One paragraph: what the user can do and what they see when it works.>

Source: `<file with the route/command>`, `<...>`

## Sub-features
- `<id>` — <one behaviour>.

## How to get to it (user POV)
- <Entry point 1, e.g. the `Export` button on the report page>.
- <Entry point 2, e.g. `<cli> export --format csv`>.

## Driving it with <harness>
Preconditions:
- <State the recipe needs, e.g. Doctor passes; report `Q1` exists>.

- **<Step>.** <User action>. Run `<exact command>`. <Exact observable result>.
- **<Error path>.** <Bad input or missing item>. Run `<exact command>`. <The error the user sees>.
- **Proof.** Run `<capture command> --path <evidence path>`. <What the artifact shows>.

## Gotchas
- <Trap, e.g. the button is disabled until the totals finish loading>.
```

## Example: a filled-in feature

```markdown
# Export a report

A user exports the current report as CSV from the web UI or the CLI, and the
file holds one row per line item with the same totals the page shows.

Source: `src/routes/reports/[id].tsx`, `cli/commands/export.ts`

## Sub-features
- `export-web` — the `Export CSV` button downloads the file.
- `export-cli` — `reports export` writes the same file from a terminal.
- `export-empty` — exporting an empty report gives a header-only file.

## How to get to it (user POV)
- Open a report and choose `Export CSV`.
- Run `reports export --id <id> --out <file>`.

## Driving it with Playwright
Preconditions:
- Doctor passes; seed report `Q1` (id `r-1`) has 3 line items totalling `1,250.00`.

- **Open the report.** Go to `/reports/r-1`. The heading reads `Q1` and the
  total cell (`getByTestId('report-total')`) reads `1,250.00`.
- **Export.** Choose `getByRole('button', { name: 'Export CSV' })` and wait for
  the download. The file `Q1.csv` has a header and 3 rows.
- **Check the totals.** Sum the `amount` column. It equals `1,250.00`.
- **CLI entry.** Run `reports export --id r-1 --out "$RUN_DIR/q1-cli.csv"`.
  Exit code `0`; the file is identical to the web download.
- **Unknown report.** Run `reports export --id r-404 --out "$RUN_DIR/missing.csv"`.
  Exit code `1`, stderr `report r-404 not found`, and no file is written.
- **Proof.** Save the page screenshot, both CSV files, and the CLI transcript
  under `$RUN_DIR/evidence/export/`.

## Gotchas
- `Export CSV` stays disabled until the totals load. Wait for the total cell,
  not a fixed delay.
- The CLI writes amounts without thousands separators. Compare numbers, not text.
```
