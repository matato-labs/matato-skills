---
name: why
description: Use this skill when the user wants to know why something works the way it does in a codebase
disable-model-invocation: true
---

Sometimes the user will call `/how`, and the answer for that skill will require investigating WHY the code is like that. This skill provides the answer on the WHY.

You need to be honest about the findings; never invent or assume. It's better to say that you found something that could be relevant but are not sure than to treat it as fact when in doubt.

## Create a base

**Code history**: We start with the Git history, go over the latest changes in the target code, and create a linear history of changes. If any of the commits could be linked to a PR, create a linear history of PRs, and if the PRs are linked to tickets or issues, add them as well. With all this, we have a basic floor to start the investigation.

**Tools**: Fetch a list of tools, CLI access, or MCPs that could help with the investigation; each one will be an investigation branch.

## Investigation
Launch up to 4 subagents in parallel to go over the different tools and collect the required information from each tool. Use only one tool per subagent. Create a good linear history of the codebase changes with links, commits, PRs, etc., so the subagent can extract the required information.

## Output
When all investigations are done and you have a better overview, draft the answer to the user. Get to the point as if you are talking to a senior software engineer. Make any answer concise. Sacrifice grammar for the sake of concision. Add meaningful evidence from the tools the subagents used to support your answer.
