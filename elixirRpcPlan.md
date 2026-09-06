# Elixir Matatod RPC Plan

## Goal

Part two builds the new Elixir application inside `../matato-pi` while keeping Pi as the agent runtime through `pi --mode rpc`. The existing Bun application in `../matato` remains the source and behavioral reference during migration; it is not the workspace for this plan.

Phoenix owns the web UI. A separate public REST API is not required. Telegram, LiveView, scheduling and workflow processing call Elixir contexts directly. A local command protocol supports the `matato` CLI, scripts and Pi Package tools.

## Repository Boundary

All implementation files belong to `../matato-pi`. Read `../matato` to understand behavior, schemas and compatibility, then port that behavior without runtime imports or filesystem coupling between repositories.

```text
../matato       reference Bun application
../matato-pi    new Pi Package and Elixir matatod
```

Keep `../matato` operational until parity and data migration are verified.

## Target Architecture

```text
                    ┌──────────────────────────────┐
                    │       Elixir matatod         │
                    │                              │
Telegram ──────────►│ Telegram adapter             │
Phoenix LiveView ──►│ application contexts         │
Scheduler ─────────►│ jobs and workflow engine     │
matato CLI ─socket─►│ local command router         │
                    │ conversation supervisor      │
                    │ SQLite/Ecto                  │
                    └──────────────┬───────────────┘
                                   │ JSONL stdin/stdout
                    ┌──────────────┼──────────────┐
                    ▼              ▼              ▼
              pi --mode rpc  pi --mode rpc  pi --mode rpc
              Telegram chat  plan session   work/subagent
```

The Phoenix endpoint is the UI transport, not a general Matato API. LiveViews subscribe to internal PubSub topics and invoke contexts directly.

## OTP Structure

```text
Matatod.Application
├── Matatod.Repo
├── Phoenix.PubSub
├── MatatodWeb.Endpoint
├── Matatod.CommandSocket
├── Matatod.Conversations.Registry
├── Matatod.Conversations.Supervisor
├── Matatod.Jobs.Supervisor
├── Matatod.Work.Supervisor
└── Matatod.Telegram.Supervisor
```

### Conversation Registry

Maps each logical session key to one conversation process.

```text
telegram:<userId>:<period>
chat:<sessionId>
plan:<planId>
research:<researchId>
work:<workId>:<stage>
subagent:<parentSessionId>:<toolCallId>
```

### Dynamic Supervisor

Starts conversation workers on demand. Different sessions run concurrently. Duplicate starts resolve to the existing registered process.

### Conversation GenServer

One GenServer owns:

- one logical session key
- one Pi session path
- zero or one active Pi child process
- command request IDs and waiting callers
- prompt/follow-up queue policy
- subscribers and PubSub topic
- idle eviction timer
- current run status

The GenServer is the only writer owner for its session file.

## Pi Process Management

Start children with explicit executable arguments, cwd, package configuration and session location.

```bash
pi --mode rpc --session /path/to/session.jsonl
```

For a new conversation, start with a dedicated session directory and capture `sessionFile` and `sessionId` from `get_state`.

Use raw binary buffering for stdout:

1. append each chunk to the actor buffer
2. split only on LF (`\n`)
3. strip one trailing CR when present
4. retain the incomplete tail
5. decode each complete JSON object

Do not use a line reader that treats Unicode separators as record boundaries.

Each outgoing command receives a unique ID:

```json
{ "id": "request-id", "type": "prompt", "message": "Hello" }
```

Incoming objects are routed as:

- matching `type: "response"` → complete the waiting command
- agent lifecycle event → publish to subscribers
- `extension_ui_request` → UI policy or selected client
- malformed JSON → record protocol failure and restart safely

Keep stderr out of stdout so logs cannot corrupt JSONL framing.

## Conversation Operations

Expose internal Elixir functions rather than HTTP endpoints:

```text
start(sessionKey, options)
prompt(sessionKey, message, options)
steer(sessionKey, message)
followUp(sessionKey, message)
abort(sessionKey)
clearQueue(sessionKey)
state(sessionKey)
messages(sessionKey)
entries(sessionKey, cursor)
compact(sessionKey, instructions)
fork(sessionKey, entryId)
subscribe(sessionKey)
stop(sessionKey)
```

A prompt response only means Pi accepted the command. Completion comes from events. Treat `agent_settled` as final for the full run.

## Warm And Cold Sessions

An active conversation does not need a permanent operating-system process.

