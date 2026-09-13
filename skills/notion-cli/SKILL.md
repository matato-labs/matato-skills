---
name: notion-cli
description: >-
  Use the official Notion CLI (`ntn`) through bash for Notion pages, blocks,
  data sources, files, API requests, or Notion Workers. Use when a user asks to
  read, search, create, update, upload, query, or manage Notion content.
---

# Notion CLI

Use the official `ntn` CLI through Pi's `bash` tool. This skill is API-first and does not require MCP.

## Preflight and authentication

Check the CLI before a Notion task:

```bash
command -v ntn && ntn --help
```

If it is unavailable, explain that the user must install the official CLI from https://ntn.dev and stop. Do not install it, start OAuth, or otherwise change authentication on the user's behalf.

`ntn api` uses `NOTION_API_TOKEN` when it is set; otherwise it uses the user's CLI login session. Do not print the token to determine which is in use. If an authenticated command fails because authentication is absent or expired, tell the user to run `ntn login` themselves and complete the browser flow. Never print, log, commit, or persist tokens, authorization headers, or CLI credential files.

## Discover before calling

The CLI and API evolve. Do not invent endpoint paths, methods, flags, or JSON fields. Inspect the installed CLI for every operation:

```bash
ntn --help
ntn api ls
ntn api <path> --help
ntn api <path> --docs
ntn api <path> --spec
```

Use `ntn api ls` to find the current endpoint for pages, blocks, search, data sources, comments, or file uploads. Read `--docs` or `--spec` before constructing a request, then use the shown syntax. `ntn api` defaults to GET and infers POST when a request body is supplied; use `-X METHOD` only when the endpoint documentation requires another method.

## Reading and search

Use read-only commands without confirmation. For a page rendered as Markdown, use the documented API endpoint:

```bash
ntn api v1/pages/<page-id>/markdown
```

For page metadata, blocks, search, or data-source queries, discover the corresponding API endpoint and schema first, then issue the documented read request. `ntn datasources query <data-source-id> --limit <n>` is available for a scoped data-source query; inspect its help before using filters or other options. Keep results scoped with documented filters, pagination, and page sizes rather than retrieving an entire workspace unnecessarily.

## Content and data sources

Use `ntn api` for pages, blocks, properties, comments, data-source queries, and data-source schema or entry management only after inspecting that endpoint's `--docs` or `--spec`. Use the exact body fields and method from the selected endpoint documentation; do not assume a Markdown field or substitute `rich_text` without verifying the schema.

Before any write, show the target workspace object, intended change, and exact command or request body, then obtain explicit user confirmation. Treat creating pages, blocks, comments, data-source entries, or data-source schema changes as writes. Do not proceed from an earlier or ambiguous confirmation.

## Files and Workers

Inspect the relevant command before use:

```bash
ntn files --help
ntn workers --help
```

Use the documented file command and options for local or external files. Confirm the source, destination, and intended access before uploading a file.

Workers can scaffold, list, execute, or deploy. Confirm before deployment and before executing a Worker capability that can change external state. Never deploy merely to test a command.

## Safety

Ask for fresh, explicit confirmation immediately before every externally visible or irreversible action: writes, updates, archives, deletes, file uploads, Worker deployment, and Worker execution with side effects. Clearly distinguish an archive from a permanent deletion. After a confirmed write, report only non-sensitive identifiers and a concise result. If authentication, access, command syntax, or API shape is unclear, stop and use CLI discovery or ask the user rather than guessing.
