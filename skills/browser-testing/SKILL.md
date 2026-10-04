---
name: browser-testing
description: Use after a runnable frontend or user-flow change to perform one focused local Brave browser smoke check with playwright-cli.
---

# Browser Testing Skill

Read the target repository's project manifest (`package.json`, `mix.exs`, etc.), start scripts, and existing E2E conventions first. Choose its actual start command and an unused local port. Never invent a framework-specific command or reuse a running human/shared server.

Use `scripts/runBrowser.ts` for all browser smoke checks. It manages the app process group, readiness (60 seconds), a unique named session, Brave configuration, fresh snapshots, interactions, assertions, screenshot, console errors, network requests and response bodies, and cleanup on success, failure, SIGINT, or SIGTERM. It never installs dependencies or browsers, attaches to human sessions, or closes other browser sessions. `bun`, global `playwright-cli`, and `/usr/bin/brave` must already exist; report missing tools as blockers.

## Run

Create a small JSON scenario outside the clone for only the changed critical path. Targets are exact accessible labels from snapshots, not CSS selectors or element refs. The runner resolves each target to a unique ref from an immediately preceding live snapshot; missing or ambiguous targets fail rather than guessing. It snapshots again after each interaction.

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

Supported actions: `click`, `check`, `uncheck`, `hover` with `target`; `fill`, `select` with `target` and `value`; `press` with `key`; `expect` with `text`. Every scenario needs at least one `expect`. Assertions wait up to 10 seconds for text in the visible accessibility snapshot; they do not evaluate hidden DOM or execute arbitrary browser code.

Resolve the runner path relative to this skill directory, not the target repository:

```sh
bun /absolute/path/to/browser-testing/scripts/runBrowser.ts \
  --repo /absolute/path/to/target-repo \
  --url http://127.0.0.1:3000 \
  --startCommand 'npm run dev -- --host 127.0.0.1 --port 3000' \
  --scenario /tmp/browserScenario.json
```

The start command above is an example only. Use the project's real command. For initial discovery, use a scenario containing only an `expect` for a known page heading, then read its snapshot labels to prepare the focused scenario. Do not guess refs or bypass the runner. Each run starts a fresh app and session; no state is shared between runs.

## Read the Output

The runner prints step outputs, snapshots, assertion results, console errors, all HTTP request statuses (including static assets), non-static request details and response bodies, and a final JSON report. HTTP evidence does not inspect WebSocket messages; LiveView interactions are verified through their resulting snapshots. Exit status is nonzero for failed assertions, commands, or cleanup. `PASS` means scenario assertions passed, not that console/network evidence is clean; inspect those outputs and the screenshot before concluding the change works.

Artifacts live outside the clone in a unique temporary directory printed as `artifacts`. It contains `run.json` (URL, scenario, app PID, log path, session), `app.log`, command logs, snapshots, `result.png`, and `report.json`. Read `result.png` with the image reader. Follow any console/network artifact paths printed by the CLI and inspect relevant failed responses. Report the URL, scenario, result, relevant evidence, and limitations.

The browser session and entire app process group are stopped before the runner returns. If cleanup failed, report the failure and resolve it before handoff. Uncatchable termination (SIGKILL or worker crash) cannot run cleanup; use `run.json` to identify the owned app/session, never `close-all` or `kill-all`.

After reading and reporting evidence, delete the artifacts using the runner and remove your scenario file:

```sh
bun /absolute/path/to/browser-testing/scripts/runBrowser.ts --cleanup /tmp/matatoBrowserABC123
rm /tmp/browserScenario.json
```

Cleanup accepts only completed runner artifact directories under the system temporary directory. Do not retain screenshots or logs containing sensitive application data unnecessarily.
