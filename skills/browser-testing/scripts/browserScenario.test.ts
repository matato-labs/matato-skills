import { describe, expect, test } from "bun:test";
import { resolveTarget, stepArguments } from "./browserScenario.ts";

const snapshot = `- document:
  - textbox "Name" [active] [ref=e2]: Ada
  - button "Save" [ref=e3]
  - checkbox "Updates" [checked] [ref=e4]
  - generic [ref=e5]: Saved`;

describe("browser scenario", () => {
  test("resolves exact live labels and strips state metadata", () => {
    expect(resolveTarget(snapshot, 'textbox "Name"')).toBe("e2");
    expect(resolveTarget(snapshot, 'checkbox "Updates"')).toBe("e4");
  });

  test("rejects missing, partial, guessed, and ambiguous targets", () => {
    for (const target of ['button "Delete"', "Save", "e3"])
      expect(() => resolveTarget(snapshot, target)).toThrow("matched 0");
    expect(() =>
      resolveTarget(`${snapshot}\n- button "Save" [ref=e6]`, 'button "Save"'),
    ).toThrow("matched 2");
  });

  test("uses refs from the supplied snapshot, not an older one", () => {
    expect(
      stepArguments({ action: "click", target: 'button "Save"' }, snapshot),
    ).toEqual(["click", "e3"]);
    expect(
      stepArguments(
        { action: "click", target: 'button "Save"' },
        snapshot.replace("e3", "e99"),
      ),
    ).toEqual(["click", "e99"]);
  });

  test("keeps fill values as one argument and supports keyboard steps", () => {
    expect(
      stepArguments(
        { action: "fill", target: 'textbox "Name"', value: 'Ada "Lovelace"' },
        snapshot,
      ),
    ).toEqual(["fill", "e2", 'Ada "Lovelace"']);
    expect(stepArguments({ action: "press", key: "Enter" }, snapshot)).toEqual([
      "press",
      "Enter",
    ]);
  });
});
