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
      await expect(p.locator(".question span")).toContainText(
        `QUESTION ${i + 2}`,
      );
    }
    expect(await p.locator(".question strong").count()).toBe(1);
  }
  await expect(black.locator(".round-scores")).toContainText("White 3", {
    timeout: 10000,
  });
  await page
    .getByRole("button", { name: "Skip question", exact: true })
    .click();
  await expect(page.locator(".question span")).toContainText("QUESTION 5");
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
  await Promise.all(
    [page, black].map(async (p) => {
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
    }),
  );
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
  let side = (await page.locator(".brain-game>.muted").innerText()).includes(
    "Your turn",
  )
    ? "WHITE"
    : "BLACK";
  while (!(await page.locator(".result").count()) && turns++ < 35) {
    const p = side === "WHITE" ? page : black;
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
    const pending = p.waitForResponse(
      (r) =>
        r.url().endsWith("/memory-turns") && r.request().method() === "POST",
    );
    await secondButton.click();
    const response = await pending;
    expect(response.ok()).toBe(true);
    const round = await response.json();
    if (round.status === "COMPLETED") break;
    side = JSON.parse(round.puzzles[0]).turnSide;
    if (await secondButton.count()) {
      const img = secondButton.locator("img");
      await expect(img).toBeVisible();
      known.set(second, (await img.getAttribute("alt"))!);
    }
  }
  await expect(page.locator(".result")).toBeVisible({ timeout: 10000 });
  const score = await page.locator(".final-score strong").innerText();
  expect(score.split(":").reduce((sum, s) => sum + Number(s.trim()), 0)).toBe(
    12,
  );
  expect(
    await black.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth,
    ),
  ).toBe(true);
  await context.close();
});

async function game(page: Page, browser: Browser, mode: string) {
  const white = {
    playerId: `speed_w_${Date.now()}`,
    playerName: "Speed white",
  };
  const black = {
    playerId: `speed_b_${Date.now()}`,
    playerName: "Speed black",
  };
  const created = await (
    await page.request.post("/api/v1/brain-matches", {
      data: { ...white, mode },
    })
  ).json();
  const joined = await (
    await page.request.post("/api/v1/brain-matches/join", {
      data: { ...black, inviteCode: created.inviteCode },
    })
  ).json();
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
  });
  const opponent = await context.newPage();
  for (const [p, guest] of [
    [page, white],
    [opponent, black],
  ] as const) {
    await p.addInitScript(
      ({ guest, id }) => {
        localStorage.setItem("cb-web-guest", JSON.stringify(guest));
        localStorage.setItem(
          "cb-web-active",
          JSON.stringify({ kind: "brain", id }),
        );
      },
      { guest, id: created.matchId },
    );
    await p.goto("/");
    await expect(p.locator(".brain-game")).toBeVisible();
  }
  return { opponent, context, joined };
}

test("final math scores do not wait for stalled progress or regress after a late response", async ({
  page,
  browser,
}) => {
  const { opponent, context, joined } = await game(
    page,
    browser,
    "MENTAL_MATH",
  );
  let release = () => {};
  let progressStarted = false;
  await page.route("**/math-submissions", async (route) => {
    if (route.request().postDataJSON().finalSubmission === false) {
      progressStarted = true;
      await new Promise<void>((resolve) => {
        release = resolve;
      });
    }
    await route.continue();
  });
  const field = page.getByRole("textbox", { name: "Your answer", exact: true });
  await field.fill(String(joined.solutions[0]));
  await expect.poll(() => progressStarted).toBe(true);
  for (let i = 1; i < joined.solutions.length; i++) {
    await field.fill(String(joined.solutions[i]));
    if (i + 1 < joined.solutions.length)
      await expect(page.locator(".question span")).toContainText(
        `QUESTION ${i + 2}`,
      );
  }
  await expect(
    page.getByRole("heading", { name: "Answers locked in", exact: true }),
  ).toBeVisible();
  for (let i = 0; i < joined.totalQuestions; i++) {
    await opponent
      .getByRole("button", { name: "Skip question", exact: true })
      .dispatchEvent("click");
    if (i + 1 < joined.totalQuestions)
      await expect(opponent.locator(".question span")).toContainText(
        `QUESTION ${i + 2}`,
      );
  }
  await expect(page.locator(".final-score strong")).toHaveText("30 : 0");
  const late = page.waitForResponse(
    (r) =>
      r.url().endsWith("/math-submissions") &&
      r.request().postDataJSON()?.finalSubmission === false,
  );
  release();
  await late;
  await expect(page.locator(".final-score strong")).toHaveText("30 : 0");
  await context.close();
});

