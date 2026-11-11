import { describe, expect, test } from "bun:test";
import { readFlagValue } from "./cli.ts";

describe("readFlagValue", () => {
  test("reads inline and separate values", () => {
    expect(readFlagValue(["--query=inline"], "query")).toBe("inline");
    expect(readFlagValue(["--query", "separate"], "query")).toBe("separate");
  });

  test("returns an empty string for a missing or valueless flag", () => {
    expect(readFlagValue([], "query")).toBe("");
    expect(readFlagValue(["--query"], "query")).toBe("");
    expect(readFlagValue(["--query="], "query")).toBe("");
  });

  test("preserves inline precedence and exact flag names", () => {
    expect(
      readFlagValue(["--query", "separate", "--query=inline"], "query"),
    ).toBe("inline");
    expect(readFlagValue(["--queryExtra=value"], "query")).toBe("");
  });
});
