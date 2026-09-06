# Matato Pi Architecture Research

## Purpose

This document explains the current Matato architecture, what Pi provides, why responsibilities belong where they do, and the strategies considered. The existing application in `../matato` is the reference implementation. All new work described here happens in `../matato-pi`. Implementation is split into `piPackagePlan.md` and `elixirRpcPlan.md`.

## Objective

Keep every Matato capability while making Pi the agent runtime:

- Telegram access
- Interactive UI and real-time monitoring
- CLI access
- Chat, work, plan, research and sequence sessions
- Scheduled jobs and reminders
- System-health analysis
- Skills and tools
- Subagents
- Durable configuration and application state

## Current Matato Architecture

The reference project at `../matato` is one Bun/TypeScript application. It embeds Pi through the SDK rather than implementing its own agent loop.

`../matato/src/agent/matatoAgent.ts` creates an `AgentSession` with:

- `createAgentSession()`
- `DefaultResourceLoader`
- `SessionManager`
- stored model credentials and configuration
- Matato tools
- event collection
- identity and guardrail prompts

The application around Pi provides:

```text
Matato
├── Pi SDK sessions
├── 23 skills
├── memory and sequence tools
├── subagents
├── Telegram polling and voice transcription
├── scheduled jobs
├── sequence/work bus
├── SQLite application state
├── Elysia REST and SSE
├── CLI
└── Astro/React GUI
```

Important boundaries today:

| Responsibility             | Current location                                                    |
| -------------------------- | ------------------------------------------------------------------- |
| Pi runtime                 | `../matato/src/agent/matatoAgent.ts`                                |
| Matato tools               | `../matato/src/agent/matatoAgentTools.ts`                           |
| Session paths and policies | `../matato/src/agent/matatoAgentSessions.ts`                        |
| API and SSE                | `../matato/src/api/`                                                |
| Telegram                   | `../matato/src/gateway/telegram/`, `../matato/src/worker/telegram/` |
| Scheduling                 | `../matato/src/worker/scheduledJobs/`                               |
| Work and sequences         | `../matato/src/worker/bus/`                                         |
| Durable domain state       | `../matato/src/storage/`, SQLite                                    |
| Skills                     | `../matato/data/agent/skills/`                                      |
| CLI                        | `../matato/src/cli/`                                                |

## What A Pi Package Provides

A Pi Package distributes resources Pi knows how to discover:

- extensions
- skills
- prompt templates
- themes

Extensions can register tools, commands, flags, shortcuts, renderers and TUI components. They can intercept events, modify prompts, inject context, call external programs and APIs, persist session entries, and launch subprocesses.

Pi Package discovery does not supervise an application daemon. Installing a package does not start Telegram polling, a scheduler, a queue worker or an HTTP server.

## What Extensions Can Own

Agent-facing behavior fits naturally in the package:

| Matato capability              | Pi mechanism                             |
| ------------------------------ | ---------------------------------------- |
| Identity and guardrails        | `before_agent_start` extension           |
| Memory actions                 | custom tools                             |
| Sequence initiation            | custom tool                              |
| Skills                         | native Pi skills                         |
| Plan and research entry points | commands and prompts                     |
| Work and health views          | commands, widgets and custom TUI screens |
| Tool permissions               | `tool_call` interception                 |
| Session metadata               | custom entries, labels and names         |
| Trace rendering                | tool and entry renderers                 |
| Model and thinking controls    | native Pi APIs                           |
| Subagent dispatch              | custom tool plus Pi subprocess/RPC       |

Extensions are session-scoped. Long-lived resources must start after `session_start` and close on `session_shutdown`. `/reload`, session replacement and Pi exit tear down extension state. That lifecycle is correct for UI and agent behavior, but wrong for infrastructure expected to remain available without an interactive Pi process.

## What Must Stay Outside A Normal Extension

The durable application runtime owns:

- Telegram polling and checkpoints
- schedules and reminders
- work queues and retries
- concurrent conversation routing
- process supervision
- relational application state
- system-level health
- repository workspace lifecycle

Putting these in a normal extension causes avoidable failure modes:

- Telegram stops when the terminal closes.
- `/reload` interrupts timers and sockets.
- multiple Pi terminals can duplicate polling or jobs.
- multiple processes can write one session file.
- scheduled work depends on an interactive process being open.

## Pi Sessions Versus Application State

Pi sessions are append-only JSONL trees. They are designed for:

- user, assistant and tool messages
- branches and labels
- model and thinking changes
- compaction and branch summaries
- custom session metadata
- parent/child session references

They are not a transactional relational database or multi-writer queue.

Keep application state in SQLite:

- configuration and environment variables
- projects, plans and research records
- sequence definitions and work state
- scheduled jobs
- failures and retries
- memory
- Telegram checkpoints
- session index and ownership

Never store secrets in session JSONL.

## Single-Writer Requirement

Exactly one runtime may append to a Pi session file at a time.

```text
logical session key
        │
        ▼
conversation actor
├── one active Pi runtime
├── one FIFO command queue
├── one session path
└── many observing channels
```

