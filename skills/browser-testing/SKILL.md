---
name: browser-testing
description: Use after a change to a runnable frontend or user flow. Perform one focused smoke check in a local Brave browser with playwright-cli.
---

# Browser Testing Skill

First, read the target repository's project manifest (`package.json`, `mix.exs`, etc.), start scripts, and existing E2E conventions. Use the repository's actual start command and an unused local port. Never invent a framework-specific command. Never reuse a running server that a person uses or shares.

Use `scripts/runBrowser.ts` for all browser smoke checks. The runner manages the app process group and waits up to 60 seconds for readiness. It manages a unique named session, Brave configuration, fresh snapshots, interactions, assertions, and a screenshot. It also manages console errors, network requests and response bodies, and cleanup on success, failure, SIGINT, or SIGTERM.

The runner reads help to detect the installed CLI interface. It supports dedicated session commands or the newer `playwright-cli cli` subcommand. It never installs or downgrades tools or browsers. It never attaches to a person's session or closes other browser sessions. `bun`, global `playwright-cli`, and `/usr/bin/brave` must already exist. Report missing or unsupported tools as blockers.

## Run

Create a small JSON scenario outside the clone. Cover only the critical path that changed. Use exact accessible labels from snapshots as targets. Do not use CSS selectors or element refs. The runner resolves each target to a unique ref from a live snapshot taken immediately before that step. If a target is missing or ambiguous, the runner fails instead of guessing. It takes another snapshot after each interaction.

```json
{
  "name": "Save the edited profile",
  "steps": [
    { "action": "fill", "target": "textbox \"Name\"", "value": "Ada" },
    { "action": "click", "target": "button \"Save\"" },
    { "action": "expect", "text": "Profile saved" }
  ]
}
```

Use these supported actions:

- `click`, `check`, `uncheck`, and `hover` require `target`.
- `fill` and `select` require `target` and `value`.
- `press` requires `key`.
- `expect` requires `text`.

Include at least one `expect` in every scenario. Assertions wait up to 10 seconds for text in the visible accessibility snapshot. They do not evaluate hidden DOM or execute arbitrary browser code.

Resolve the runner path relative to this skill directory, not the target repository:

```sh
bun /absolute/path/to/browser-testing/scripts/runBrowser.ts \
  --repo /absolute/path/to/target-repo \
  --url http://127.0.0.1:3000 \
  --startCommand 'npm run dev -- --host 127.0.0.1 --port 3000' \
  --scenario /tmp/browserScenario.json
```

The start command above is an example only. Use the project's actual start command. To find the snapshot labels, first use a scenario with only an `expect` for a known page heading. Then read its snapshot labels to prepare the focused scenario. Do not guess refs or bypass the runner. Each run starts a fresh app and session. Runs do not share state.

## Read the Output

The runner prints step outputs, snapshots, assertion results, and console errors. It also prints all HTTP request statuses (including static assets), non-static request details and response bodies, and a final JSON report. HTTP evidence does not include inspection of WebSocket messages. Use the resulting snapshots to verify LiveView interactions. The runner returns a nonzero exit status if an assertion, command, or cleanup fails. `PASS` means the scenario assertions passed. It does not mean that the console and network evidence show no problems. Inspect those outputs and the screenshot before you conclude that the change works.

The runner stores artifacts outside the clone in a unique temporary directory. It prints the directory path as `artifacts`. The directory contains `run.json` (URL, scenario, app PID, log path, session), `app.log`, command logs, snapshots, `result.png`, and `report.json`. Read `result.png` with the image reader. Follow any paths to console or network artifacts that the CLI prints. Inspect relevant failed responses. Report the URL, scenario, result, relevant evidence, and limitations.

The runner stops the browser session and the entire app process group before it returns. If cleanup fails, report the failure and resolve it before handoff. Cleanup cannot run after an uncatchable termination (SIGKILL or worker crash). Use `run.json` to identify the app and session owned by the runner. Never use `close-all` or `kill-all`.

After you read and report the evidence, use the runner to delete the artifacts. Remove your scenario file:

```sh
bun /absolute/path/to/browser-testing/scripts/runBrowser.ts --cleanup /tmp/matatoBrowserABC123
rm /tmp/browserScenario.json
```

Cleanup accepts only artifact directories from completed runs of the runner. These directories must be under the system temporary directory. Do not keep screenshots or logs that contain sensitive application data longer than necessary.