```text
cold session
  → message arrives
  → actor starts Pi with saved session
  → actor becomes warm
  → commands and events flow
  → idle timeout expires
  → graceful child shutdown
  → actor retains durable session mapping
```

Never evict while Pi is streaming, retrying, compacting or processing queued continuations.

On unexpected child exit:

- fail current waiting commands
- publish a runtime failure
- retain the session path
- apply bounded restart policy
- do not replay an accepted prompt automatically unless idempotency is proven

## Channel Routing

### Phoenix LiveView

LiveView calls conversation contexts directly and subscribes through Phoenix PubSub.

```text
LiveView event
  → Conversations.prompt/3
  → conversation GenServer
  → Pi RPC
  → PubSub events
  → LiveView update
```

No browser-facing REST API is needed. Use LiveView uploads for voice or attachments and LiveView streams for transcript/trace rendering.

### Telegram

Telegram remains an always-running supervised adapter:

```text
Telegram update
  → authorize
  → deduplicate/checkpoint
  → transcribe voice when present
  → resolve session key
  → Conversations.prompt/3
  → subscribe to run
  → send or edit Telegram response
```

Telegram and LiveView can observe the same conversation only when both resolve to the same logical key. The GenServer still remains the sole writer.

### Scheduled Jobs

Store schedules and run state in SQLite. A supervised scheduler loads due jobs, claims them transactionally and starts unique run sessions.

Each run receives a unique key:

```text
scheduled:<jobName>:<runId>
```

Do not reuse one conversation file for overlapping scheduled runs.

### Work And Sequences

Keep definitions and state transitions in Ecto. Each sequence stage launches a unique Pi session and stores its session ID/file on the agent/work record. Completion events advance the state machine transactionally.

## No General API

Matatod does not need Elysia-style REST routes when all product surfaces run in one Phoenix application.

Use three boundaries:

| Consumer                       | Boundary                   |
| ------------------------------ | -------------------------- |
| LiveView and controllers       | direct Elixir contexts     |
| Telegram, scheduler, workflow  | direct Elixir contexts     |
| local CLI, scripts, Pi Package | Unix-domain command socket |

The Unix socket is local infrastructure, not a public web API. Filesystem permissions restrict access. Remote administration can use SSH to run the CLI.

If an external mobile app or third-party integration is later required, add only the necessary authenticated Phoenix endpoints.

## Agent-Friendly CLI

Provide one stable executable named `matato`. It should be useful to humans, shell scripts and Pi tools.

```bash
matato health
matato config get
matato work list
matato work show <id>
matato work start ...
matato plan show <id>
matato research show <id>
matato session prompt <id> "message"
matato session followup <id> "message"
matato session events <id>
matato job list
```

CLI rules:

- concise human output by default
- `--json` for every data-returning command
- stable exit codes
- errors on stderr
- no prompts in `--json` mode
- explicit `--yes` for destructive non-interactive actions
- stream JSONL for event commands
- bounded output with pagination/filter options
- command names and fields remain stable

Example machine use:

```bash
matato --json work list
matato --json work show "$WORK_ID"
matato --json session prompt "$SESSION_ID" "continue"
matato --jsonl session events "$SESSION_ID"
```

The CLI connects to `matatod` through the local Unix socket. It must not open SQLite or Pi session files directly, preserving one owner for state and conversations.

Pi Package custom tools should call the same local protocol through a small client or invoke `matato --json`. The model receives typed tool schemas and never needs to parse human CLI output.

## Local Command Protocol

Use length-prefixed JSON or strict JSONL over the Unix socket. Keep request/response messages versioned.

```json
{"version":1,"id":"request-id","command":"work.list","params":{}}
{"version":1,"id":"request-id","ok":true,"result":{"items":[]}}
```

Streaming commands emit envelopes carrying the same request ID:

```json
{ "version": 1, "id": "request-id", "type": "event", "event": {} }
```

This protocol is independent from Pi RPC. Matatod translates domain commands to Ecto operations or conversation actor calls.

## Persistence

Use Ecto with SQLite initially to preserve the current deployment model.

Keep:

- Matato relational/domain data in SQLite
- Pi conversation history in JSONL
- session key to session path mapping in SQLite
- Telegram checkpoints in SQLite
- active process state in memory only

On boot, reconcile records marked active with reality. A process restart means those runs are interrupted unless Pi/session state proves they settled.

Plan schema migrations for existing tables rather than replacing storage wholesale.

