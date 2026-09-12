import { expect, test } from "bun:test";

const changeGate = await Bun.file("skills/change-gate/SKILL.md").text();
const verification = await Bun.file(
  "skills/ui-change-verification/SKILL.md",
).text();

test("change gate runs UI verification after its other specialists", () => {
  const specialists = [
    "$acceptance-criteria-review",
    "$general-change-review",
    "$mutation-testing-review",
    "$quality-checks-review",
    "$ui-change-verification",
  ];

  expect(
    specialists.map((specialist) => changeGate.indexOf(specialist)),
  ).toEqual([
    ...specialists
      .map((specialist) => changeGate.indexOf(specialist))
      .sort((left, right) => left - right),
  ]);
  expect(changeGate).toContain("After all five subagents return");
});

test("UI verification skips non-demonstrable changes and focuses browser evidence", () => {
  expect(verification).toContain(
    "no meaningful, demonstrable user-visible UI change, do not test and do not comment on the PR",
  );
  expect(verification).toContain(
    "invoke `$browser-testing` and test only the changed UI paths",
  );
  expect(verification).toContain("free port other than `4000`");
  expect(verification).toContain(
    "Capture only screenshots that prove the changed UI looks correct",
  );
  expect(verification).toContain("exactly one PR comment");
});
