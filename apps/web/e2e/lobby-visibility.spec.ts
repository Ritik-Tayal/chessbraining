import { test, expect } from "@playwright/test";
async function enter(page: import("@playwright/test").Page) {
  await page.goto("/");
  await page
    .getByRole("textbox", { name: "Your name", exact: true })
    .fill("Lobby guest");
  await page.getByRole("button", { name: "Let's play", exact: true }).click();
}
test("lobby is free of live-game controls on desktop and mobile", async ({
  page,
}) => {
  await enter(page);
  for (const width of [1366, 390]) {
    await page.setViewportSize({ width, height: 844 });
    await expect(
      page.getByRole("heading", { name: "ChessBraining", exact: true }),
    ).toBeVisible();
    for (const selector of [
      ".brain-countdown",
      ".clock",
      ".brain-game",
      ".game-powers",
      ".status",
      ".result-notice",
    ])
      await expect(page.locator(`${selector}:visible`)).toHaveCount(0);
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= innerWidth,
      ),
    ).toBe(true);
  }
});
test("waiting matches do not show a countdown and can be resumed from home", async ({
  page,
}) => {
  await enter(page);
  await page.getByRole("button", { name: /Play with a friend/ }).click();
  await page.getByRole("button", { name: "Create match", exact: true }).click();
  await expect(page.locator(".waiting")).toBeVisible();
  await expect(page.locator(".brain-countdown:visible")).toHaveCount(0);
  await page.getByRole("button", { name: "Play chess", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "ChessBraining", exact: true }),
  ).toBeVisible();
  await expect(page.locator(".clock:visible")).toHaveCount(0);
  await page
    .getByRole("button", { name: "Return to match", exact: true })
    .click();
  await expect(page.locator(".waiting")).toBeVisible();
  await page.getByRole("button", { name: "Cancel match", exact: true }).click();
  await expect(page.locator(".resume-match")).toHaveCount(0);
});
test("navigation hides a running game, resumes the same board and hides the countdown after completion", async ({
  page,
}) => {
  await enter(page);
  await page.getByRole("button", { name: /Challenge the computer/ }).click();
  await page.getByRole("button", { name: /Casual/ }).click();
  await page.getByRole("button", { name: "Start match", exact: true }).click();
  await expect(page.locator(".brain-countdown")).toBeVisible();
  const code = await page.locator(".match-share b").innerText();
  await page.getByRole("button", { name: "Play chess", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "ChessBraining", exact: true }),
  ).toBeVisible();
  for (const selector of [
    ".brain-countdown",
    ".clock",
    ".game-powers",
    ".status",
  ])
    await expect(page.locator(`${selector}:visible`)).toHaveCount(0);
  await page.getByRole("button", { name: /Play now/ }).click();
  await expect(page.locator(".match-share b")).toHaveText(code);
  await page.getByRole("button", { name: "Your profile", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Make your mark.", exact: true }),
  ).toBeVisible();
  await page
    .getByRole("button", { name: "Return to match", exact: true })
    .click();
  await expect(page.locator(".match-share b")).toHaveText(code);
  await page.getByRole("button", { name: "Resign", exact: true }).click();
  await page.getByRole("button", { name: "Resign match", exact: true }).click();
  await expect(page.locator(".result")).toBeVisible();
  await expect(page.locator(".brain-countdown:visible")).toHaveCount(0);
});