test("math input advances while progress request is delayed; skip does not score", async ({
  page,
  browser,
}) => {
  const { opponent, context, joined } = await game(
    page,
    browser,
    "MENTAL_MATH",
  );
  await page.route("**/math-submissions", async (route) => {
    if (route.request().postDataJSON().finalSubmission === false)
      await new Promise((resolve) => setTimeout(resolve, 1500));
    await route.continue();
  });
  const field = page.getByRole("textbox", { name: "Your answer", exact: true });
  await field.fill(String(joined.solutions[0] + 1000));
  await expect(page.locator(".question span")).toContainText("QUESTION 1");
  await field.fill(String(joined.solutions[0]));
  await expect(page.locator(".question span")).toContainText("QUESTION 2");
  await field.fill(String(joined.solutions[1]));
  await expect(page.locator(".question span")).toContainText("QUESTION 3");
  await page
    .getByRole("button", { name: "Skip question", exact: true })
    .click();
  await expect(page.locator(".question span")).toContainText("QUESTION 4");
  await expect(opponent.locator(".round-scores")).toContainText("White 2", {
    timeout: 10000,
  });
  await page.reload();
  await expect(page.locator(".question span")).toContainText("QUESTION 4");
  await expect(page.locator(".result")).toBeVisible({ timeout: 40000 });
  await expect(page.locator(".final-score strong")).toHaveText("2 : 0");
  await context.close();
});

test("memory has 24 colored cards and forfeits an unfinished eight-second turn", async ({
  page,
  browser,
}, testInfo) => {
  const { opponent, context, joined } = await game(page, browser, "MEMORY");
  await expect(page.locator(".memory-card")).toHaveCount(24);
  expect(
    await page
      .locator(".memory-grid")
      .evaluate(
        (e) => getComputedStyle(e).gridTemplateColumns.split(" ").length,
      ),
  ).toBe(6);
  const initial = await (
    await page.request.get(`/api/v1/brain-matches/${joined.matchId}`)
  ).json();
  const board = JSON.parse(initial.puzzles[0]);
  const actor = board.turnSide === "WHITE" ? page : opponent;
  await actor.locator(".memory-card").first().click();
  await expect(
    actor.locator(".memory-card").first().locator("img"),
  ).toBeVisible();
  expect(
    await actor
      .locator(".memory-card")
      .first()
      .locator("img")
      .getAttribute("alt"),
  ).toMatch(/^[wb][PNBRQK]$/);
  await opponent.screenshot({
    path: testInfo.outputPath("memory-mobile.png"),
    fullPage: true,
  });
  await expect(actor.locator(".memory-turn-clock")).toContainText(
    "Opponent's turn",
    { timeout: 11000 },
  );
  await expect(actor.locator(".memory-card.revealed")).toHaveCount(0);
  const current = await (
    await page.request.get(`/api/v1/brain-matches/${joined.matchId}`)
  ).json();
  expect(JSON.parse(current.puzzles[0]).pendingFirstIndex).toBeNull();
  expect(current.whiteScore + current.blackScore).toBe(0);
  expect(
    await opponent.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth,
    ),
  ).toBe(true);
  await context.close();
});

test("math supports physical keyboard answers and Enter skips exactly one question", async ({
  page,
  browser,
}) => {
  const { context, joined } = await game(page, browser, "MENTAL_MATH");
  await page.locator(".brain-game h2").click();
  await page.keyboard.type(String(joined.solutions[0]), { delay: 70 });
  await expect(page.locator(".question span")).toContainText("QUESTION 2 /");
  await page.keyboard.press("Enter");
  await expect(page.locator(".question span")).toContainText("QUESTION 3 /");
  await page.locator(".number-pad button").filter({ hasText: /^-$/ }).click();
  await page.keyboard.press("Backspace");
  await expect(
    page.getByRole("textbox", { name: "Your answer", exact: true }),
  ).toHaveValue("");
  await page.keyboard.type(String(joined.solutions[2]), { delay: 70 });
  await expect(page.locator(".question span")).toContainText("QUESTION 4 /");
  await page.getByRole("textbox", { name: "Your answer", exact: true }).focus();
  await page.keyboard.press("Enter");
  await expect(page.locator(".question span")).toContainText("QUESTION 5 /");
  await expect(page.locator(".round-scores")).toContainText("White 2");
  await context.close();
});
