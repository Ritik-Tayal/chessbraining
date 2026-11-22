import { test, expect, type Page } from "@playwright/test";
async function guest(page: Page, name: string) {
  await page.goto("/");
  await page
    .getByRole("textbox", { name: "Your name", exact: true })
    .fill(name);
  await page.getByRole("button", { name: "Let's play", exact: true }).click();
}
async function move(page: Page, from: string, to: string) {
  await expect(page.locator(".board-tools")).toContainText("Your move");
  await page.locator(`[data-square=${from}]`).click();
  await expect(page.locator(".move-dot,.capture-ring").first()).toBeVisible();
  const pending = page.waitForResponse(
    (r) => r.url().endsWith("/moves") && r.request().method() === "POST",
  );
  await page.locator(`[data-square=${to}]`).click();
  expect((await pending).status()).toBe(200);
}

test("cancelling quickplay removes the abandoned waiting game", async ({
  page,
  browser,
}) => {
  await guest(page, "Cancel host");
  await page.getByRole("button", { name: /Play now/ }).click();
  const oldCode = await page.locator(".invite-code").innerText();
  await page.getByRole("button", { name: "Cancel match", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "ChessBraining", exact: true }),
  ).toBeVisible();
  const ctx = await browser.newContext();
  const next = await ctx.newPage();
  await guest(next, "Next guest");
  await next.getByRole("button", { name: /Play now/ }).click();
  await expect(next.locator(".invite-code")).toBeVisible();
  expect(await next.locator(".invite-code").innerText()).not.toBe(oldCode);
  await next.getByRole("button", { name: "Cancel match", exact: true }).click();
  await ctx.close();
});

test("quickplay pairs two guests, syncs ten moves, settles a brain round, spends BP, resigns and rematches", async ({
  page,
  browser,
}) => {
  test.setTimeout(240000);
  await page.setViewportSize({ width: 1440, height: 1000 });
  await guest(page, "Desktop player");
  const ctx = await browser.newContext({
    viewport: { width: 390, height: 844 },
  });
  const mobile = await ctx.newPage();
  await guest(mobile, "Mobile player");
  await page.getByRole("button", { name: /Play now/ }).click();
  await expect(page.locator(".invite-code")).toBeVisible();
  const invite = await page.locator(".invite-code").innerText();
  await mobile.getByRole("button", { name: /Play now/ }).click();
  await expect(page.locator(".waiting")).toHaveCount(0);
  await expect(mobile.locator(".waiting")).toHaveCount(0);
  expect(await mobile.locator(".match-share").innerText()).toContain(
    invite.trim(),
  );
  for (const [who, from, to] of [
    [0, "e2", "e4"],
    [1, "e7", "e5"],
    [0, "g1", "f3"],
    [1, "b8", "c6"],
    [0, "f1", "c4"],
    [1, "g8", "f6"],
    [0, "d2", "d3"],
    [1, "f8", "c5"],
    [0, "c2", "c3"],
    [1, "d7", "d6"],
  ] as const)
    await move(who === 0 ? page : mobile, from, to);
  await expect(page.locator(".brain-game")).toBeVisible();
  await expect(mobile.locator(".brain-game")).toBeVisible();
  expect(
    await mobile.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth,
    ),
  ).toBe(true);
  // Let the server deadline settle every randomly selected game, including memory.
  await expect(page.locator(".result-notice")).toBeVisible({ timeout: 125000 });
  await expect(mobile.locator(".result-notice")).toBeVisible();
  await page.getByRole("button", { name: "Back to the board" }).click();
  await mobile.getByRole("button", { name: "Back to the board" }).click();
  await expect(page.locator(".cost")).toContainText("1 BP");
  await page.getByRole("button", { name: /Time boost.*1 BP/ }).click();
  await expect(page.locator(".cost")).toContainText("0 BP");
  await page.getByRole("button", { name: "Resign", exact: true }).click();
  await page.getByRole("button", { name: "Resign match", exact: true }).click();
  await expect(mobile.locator(".result")).toBeVisible();
  await page.getByRole("button", { name: "Play again", exact: true }).click();
  await mobile
    .getByRole("button", { name: "Accept rematch", exact: true })
    .click();
  await expect(page.locator(".result")).toHaveCount(0);
  await expect(page.locator(".player-row.opponent")).toContainText(
    "Desktop player",
  );
  await ctx.close();
});

test("friend codes and checkmate work, move log reviews the board, guest rename persists", async ({
  page,
  browser,
}) => {
  test.setTimeout(150000);
  await guest(page, "White guest");
  await page.getByRole("button", { name: /Play with a friend/ }).click();
  await page.getByRole("button", { name: "Create match", exact: true }).click();
  const code = await page.locator(".invite-code").innerText();
  const ctx = await browser.newContext();
  const black = await ctx.newPage();
  await guest(black, "Black guest");
  await black.getByRole("button", { name: /Have a friend code/ }).click();
  await black
    .getByRole("textbox", { name: "Friend code", exact: true })
    .fill(code);
  await black.getByRole("button", { name: "Join match", exact: true }).click();
  await move(page, "f2", "f3");
  await move(black, "e7", "e5");
  await page.locator(".move-log button").first().click();
  await expect(page.locator(".board-tools")).toContainText("Reviewing move 1");
  await expect(page.locator("[data-square=e7] img")).toBeVisible();
  await page.getByRole("button", { name: "Live board", exact: true }).click();
  await move(page, "g2", "g4");
  await move(black, "d8", "h4");
  await expect(page.locator(".result")).toBeVisible();
  await expect(black.locator(".result")).toContainText("That one is yours");
  await page
    .getByRole("button", { name: "Back to lobby", exact: true })
    .click();
  await page.getByRole("button", { name: "Your profile", exact: true }).click();
  await page
    .getByRole("textbox", { name: "Display name", exact: true })
    .fill("Renamed guest");
  await page.getByRole("button", { name: "Save name", exact: true }).click();
  await expect(page.locator(".toast")).toContainText("Profile updated");
  await page.reload();
  await expect(page.locator(".profile-button")).toContainText("Renamed guest");
  await ctx.close();
});

test("bot setup starts a real match and computer replies", async ({ page }) => {
  await page.addInitScript(() => {
    const Native = window.AudioContext;
    let tones = 0;
    Object.defineProperty(window, "__tones", { get: () => tones });
    window.AudioContext = class extends Native {
      createOscillator() {
        tones++;
        return super.createOscillator();
      }
    };
  });
  await guest(page, "Bot challenger");
  await page.getByRole("button", { name: /Challenge the computer/ }).click();
  await expect(
    page.getByRole("heading", { name: "Meet your next challenge." }),
  ).toBeVisible();
  await page.getByRole("button", { name: /Strategist/ }).click();
  const created = page.waitForResponse(
    (response) =>
      response.url().endsWith("/matches/bot") &&
      response.request().method() === "POST",
  );
  await page.getByRole("button", { name: "Start match", exact: true }).click();
  expect((await created).status()).toBe(200);
  await move(page, "e2", "e4");
  await expect(page.locator(".move-log-heading")).toContainText("2 played", {
    timeout: 20000,
  });
  await expect(page.locator(".error")).toHaveCount(0);
  expect(
    await page.evaluate(
      () => (window as unknown as { __tones: number }).__tones,
    ),
  ).toBeGreaterThan(0);
});
