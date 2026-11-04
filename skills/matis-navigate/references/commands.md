# Matis navigation commands

All graph commands output JSON on stdout by default. Errors go to stderr with a nonzero exit code. Run `matis graph --help` and the subcommand's `--help` when unsure. Only `source` supports `--format text` for numbered excerpts with metadata.

Before project discovery, check whether the database exists without opening or creating it. Use the Matis environment's Python if `python3` is unavailable:

```sh
python3 -c 'import os; from pathlib import Path; p=Path(os.environ["DATABASE_PATH"]).expanduser() if os.environ.get("DATABASE_PATH") else Path(os.environ.get("XDG_DATA_HOME") or Path.home()/".local/share").expanduser()/"matis/matis.sqlite"; print(p); raise SystemExit(0 if p.is_file() else 1)'
```

If this command exits with a nonzero code, do not run `matis projects`. It can create an empty database. Explain the prerequisite or use local file navigation instead. If the database exists, start inside the intended indexed checkout:

```sh
matis graph overview
matis graph find 'save_folder' --limit 5
```

Use `matis projects` and `matis graph --project "$PROJECT" overview` when outside the checkout or when its registration is ambiguous. Confirm the folder and identity in the overview before using the graph.

Select an exact key from `find`. Do not select only by match order. Record its graph revision and use it to keep later queries consistent:

```sh
matis graph --project "$PROJECT" --revision "$REVISION" show "$KEY"
matis graph --project "$PROJECT" --revision "$REVISION" children "$KEY" --limit 30
matis graph --project "$PROJECT" --revision "$REVISION" context "$KEY" \
  --direction out --relations CALLS,REFERENCES --depth 1 --max-nodes 12 --max-edges 30
matis graph --project "$PROJECT" --revision "$REVISION" context "$KEY" \
  --direction in --relations CALLS,REFERENCES --depth 1
matis graph --project "$PROJECT" --revision "$REVISION" source "$KEY" --max-lines 80
matis graph --project "$PROJECT" --revision "$REVISION" source "$KEY" "$OTHER_KEY" --format text
matis graph --project "$PROJECT" --revision "$REVISION" path "$FROM" "$TO"
```

`--project` is optional inside an indexed folder or any of its subdirectories. `matis graph overview` and `matis graph find 'save_folder'` infer the nearest containing registered folder. From elsewhere, or when that folder has multiple registrations, use `--project` with an explicit registered name or ID. If no registration matches, the command returns an error that explains what to do. Navigation never indexes automatically. `--revision` is optional on the first query and recommended on later queries. Put group options before the subcommand. Keep `DATABASE_PATH` unchanged between indexing and querying. Otherwise, Matis uses its user-data database.

| Command | Purpose |
|---|---|
| `overview` | Show index identity, coverage and counts. Give an initial view of the project. |
| `find QUERY` | Search names, qualified names or paths within a limit. This is not semantic search. |
| `show KEY` | Show declaration details and containment ancestors. |
| `children KEY` | Show immediate children within a limit, not all descendants. |
| `context KEY` | Show a dependency neighborhood within limits, with relationship evidence. |
| `source KEY...` | Show local source for one or more declarations or files after checking its hash. |
| `path FROM TO` | Find a directed relationship path within limits. This is not an execution trace. |

Context directions are `out`, `in`, and `both`. The default relations are `CALLS,REFERENCES`. Select `IMPORTS` for file or module dependencies and `INHERITS` for type relationships. Keep type-only dependencies distinct from runtime dependencies. Keep unresolved targets distinct from resolved targets. Use `children` to explore structure. Do not add containment to a behavioral trace.

Every successful response includes `repositoryId`, `graphRevision`, `indexedAt`, effective `filters`, `diagnostics` scoped to paths, and `diagnosticsTruncated`. Inspect these fields and `truncated` every time. `show.ancestors` lists the nearest parent first. `context.boundaries` gives `stableKey`, `reason`, and `expandable`. Expand only relevant keys. A `path.status` of `unknown` means that limits prevented the search from ruling out a connection. `not_found` applies only to the selected static relations.

Read `children` in pages. Pass its returned `nextOffset` to `--offset`. Read `source` in pages. Pass `source.nextStartLine` to `--start-line`. This is an absolute, 1-based line number within the symbol or file bounds. Only `source.status: ok` returns verified `lines`, `startLine`, `endLine`, `truncated`, and `nextStartLine`. Other statuses include `changed`, `missing`, `unsafe`, `unreadable`, `unverified`, `unavailable`, `unsupported_encoding`, `span_unavailable`, and `too_large`. For these statuses, use the fallback rules in the skill. Source reads have limits of 8 MiB per file and 16 KiB of excerpt text. `too_large` returns these byte limits without source lines. For an oversized excerpt, retry with fewer lines or read the relevant current source with ordinary tools and bounded reads. Never treat truncated evidence as a complete function body.

Source JSON for a single key retains its `source` object. Multiple keys return ordered `sources` entries. Each entry has `stableKey` and the same fields for each excerpt. The entries share graph metadata and diagnostics. `--max-lines` and `--start-line` apply to each excerpt. Inspect each status. Read individual keys in pages using each key's own `nextStartLine`. Unknown keys cause the command to fail. Verification failures remain statuses for individual excerpts. `--format text` retains snapshot and excerpt metadata alongside numbered lines.

To investigate behavior, prefer concrete `find --limit 5` queries, focused context, and batched `source --format text` over broad graphs. Search paths with positional query text, for example `matis graph --revision "$REVISION" find 'worker/scheduler.ts' --limit 5`. `find` has no `--path` filter. For a symbol, search its concrete name and inspect the returned paths. Do not assume that name and path filters can be combined. You do not have to use the CLI defaults below as initial query limits. If both the harness and Matis clip output, reduce the next batch. Do not assume that the last excerpt was visible. If you use a compact JSON projection, retain identity and revision, diagnostics and truncation flags, boundaries, node keys and paths, and pertinent edges. Keep relationship, confidence, type-only and evidence distinctions for those edges. Do not remove uncertainty metadata to save tokens.

Use ordinary search to supplement Matis. Discover paths before searching guessed directories. A search exit code of 1 can mean no matches, not a tool failure. Avoid `&&` before unrelated verification when you expect no match. If the harness rewrites `rg`/`find` and rejects options, use a search or read tool that is known to work. Do not repeat the same command. Do not report genuine path or syntax errors as no matches.

The defaults are `find --limit 10`; `children --limit 30 --offset 0`; `context --depth 2 --max-nodes 30 --max-edges 100`; `source --max-lines 80`; and `path --max-depth 6 --max-nodes 30 --max-edges 100`. Path also accepts `--direction` and `--relations`. Navigation errors return JSON on stderr and exit with code 1. Invalid CLI usage exits with code 2.

Graph queries do not implicitly migrate or reindex the database. For authorized setup in an Matis checkout, use:

```sh
uv run --project /absolute/path/to/matis/matis python -m matis.persistence.database migrate
uv run --project /absolute/path/to/matis/matis matis index --folder /absolute/project/path
```

Use the same `DATABASE_PATH` for these commands and queries. Initialization and indexing write data. Do not run them only because a read query failed.
