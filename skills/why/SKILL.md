---
name: why
description: Use this skill when the user wants to understand why something in a codebase works in a particular way.
disable-model-invocation: true
---

An answer to the user's `/deep-dive` request can require an investigation into why code works in a particular way. Use this skill to answer that question.

Report findings honestly. Never invent information or make assumptions. If a finding could be relevant but you are unsure, state that uncertainty. Do not present uncertain findings as facts.

## Create a base

**Code history**: Start with the Git history. Review the latest changes in the target code and create a linear history of changes. If you can link commits to PRs, create a linear history of those PRs. Add any tickets or issues linked to those PRs. Use this history as the basis for the investigation.

**Tools**: Get a list of tools, CLI access, or MCPs that could help with the investigation. Use each one as an investigation branch.

## Investigation
Launch up to 4 subagents in parallel to investigate the different tools and collect the required information from each tool. Use only one tool per subagent. Create a clear linear history of the codebase changes. Include links, commits, PRs and other relevant references so each subagent can extract the required information.

## Output
When all investigations are complete and you understand the findings, draft the answer to the user. Use short, complete sentences and active voice. Use the same term for the same concept. Give direct instructions. Avoid idioms and unnecessary words. Preserve technical accuracy, code, commands, and identifiers. Do not sacrifice grammar for brevity. Support the answer with meaningful evidence from the tools that the subagents used.
