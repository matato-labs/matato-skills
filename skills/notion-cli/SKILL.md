---
name: notion-cli
description: Use the official Notion CLI (`ntn`) through bash to work with Notion pages, blocks,
  data sources, files, API requests, or Notion Workers. Use when a user asks to
  read, search, create, update, upload, query, or manage Notion content.
---

The CLI and API change over time. If you do not know how to perform an operation, read the official docs at https://developers.notion.com/cli/get-started/overview or use the `ntn help` command. Do not invent endpoint paths, methods, flags, or JSON fields. Inspect the installed CLI for every operation.

The high-level workspace `Personal Work` contains 3 databases: `Projects`, `Research`, and `Plans`.

**Projects**: This database tracks all projects in Notion. Plans are linked to projects.
**Research**: This database stores all research conducted by the user.
**Plans**: This database stores all ongoing plans for a project.

When you create a new page under any of these databases, follow the template.
