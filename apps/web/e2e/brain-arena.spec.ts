import { test, expect, type Page, type Browser } from "@playwright/test";
async function enter(page: Page, name: string) {
  await page.goto("/");
  await page
    .getByRole("textbox", { name: "Your name", exact: true })
    .fill(name);
  await page.getByRole("button", { name: "Let's play", exact: true }).click();
}
async function arena(page: Page, browser: Browser, mode: string) {
  await enter(page, "Brain white");
  await page.getByRole("button", { name: "Brain arena", exact: true }).click();
  await page.locator(".mode").filter({ hasText: mode }).click();
  await page
    .getByRole("button", { name: "Create brain match", exact: true })
    .click();
  const code = await page.locator(".invite-code").innerText();
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
  });
  const black = await context.newPage();
  await enter(black, "Brain black");
  await black
    .locator(".mobile-nav button")
    .filter({ hasText: "Brain" })
    .click();
  await black
    .getByRole("button", { name: "Join with a friend code", exact: true })
    .click();
  await black
    .getByRole("textbox", { name: "Friend code", exact: true })
    .fill(code);
  await black.getByRole("button", { name: "Join match", exact: true }).click();
  await expect(page.locator(".brain-game")).toBeVisible();
  await expect(black.locator(".brain-game")).toBeVisible();
  return { black, context };
}
function calculate(text: string) {
  const [a, op, b] = text.trim().split(/\s+/);
  return op === "+"
    ? Number(a) + Number(b)
    : op === "-"
      ? Number(a) - Number(b)
      : Number(a) * Number(b);
}
test("mental math is one question at a time, autosubmits both scores and rematches", async ({
  page,
  browser,
}) => {
  const { black, context } = await arena(page, browser, "Mental sprint");
  for (const [p, count] of [
    [page, 3],
    [black, 2],
  ] as const) {
    for (let i = 0; i < count; i++) {
      const q = await p.locator(".question strong").innerText();
      await p
        .getByRole("textbox", { name: "Your answer", exact: true })
        .fill(String(calculate(q)));
      await p
        .getByRole("button", { name: "Next question", exact: true })
        .click();
    }
    expect(await p.locator(".question strong").count()).toBe(1);
  }
  await expect(page.locator(".result")).toBeVisible({ timeout: 40000 });
  await expect(page.locator(".final-score strong")).toHaveText("3 : 2");
  await expect(black.locator(".final-score strong")).toHaveText("3 : 2");
  await page.getByRole("button", { name: "Play again", exact: true }).click();
  await black
    .getByRole("button", { name: "Accept rematch", exact: true })
    .click();
  await expect(
    page.getByRole("heading", { name: "Mental sprint", exact: true }),
  ).toBeVisible();
  await context.close();
});
test("dot connect accepts a legal continuous path and records both players scores", async ({
  page,
  browser,
}) => {
  const { black, context } = await arena(page, browser, "Connect the dots");
  await Promise.all([page, black].map(async (p) => {
    for (let r = 0; r < 5; r++)
      for (let k = 0; k < 5; k++) {
        const c = r % 2 ? 4 - k : k;
        await p
          .getByRole("button", {
            name: `Dot row ${r + 1} column ${c + 1}`,
            exact: true,
          })
          .dispatchEvent("click");
      }
    await p.getByRole("button", { name: "Submit path", exact: true }).click();
  }));
  await expect(page.locator(".result")).toBeVisible({ timeout: 40000 });
  await expect(page.locator(".final-score strong")).toHaveText("1 : 1");
  await expect(black.locator(".final-score strong")).toHaveText("1 : 1");
  await context.close();
});
test("memory shows picks immediately, hides mismatches, preserves pairs and finishes", async ({
  page,
  browser,
}) => {
  test.setTimeout(160000);
  const { black, context } = await arena(page, browser, "Memory match");
  const known = new Map<number, string>();
  let turns = 0;
  while (!(await page.locator(".result").count()) && turns++ < 35) {
    const p = (await page.locator(".brain-game>.muted").innerText()).includes(
      "Your turn",
    )
      ? page
      : black;
    const available = await p
      .locator(".memory-card")
      .evaluateAll((elements) =>
        elements
          .map((e, i) => (!e.classList.contains("matched") ? i : -1))
          .filter((i) => i >= 0),
      );
    if (!available.length) break;
    const pair = available.flatMap((a, i) =>
      available
        .slice(i + 1)
        .filter((b) => known.has(a) && known.get(a) === known.get(b))
        .map((b) => [a, b]),
    )[0];
    const first =
      pair?.[0] ?? available.find((i) => !known.has(i)) ?? available[0];
    const firstButton = p.locator(".memory-card").nth(first);
    await expect(firstButton).toBeEnabled();
    await firstButton.click();
    await expect(firstButton.locator("img")).toBeVisible();
    known.set(first, (await firstButton.locator("img").getAttribute("alt"))!);
    const second =
      pair?.[1] ??
      available.find((i) => i !== first && known.get(i) === known.get(first)) ??
      available.find((i) => i !== first && !known.has(i)) ??
      available.find((i) => i !== first)!;
    const secondButton = p.locator(".memory-card").nth(second);
    await expect(secondButton).toBeEnabled();
    await secondButton.click();
    if (await secondButton.count()) {
      const img = secondButton.locator("img");
      await expect(img).toBeVisible();
      known.set(second, (await img.getAttribute("alt"))!);
    }
  }
  await expect(page.locator(".result")).toBeVisible({ timeout: 10000 });
  const score = await page.locator(".final-score strong").innerText();
  expect(score.split(":").reduce((sum, s) => sum + Number(s.trim()), 0)).toBe(
    6,
  );
  expect(
    await black.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth,
    ),
  ).toBe(true);
  await context.close();
});
