---
name: interview
description: Turn a rough feature idea into a clear brief and implement it. Ask one question at a time before coding.
disable-model-invocation: true
---

# Feature interview

Start with the user's idea. If they have not shared it yet, ask: “What do you want to build?”

## Ask one question per turn

- Ask one short question about one decision. Wait for the answer before asking the next question. Do not hide extra questions in a list or example.
- Use each answer to choose the next question. Start with the outcome. Then focus on decisions that change what you build or how you test it.
- Inspect the code when it can answer a question. Do not ask the user to repeat an answer or decide details that can use an existing default.
- If a trade-off matters, give your recommendation and a short reason. Then ask for one decision.
- Keep track of the goal, agreed scope, and what must work. Treat assumptions as assumptions, not decisions. Do not edit files during the interview.

## Start implementation

End the interview when you know enough to build and verify the feature, or when the user says to stop the interview. Do not ask for approval of the brief or ask one last interview question.

Before editing, give a short brief in chat: what you will build, what must work, and any assumptions that affect the result. If the user stopped early, use the simplest safe defaults for open decisions. If something blocks part of the work, say so and continue with what you can safely build. Then implement and verify the change in the same turn.
