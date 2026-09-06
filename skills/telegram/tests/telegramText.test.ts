import { describe, expect, test } from "bun:test";
import { normalizeTelegramText } from "../scripts/telegramText.ts";

describe("normalizeTelegramText", () => {
  test("converts escaped newlines into line breaks", () => {
    const input =
      "Daily digest\\n\\nTechnology: Headline\\nhttps://example.com/story";

    expect(normalizeTelegramText(input)).toBe(
      "Daily digest\n\nTechnology: Headline\nhttps://example.com/story",
    );
  });

  test("keeps existing line breaks unchanged", () => {
    const input =
      "Daily digest\n\nTechnology: Headline\nhttps://example.com/story";

    expect(normalizeTelegramText(input)).toBe(input);
  });
});
