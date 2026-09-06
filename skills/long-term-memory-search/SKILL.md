---
name: long-term-memory-search
description: Access long-term memory to find details about the user's exchanges with the agent and things that have happened in the past. Use this skill only when the short-term-memory skill could not find anything, or when the user asks you directly to use it.
---

# Long-Term Memory Search
You have access to long-term memory from an agent. It represents durable summaries of things that happened in the system, exchanges between the user and the agent, decisions, preferences, and project context that may matter later.

Only use this skill when the short-term-memory skill could not find anything useful or when the user asks directly to use long-term memory.

Long-term memory is organized as rooms, topics, and items. Rooms are broad domains or people. Topics are reusable subjects that can belong to multiple rooms. Items are concise durable facts or events, and an item can be linked to multiple topics.

Use `findMemoryRooms` to inspect the available rooms and their metadata. Read the room names, summaries, keywords, and topic ids, then decide which rooms are likely to matter for the user's query. Do not assume every room is relevant.

Use `findMemoryTopicsById` with the topic ids from the relevant rooms. Read the topic metadata and the linked items. Decide which topics actually match the query, then use the items under those topics as the memory evidence.

When you answer, synthesize the relevant items into a concise response for the user. Keep the explanation grounded in the retrieved memory. If useful, mention the room, topic, and item relationship so the user can understand where the memory came from, but do not overcomplicate the response.
