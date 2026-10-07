import type { JsonAgentSessionEvent } from "@earendil-works/pi-coding-agent";

type AssistantMessage = Extract<
  Extract<JsonAgentSessionEvent, { type: "message_end" }>["message"],
  { role: "assistant" }
>;

export function createPiOutput(): {
  write: (chunk: string) => void;
  verify: () => void;
} {
  let buffer = "";
  let parseError: string | undefined;
  let finalMessage: AssistantMessage | undefined;
  let settled = false;
  const readLine = (line: string): void => {
    if (!line.trim() || parseError) return;
    try {
      // Pi owns this protocol; its exported union supplies the event shapes.
      // JSON mode also emits a session header, ignored by the cases below.
      const event = JSON.parse(line) as JsonAgentSessionEvent;
      if (event.type === "agent_start") settled = false;
      if (event.type === "agent_settled") settled = true;
      if (event.type === "message_end" && event.message.role === "assistant")
        finalMessage = event.message;
    } catch (error) {
      parseError = `Invalid Pi JSON output: ${String(error)}`;
    }
  };
  return {
    write(chunk) {
      buffer += chunk;
      let newline = buffer.indexOf("\n");
      while (newline !== -1) {
        readLine(buffer.slice(0, newline).replace(/\r$/, ""));
        buffer = buffer.slice(newline + 1);
        newline = buffer.indexOf("\n");
      }
    },
    verify() {
      if (buffer.trim()) throw new Error("Incomplete Pi JSON record");
      if (parseError) throw new Error(parseError);
      if (!settled || !finalMessage)
        throw new Error("Pi exited before completing the scheduled prompt");
      if (
        finalMessage.stopReason !== "stop" &&
        finalMessage.stopReason !== "length"
      )
        throw new Error(
          finalMessage.errorMessage || `Pi stopped: ${finalMessage.stopReason}`,
        );
    },
  };
}
