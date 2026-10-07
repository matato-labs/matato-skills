import { describe, expect, test } from "bun:test";
import { createPiOutput } from "./piOutput.ts";
import { piEvents } from "./testFixtures.ts";

describe("Pi JSON completion", () => {
  test("chunked CRLF records accept success and retry recovery", () => {
    const output = createPiOutput();
    const records = (
      piEvents("error", "bad\u2028provider") + piEvents()
    ).replace(/\n/g, "\r\n");
    for (let offset = 0; offset < records.length; offset += 7)
      output.write(records.slice(offset, offset + 7));
    expect(() => output.verify()).not.toThrow();
  });

  test("failure and aborted responses reject even after agent_settled", () => {
    for (const reason of [
      "error",
      "aborted",
      "pending",
      "deferred",
      "toolUse",
    ]) {
      const output = createPiOutput();
      output.write(piEvents(reason));
      expect(() => output.verify()).toThrow(`Pi stopped: ${reason}`);
    }
  });

  test("early exits, malformed records, and partial records fail", () => {
    const empty = createPiOutput();
    expect(() => empty.verify()).toThrow("before completing");
    const early = createPiOutput();
    early.write(piEvents().replace('{"type":"agent_settled"}\n', ""));
    expect(() => early.verify()).toThrow("before completing");
    const malformed = createPiOutput();
    malformed.write("not json\n" + piEvents());
    expect(() => malformed.verify()).toThrow("Invalid Pi JSON");
    const partial = createPiOutput();
    partial.write(piEvents() + '{"type":');
    expect(() => partial.verify()).toThrow("Incomplete Pi JSON");
  });
});
