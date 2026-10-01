---
name: deep-dive
description: Use this skill anytime the user want to clarify a doubt, find other parts of the code already does something or just want to deeply understand something
disable-model-invocation: true
---

deep-dive it's a companion to `/how` and `/why`, you can use them or use the result from previous runs. Use it when the user wants to deep-dive into a topic, find if there components that already does something similar, find patterns in the code, etc. Don't focus on the how or why, focus the actual facts, `are test that cover this scenario? yes these are the test/ no there not`

Give a first check and find the branch to explore that could give the use the answer is looking for, for each branch launch a sub-agent that will do a deep-dive and comeback with a conclusion, they need to work until the branch either is proved to satisfy or not the theory.

The deep-dive should only answer strictly what the user asks, keep the answer simple and short, you don't need to give explanations.
