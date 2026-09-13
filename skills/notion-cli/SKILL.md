---
name: notion-cli
description: Use this skill to use the official Notion CLI (`ntn`) through bash for Notion pages, blocks,
  data sources, files, API requests, or Notion Workers. Use when a user asks to
  read, search, create, update, upload, query, or manage Notion content.
---

The CLI and API evolve, use the official docs https://developers.notion.com/cli/get-started/overview if you don't know how to do something or use the `ntn help` command. Do not invent endpoint paths, methods, flags, or JSON fields. Inspect the installed CLI for every operation:

There is a high level workspace called `Personal Work`, it contains 3 databases, `Projects`, `Research`, `Plans`.

**Projects**: Database to all projects track in Notion, plans are linked to projects.
**Research**: It stores all Research made by the user.
**Plans**: All the ongoing plans for a project.

When you create a new page under any of the databases, follow the template.