## Event Delivery

Phoenix PubSub provides live in-process delivery. Durable replay is separate.

Minimum first version:

- persist final messages through Pi sessions
- keep active deltas in memory
- allow reconnecting UI to reload messages then subscribe to new events

Add a durable event journal only if the product requires replay of intermediate tool/delta events across daemon restarts.

## Subagents

Two paths are supported:

### Package-Local Subagent

The Pi extension spawns a temporary child itself. This is simple but invisible to global daemon limits.

### Matatod-Supervised Subagent

A Pi tool calls the local Matato protocol. Matatod starts a child conversation actor, streams progress back and stores lineage/status. Use this for:

- long-running subagents
- UI-visible subagents
- global/provider concurrency limits
- durable failure tracking

RPC isolation is not sandboxing. Use restricted tool sets, OS users, containers or remote execution for untrusted workloads.

## Migration Strategy

### 1. Elixir Skeleton

Create the OTP application under `../matato-pi/matatod/`, including Repo, Phoenix LiveView shell, PubSub and supervision tree. Keep `../matato` operational as the reference application.

### 2. Pi RPC Client

Implement one RPC process wrapper with command correlation, events, cancellation, strict framing and tests using a controllable fake child.

### 3. Conversation Actors

Add Registry, DynamicSupervisor, session mapping, single-writer guarantees, warm reuse and idle eviction.

### 4. Local Command Socket And CLI

Implement versioned commands and migrate read-only CLI actions first. Add mutations after ownership is centralized.

### 5. Phoenix Chat

Build chat, plan and research LiveViews directly on conversation contexts and PubSub.

### 6. Domain Persistence

Map the SQLite schema from `../matato/src/storage/` and migrate configuration, plans, research, work, sequences, memory and failures into Ecto contexts in `../matato-pi`.

### 7. Telegram

Move polling, checkpointing, authorization, voice transcription and conversation routing into supervised Elixir processes.

### 8. Jobs And Workflows

Move scheduler and sequence/work processing. Preserve retry and repository cleanup semantics.

### 9. Package Integration

Configure every RPC child to load the Matato Pi Package. Route package domain tools through the local command protocol.

### 10. Cutover

Run parity checks against `../matato`, stop its deployed writers, then switch CLI, UI and Telegram to the Elixir application. Any cleanup in `../matato` is a later, separately approved task.

## Proposed Elixir Layout

Inside `../matato-pi`:

```text
matatod/
├── lib/
│   ├── matatod/
│   │   ├── application.ex
│   │   ├── repo.ex
│   │   ├── conversations/
│   │   ├── piRpc/
│   │   ├── commandSocket/
│   │   ├── telegram/
│   │   ├── jobs/
│   │   ├── work/
│   │   ├── plans/
│   │   ├── researches/
│   │   ├── memory/
│   │   └── config/
│   └── matatodWeb/
│       ├── endpoint.ex
│       ├── router.ex
│       └── live/
├── priv/repo/migrations/
├── test/
└── mix.exs
```

Final names should follow Elixir conventions even where this conceptual diagram uses project-style camelCase labels.

## Verification

Test at four levels:

- RPC framing and response/event correlation
- conversation actor lifecycle and single-writer behavior
- Ecto domain transitions
- LiveView, Telegram and CLI workflows

Critical failure tests:

- fragmented and combined stdout chunks
- malformed RPC output
- child exit during prompt
- abort timeout and forced kill
- daemon restart with saved sessions
- duplicate requests for one session key
- concurrent different sessions
- idle eviction during and after runs
- CLI disconnect during streaming
- Telegram duplicate update

## Completion Criteria

- Phoenix provides all required UI without a general REST API
- `matato` CLI covers human, script and agent access
- Telegram remains always on
- chat, plan and research conversations support real-time back-and-forth RPC
- previous sessions reactivate after child eviction or daemon restart
- work, sequences and scheduled jobs persist and resume safely
- one writer owns every Pi session file
- Pi Package resources load in every child
- subagents support cancellation, limits and traceability
- existing SQLite data has a migration path

## Decisions Needed

- Phoenix LiveView only or selected controller endpoints too
- Unix socket location and permissions
- CLI implementation and packaging format
- RPC idle timeout and restart limits
- Telegram session period and UI-sharing policy
- initial scheduler implementation for SQLite
- durable intermediate-event replay requirements
- package-local versus Matatod-supervised subagent defaults
