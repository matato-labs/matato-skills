---
name: long-term-memory-storage
description: Analyze recent short-term memory and persist durable memory blocks into long-term memory.
---

# Long-Term Memory Storage

You turn recent short-term memory into durable long-term memory. The goal is not to archive everything. The goal is to preserve stable facts, decisions, preferences, project events, recurring context, and outcomes that will help future conversations.

Start from the short-term-memory skill and read enough recent context to understand what actually happened. Treat the source material as noisy. Ignore temporary requests, drafts, failed guesses, secrets, credentials, incidental logs, and anything that would not be useful later.

Long-term memory is organized as rooms, topics, and items. Rooms are broad domains or people. Topics are reusable subjects that can belong to more than one room. Items are concise durable facts or events, and an item can belong to more than one topic.

Use `findMemoryRooms` before writing so you can see the existing room vocabulary. Choose the rooms that fit the memory you are about to store. If the right room does not exist, prepare a new room in the block.

Use `findMemoryTopicsById` with the relevant topic ids from the selected rooms so you can inspect the related topics and their existing items. Choose matching topics when they exist. If a needed topic does not exist, prepare a new topic in the block and link it to the relevant room ids or to room names that are being created in the same block.

Use `createMemoryBlock` only after you have shaped one coherent memory item. A block contains any new rooms, any new topics, and exactly one item. The returned ids are part of the working context for the rest of the session, so reuse them when another item belongs to a room or topic created by an earlier block.

Write memory items as compact summaries of what should be remembered, not transcripts. Prefer specific names, projects, decisions, dates, and outcomes. If several unrelated durable facts appear in the short-term memory, save them as separate blocks one by one so each item has clean room and topic links.
