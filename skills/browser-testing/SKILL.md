---
name: browser-testing
description: Use after a runnable frontend or user-flow change to perform one focused local Brave browser smoke check with playwright-cli.
---

# Browser Testing Skill
- Read the target repository's `package.json`, scripts, and existing E2E conventions first. Reuse the project's own start command instead of inventing a framework-specific one.
- Record the app process PID and its log path so both can be cleaned up.
- `playwright-cli` and Brave at `/usr/bin/brave` are provisioned globally on the worker. Never install them or download a browser inside a task. If either is missing, stop and report the blocker.
- Configure `playwright-cli` with `browserName: "chromium"` and `launchOptions.executablePath: "/usr/bin/brave"`. `browserName` selects Playwright's Chromium engine API; the executable path ensures the launched browser is Brave, not Playwright's bundled Chromium.

## Interaction Contract

- Create a unique named session per work item, e.g. `matato-${issueNumber}-...`. Run every browser command against that name.
- Never use `close-all`, a shared profile, or `attach` to a human browser.
- Run only the changed critical path.
- Interact only through element refs from the immediately preceding `snapshot`. Never guess or reuse refs from an older snapshot.
- Validate the visible outcome with a follow-up `snapshot` after the interaction.
- Capture one screenshot after the result.
- Inspect `console error` output and relevant network responses via `requests`.

## Interaction Shape

The block below is a shape, not a script. `e12` is an example ref only; always use the refs returned by the live snapshot and the target project's actual start command and URL.

```sh
artifactDirectory="$(mktemp -d /tmp/matato-browser-XXXXXX)"
browserSession="matato-${issueNumber}-$(basename "$artifactDirectory")"
browserConfig="$artifactDirectory/playwright-cli.json"
printf '%s\n' '{"browser":{"browserName":"chromium","launchOptions":{"executablePath":"/usr/bin/brave"}}}' > "$browserConfig"
trap 'playwright-cli -s="$browserSession" close; kill "$appPid" 2>/dev/null' EXIT

cd "$artifactDirectory"
playwright-cli -s="$browserSession" --config "$browserConfig" open "$applicationUrl"
playwright-cli -s="$browserSession" snapshot
playwright-cli -s="$browserSession" click e12
playwright-cli -s="$browserSession" snapshot
playwright-cli -s="$browserSession" screenshot --filename="$artifactDirectory/changed-flow.png"
playwright-cli -s="$browserSession" console error
playwright-cli -s="$browserSession" requests
playwright-cli -s="$browserSession" close
```

## Artifacts

- Store snapshots and screenshots in a `mktemp -d` directory outside the clone.

## Cleanup and Evidence

- Always close the named browser session and kill the app process by its recorded PID, including on failure. No browser or server process may survive the session.
- Report the URL, the scenario executed, the result, relevant command outputs, and any limitation.
- After the handoff evidence has been reported, delete the artifact directory with `rm -rf "$artifactDirectory"` so `/tmp/matato-browser-*` directories do not accumulate on the worker.
