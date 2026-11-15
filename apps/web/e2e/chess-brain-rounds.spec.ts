import { test, expect, type Page, type Browser } from "@playwright/test";

// Setup uses public APIs; the game, submissions, scoring and chess resume run in the browser.
async function chessRound(page: Page, browser: Browser, type: string) {
  const stamp = `${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  const white = { playerId: `player_cw_${stamp}`, playerName: "Chess white" };
  const black = { playerId: `player_cb_${stamp}`, playerName: "Chess black" };
  async function post(path: string, data: unknown) {
    const r = await page.request.post(`http://localhost:5173/api/v1${path}`, {
      data,
    });
    expect(r.ok(), await r.text()).toBe(true);
    return r.json();
  }
  let found: any;
  for (let attempt = 0; attempt < 24; attempt++) {
    const match = await post("/matches", {
      ...white,
      timeControlSeconds: 600,
      brainRoundIntervalMoves: 5,
    });
    await post("/matches/join", { ...black, inviteCode: match.inviteCode });
    for (const [side, from, to] of [
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
      await post(`/matches/${match.matchId}/moves`, {
        playerId: side === 0 ? white.playerId : black.playerId,
        from,
        to,
      });
    const r = await page.request.get(
      `http://localhost:5173/api/v1/matches/${match.matchId}/brain-rounds/current`,
    );
    expect(r.ok()).toBe(true);
    const round = await r.json();
    if (round.puzzleType === type) {
      found = match;
      break;
    }
    await post(`/matches/${match.matchId}/resign`, {
      playerId: white.playerId,
    });
  }
  expect(
    found,
    `Expected the server's random chooser to produce ${type}`,
  ).toBeTruthy();
  async function seed(p: Page, guest: typeof white) {
    await p.addInitScript(
      ({ guest, id }) => {
        localStorage.setItem("cb-web-guest", JSON.stringify(guest));
        localStorage.setItem(
          "cb-web-active",
          JSON.stringify({ kind: "chess", id }),
        );
      },
      { guest, id: found.matchId },
    );
    await p.goto("/");
    await expect(p.locator(".brain-game")).toBeVisible();
  }
  await seed(page, white);
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
  });
  const opponent = await context.newPage();
  await seed(opponent, black);
  return { opponent, context, id: found.matchId, white, post };
}
function calculate(expression: string) {
  const [a, op, b] = expression.split(/\s+/);
  return op === "+" ? +a + +b : op === "-" ? +a - +b : +a * +b;
}
async function assertResume(page: Page, opponent: Page) {
  await expect(page.locator(".result-notice")).toBeVisible({ timeout: 40000 });
  await expect(opponent.locator(".result-notice")).toBeVisible({
    timeout: 10000,
  });
  const scores = await page.locator(".score-result strong").allTextContents();
  expect(
    await opponent.locator(".score-result strong").allTextContents(),
  ).toEqual(scores);
  await page
    .getByRole("button", { name: "Back to the board", exact: true })
    .click();
  await opponent
    .getByRole("button", { name: "Back to the board", exact: true })
    .click();
  await expect(page.locator(".brain-game:visible")).toHaveCount(0);
  await expect(page.locator(".board-tools")).toContainText("Your move");
  await page.locator("[data-square=a2]").click();
  await expect(page.locator(".move-dot").first()).toBeVisible();
  await page.locator("[data-square=a3]").click();
  await expect(page.locator(".move-log")).toContainText("a3");
  return scores.map(Number);
}
test("chess mental math survives refresh, scores both players and resumes chess", async ({
  page,
  browser,
}) => {
  test.setTimeout(180000);
  const game = await chessRound(page, browser, "MENTAL_MATH");
  for (const [p, count] of [
    [page, 3],
    [game.opponent, 2],
  ] as const)
    for (let i = 0; i < count; i++) {
      const answer = calculate(await p.locator(".question strong").innerText());
      await p
        .getByRole("textbox", { name: "Your answer", exact: true })
        .fill(String(answer));
      await p
        .getByRole("button", { name: "Next question", exact: true })
        .click();
    }
  await expect(page.locator(".question span")).toContainText("QUESTION 4");
  await page.reload();
  await expect(page.locator(".question span")).toContainText("QUESTION 4");
  expect(await assertResume(page, game.opponent)).toEqual([3, 2]);
  await game.post(`/matches/${game.id}/resign`, {
    playerId: game.white.playerId,
  });
  await game.context.close();
});
test("chess dot connect records both scores and resumes chess", async ({
  page,
  browser,
}) => {
  test.setTimeout(180000);
  const game = await chessRound(page, browser, "DOT_CONNECT");
  await Promise.all([page, game.opponent].map(async (p) => {
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
  expect(await assertResume(page, game.opponent)).toEqual([1, 1]);
  await game.post(`/matches/${game.id}/resign`, {
    playerId: game.white.playerId,
  });
  await game.context.close();
});
test("chess memory reveals cards, clears all pairs, awards BP and resumes chess", async ({
  page,
  browser,
}) => {
  test.setTimeout(180000);
  const game = await chessRound(page, browser, "MEMORY");
  const known = new Map<number, string>();
  let side = "WHITE";
  let turns = 0;
  while (!(await page.locator(".result-notice").count()) && turns++ < 36) {
    const p = side === "WHITE" ? page : game.opponent;
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
    const a = p.locator(".memory-card").nth(first);
    await expect(a).toBeEnabled();
    await a.click();
    await expect(a.locator("img")).toBeVisible();
    known.set(first, (await a.locator("img").getAttribute("alt"))!);
    const second =
      pair?.[1] ??
      available.find((i) => i !== first && known.get(i) === known.get(first)) ??
      available.find((i) => i !== first && !known.has(i)) ??
      available.find((i) => i !== first)!;
    const b = p.locator(".memory-card").nth(second);
    await expect(b).toBeEnabled();
    const pending = p.waitForResponse(
      (r) =>
        r.url().endsWith("/memory-turns") && r.request().method() === "POST",
    );
    await b.click();
    const response = await pending;
    expect(response.ok()).toBe(true);
    const round = await response.json();
    if (round.status === "COMPLETED") break;
    await expect(b.locator("img")).toBeVisible();
    known.set(second, (await b.locator("img").getAttribute("alt"))!);
    side = JSON.parse(round.puzzles[0]).turnSide;
  }
  const scores = await assertResume(page, game.opponent);
  expect(scores[0] + scores[1]).toBe(6);
  await expect(page.locator(".power-bar-title .cost")).toContainText(
    scores[0] === scores[1] ? "1 BP" : scores[0] > scores[1] ? "2 BP" : "0 BP",
  );
  await game.post(`/matches/${game.id}/resign`, {
    playerId: game.white.playerId,
  });
  await game.context.close();
});