Telegram, UI, CLI and Pi TUI may share a conversation only by routing through the same owner. They must not independently open the same session for writing.

Suggested logical keys:

```text
telegram:<userId>:<period>
chat:<sessionId>
plan:<planId>
research:<researchId>
work:<workId>:<stage>
scheduled:<jobName>:<runId>
subagent:<parentSessionId>:<toolCallId>
```

## SDK Strategy

The SDK runs `AgentSession` in the application process.

Advantages:

- direct TypeScript types
- low startup overhead
- direct access to session internals
- easy event subscriptions
- simple custom tool injection

Costs:

- daemon must use JavaScript/TypeScript
- an agent/runtime failure shares the daemon process
- runtime dependencies are coupled to application dependencies
- changing the daemon stack requires replacing SDK integration

SDK remains a valid optimization if RPC overhead becomes material or a required capability is absent from RPC.

## RPC Strategy

`pi --mode rpc` exposes Pi through LF-delimited JSON on stdin/stdout. It supports:

- prompts and streaming events
- steering and queued follow-ups
- abort and queue clearing
- model and thinking controls
- session creation and switching
- message, entry and tree reads
- forks and clones
- compaction
- extension commands and extension UI requests

A process can hold a back-and-forth conversation for as long as it remains alive. Conversation history persists in JSONL, so a stopped process can later be restarted with the same session.

Advantages:

- daemon can use Elixir or any subprocess-capable language
- each active session has process isolation
- Pi CLI and package behavior remain canonical
- runtime upgrades are separated from daemon compilation

Costs:

- one child process per active logical session
- process startup and memory overhead
- strict JSONL parsing and request correlation
- restart, timeout and cancellation supervision
- weaker access than in-process SDK internals

RPC gives process isolation, not a security sandbox. Pi children still inherit host permissions unless tools, credentials, users or containers restrict them.

## RPC Conversation Lifecycle

```text
message arrives
  → resolve logical session
  → start or find actor
  → start Pi RPC child if cold
  → send command with request id
  → forward asynchronous events
  → wait for agent_settled
  → retain process while warm
  → evict after idle timeout
  → retain session path for reactivation
```

Responses carrying request IDs and asynchronous agent events are separate streams conceptually, even though both arrive over stdout. The owner must correlate responses while independently publishing events.

Use `agent_settled`, not only `agent_end`, when deciding that automatic retries, compaction retries and queued continuations are finished.

## Subagent Strategies

Three useful modes exist:

| Mode                             | Use                                             |
| -------------------------------- | ----------------------------------------------- |
| Persistent RPC                   | conversational or observable subagent           |
| Temporary RPC                    | isolated task requiring live updates or control |
| `pi --mode json -p --no-session` | independent one-shot task                       |

A daemon-supervised RPC subagent gives central concurrency limits and lifecycle tracking. An extension-spawned subagent is simpler but bypasses daemon supervision. The package plan can start with package-local dispatch; the Elixir runtime should eventually own subagents requiring durable status or global limits.

## UI And Transport Strategy

A separate public REST API is not mandatory when Phoenix owns the UI and runtime in one Elixir application. LiveView, controllers, Telegram handlers and schedulers can call application contexts directly.

A local integration boundary is still required for:

- the `matato` shell CLI
- Pi Package tools and commands
- scripts and automation

A local Unix-domain socket can provide this without exposing an HTTP API. The CLI presents stable human output and `--json` machine output. Pi extension tools can call the CLI or a small socket client.

## Recommended Direction

```text
Matato Pi Package
extensions, tools, skills, prompts, TUI
                 │ local CLI/socket when domain access is needed
                 ▼
Elixir matatod
Phoenix UI, Telegram, scheduler, state, supervision
                 │ strict JSONL
                 ▼
pi --mode rpc
one process per active logical session
```

Implementation order in `../matato-pi`:

1. Standardize eligible behavior copied or ported from `../matato` as a Pi Package.
2. Build the Elixir runtime around Pi RPC and a local CLI protocol.
3. Migrate durable application services incrementally while `../matato` remains the behavioral reference.

## Decisions Still Open

- Whether Telegram and UI intentionally share conversations
- Session period policy for Telegram
- Local, private git or npm package distribution
- Idle RPC process timeout
- Global and per-provider concurrency limits
- Durable replay requirements for UI event reconnection
- SQLite migration and compatibility strategy
- Which subagents need daemon supervision

## Sources

Installed Pi `0.84.4` documentation:

- `docs/extensions.md`
- `docs/sdk.md`
- `docs/rpc.md`
- `docs/packages.md`
- `docs/skills.md`
- `docs/sessions.md`
- `docs/session-format.md`
- `docs/tui.md`
- `examples/extensions/subagent/`
- `examples/extensions/file-trigger.ts`

Latest package guide verified at:

- https://pi.dev/docs/latest/packages

Public references:

- https://github.com/earendil-works/pi
- https://pi.dev/packages
- https://github.com/artyom-ivanov/pi-telegram-connect
- https://pi.dev/packages/@chankov/agent-fleet
- https://github.com/earendil-works/pi/issues/1253
