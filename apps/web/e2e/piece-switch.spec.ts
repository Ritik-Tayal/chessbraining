import { test, expect, type Page } from "@playwright/test";
import { switchSolution, type SwitchQuestion } from "../src/pieceSwitchRules";

test("expert bot readies itself, scores live in Piece Switch and returns to chess", async ({
  page,
}) => {
  test.setTimeout(150000);
  const guest = {
    playerId: `switch_bot_human_${Date.now()}`,
    playerName: "Bot challenger",
  };
  async function post(path: string, data: unknown) {
    const response = await page.request.post(`/api/v1${path}`, { data });
    expect(response.ok(), await response.text()).toBe(true);
    return response.json();
  }
  let selected: any;
  let round: any;
  for (let attempt = 0; attempt < 24; attempt++) {
    const match = await post("/matches/bot", {
      ...guest,
      difficulty: "EXPERT",
      preferredSide: "WHITE",
      timeControlSeconds: 600,
      brainRoundIntervalMoves: 1,
    });
    await post(`/matches/${match.matchId}/moves`, {
      playerId: guest.playerId,
      from: "e2",
      to: "e4",
    });
    await expect
      .poll(
        async () =>
          (
            await (
              await page.request.get(`/api/v1/matches/${match.matchId}`)
            ).json()
          ).phase,
        { timeout: 15000 },
      )
      .toBe("BRAIN_ROUND");
    round = await (
      await page.request.get(
        `/api/v1/matches/${match.matchId}/brain-rounds/current`,
      )
    ).json();
    if (round.puzzleType === "PIECE_SWITCH") {
      selected = match;
      break;
    }
    await post(`/matches/${match.matchId}/resign`, {
      playerId: guest.playerId,
    });
  }
  expect(selected).toBeTruthy();
  await page.addInitScript(
    ({ guest, id }) => {
      localStorage.setItem("cb-web-guest", JSON.stringify(guest));
      localStorage.setItem(
        "cb-web-active",
        JSON.stringify({ kind: "chess", id }),
      );
    },
    { guest, id: selected.matchId },
  );
  await page.goto("/");
  await expect(page.locator(".switch-stimulus")).toBeVisible({
    timeout: 10000,
  });
  await page
    .locator(".switch-choice")
    .nth(switchSolution(JSON.parse(round.puzzles[0])))
    .click();
  await expect(page.getByTestId("switch-own-score")).toHaveText("1");
  await expect
    .poll(
      async () =>
        Number(await page.getByTestId("switch-opponent-score").innerText()),
      { timeout: 10000 },
    )
    .toBeGreaterThan(0);
  await expect(page.locator(".result-notice")).toBeVisible({ timeout: 55000 });
  const match = await (
    await page.request.get(`/api/v1/matches/${selected.matchId}`)
  ).json();
  expect(match.phase).toBe("CHESS_PHASE");
  expect(match.latestBrainRoundResult.whiteCorrectCount).toBe(1);
  expect(match.latestBrainRoundResult.blackCorrectCount).toBeGreaterThan(10);
  expect(match.black.brainPoints).toBe(2);
});

test("Piece Switch runs locally, syncs scores, survives refresh and rematches on desktop/mobile", async ({
  page,
  browser,
}) => {
  const stamp = Date.now();
  const white = { playerId: `switch_w_${stamp}`, playerName: "Switch white" };
  const black = { playerId: `switch_b_${stamp}`, playerName: "Switch black" };
  const post = async (path: string, data: unknown) => {
    const response = await page.request.post(`/api/v1${path}`, { data });
    expect(response.ok(), await response.text()).toBe(true);
    return response.json();
  };
  const created = await post("/brain-matches", {
    ...white,
    mode: "PIECE_SWITCH",
  });
  const joined = await post("/brain-matches/join", {
    ...black,
    inviteCode: created.inviteCode,
  });
  const questions: SwitchQuestion[] = joined.puzzles.map((p: string) =>
    JSON.parse(p),
  );
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
  });
  const opponent = await context.newPage();
  async function seed(p: Page, guest: typeof white) {
    await p.addInitScript(
      ({ guest, id }) => {
        localStorage.setItem("cb-web-guest", JSON.stringify(guest));
        localStorage.setItem(
          "cb-web-active",
          JSON.stringify({ kind: "brain", id }),
        );
      },
      { guest, id: joined.matchId },
    );
    await p.goto("/");
    await expect(p.locator(".piece-switch")).toBeVisible();
  }
  try {
    await seed(page, white);
    await seed(opponent, black);
    await expect(page.locator(".switch-stimulus")).toBeVisible({
      timeout: 10000,
    });
    await expect(opponent.locator(".switch-stimulus")).toBeVisible();
    let idleRequests = 0;
    const countIdle = (request: import("@playwright/test").Request) => {
      if (request.url().includes("/piece-switch/events")) idleRequests++;
    };
    page.on("request", countIdle);
    await page.waitForTimeout(6000);
    page.off("request", countIdle);
    expect(idleRequests).toBeLessThanOrEqual(3);
    // Deliberately slow score requests: answering must still be instantaneous.
    await page.route("**/piece-switch/events", async (route) => {
      await new Promise((resolve) => setTimeout(resolve, 1200));
      await route.continue();
    });
    await page.keyboard.press(String(switchSolution(questions[0]) + 1));
    await expect(page.getByTestId("switch-own-score")).toHaveText("1", {
      timeout: 500,
    });
    await page.waitForTimeout(200);
    await page.keyboard.press(String(switchSolution(questions[1]) + 1));
    await expect(page.getByTestId("switch-own-score")).toHaveText("2", {
      timeout: 500,
    });
    await page.waitForTimeout(200);
    await page.keyboard.press(
      String(((switchSolution(questions[2]) + 1) % 3) + 1),
    );
    await expect(page.getByTestId("switch-own-score")).toHaveText("1");
    await page.waitForTimeout(650);
    await page.keyboard.press(String(switchSolution(questions[3]) + 1));
    await expect(page.getByTestId("switch-own-score")).toHaveText("2");
    await expect(opponent.getByTestId("switch-opponent-score")).toHaveText(
      "2",
      { timeout: 8000 },
    );
    await opponent
      .locator(".switch-choice")
      .nth(switchSolution(questions[0]))
      .click();
    await expect(opponent.getByTestId("switch-own-score")).toHaveText("1");
    for (const button of await opponent.locator(".switch-choice").all()) {
      const box = await button.boundingBox();
      expect(box!.height).toBeGreaterThanOrEqual(48);
      expect(box!.width).toBeGreaterThanOrEqual(48);
      expect(box!.y + box!.height).toBeLessThanOrEqual(844);
    }
    await opponent.screenshot({
      path: "test-results/piece-switch-mobile-playing.png",
      fullPage: true,
    });
    await page.screenshot({
      path: "test-results/piece-switch-desktop-playing.png",
      fullPage: true,
    });
    await opponent.setViewportSize({ width: 320, height: 667 });
    for (const button of await opponent.locator(".switch-choice").all()) {
      const box = await button.boundingBox();
      const navigation = await opponent.locator(".mobile-nav").boundingBox();
      expect(box!.height).toBeGreaterThanOrEqual(48);
      expect(box!.y + box!.height).toBeLessThanOrEqual(navigation!.y);
    }
    expect(
      await opponent.evaluate(
        () => document.documentElement.scrollWidth <= innerWidth,
      ),
    ).toBe(true);
    await opponent.screenshot({
      path: "test-results/piece-switch-compact-playing.png",
      fullPage: true,
    });
    await opponent.setViewportSize({ width: 390, height: 844 });
    await page.unrouteAll({ behavior: "wait" });
    await page.reload();
    await expect(page.getByTestId("switch-own-score")).toHaveText("2");
    await expect(page.locator(".result")).toBeVisible({ timeout: 55000 });
    await expect(page.locator(".final-score strong")).toHaveText("2 : 1");
    await expect(opponent.locator(".final-score strong")).toHaveText("2 : 1");
    await page.getByRole("button", { name: "Play again", exact: true }).click();
    await opponent
      .getByRole("button", { name: "Accept rematch", exact: true })
      .click();
    await expect(
      page.getByRole("heading", { name: "Piece Switch", exact: true }),
    ).toBeVisible();
    await expect(page.getByTestId("switch-own-score")).toHaveText("0");
    const active = await page.evaluate(() =>
      JSON.parse(localStorage.getItem("cb-web-active")!),
    );
    const rematch = await (
      await page.request.get(`/api/v1/brain-matches/${active.id}`)
    ).json();
    expect(rematch.puzzleType).toBe("PIECE_SWITCH");
    expect(rematch.mode).toBe("PIECE_SWITCH");
    expect(rematch.puzzles).not.toEqual(joined.puzzles);
    await opponent.screenshot({
      path: "test-results/piece-switch-mobile.png",
      fullPage: true,
    });
    await page.screenshot({
      path: "test-results/piece-switch-desktop.png",
      fullPage: true,
    });
  } finally {
    await context.close();
  }
});

test("compact phone keeps every Piece Switch answer above navigation", async ({
  page,
}) => {
  await page.setViewportSize({ width: 320, height: 667 });
  const guest = {
    playerId: `compact_${Date.now()}`,
    playerName: "Compact player",
  };
  const created = await (
    await page.request.post("/api/v1/brain-matches", {
      data: { ...guest, mode: "PIECE_SWITCH" },
    })
  ).json();
  await page.request.post("/api/v1/brain-matches/join", {
    data: {
      playerId: `${guest.playerId}_b`,
      playerName: "Opponent",
      inviteCode: created.inviteCode,
    },
  });
  await page.request.post(
    `/api/v1/brain-matches/${created.matchId}/piece-switch/ready`,
    {
      data: {
        playerId: `${guest.playerId}_b`,
        roundId: created.matchId,
        answers: [],
        finished: false,
      },
    },
  );
  await page.addInitScript(
    ({ guest, id }) => {
      localStorage.setItem("cb-web-guest", JSON.stringify(guest));
      localStorage.setItem(
        "cb-web-active",
        JSON.stringify({ kind: "brain", id }),
      );
    },
    { guest, id: created.matchId },
  );
  await page.goto("/");
  await expect(page.locator(".switch-stimulus")).toBeVisible({
    timeout: 10000,
  });
  const navigation = await page.locator(".mobile-nav").boundingBox();
  for (const button of await page.locator(".switch-choice").all()) {
    const box = await button.boundingBox();
    expect(box!.height).toBeGreaterThanOrEqual(48);
    expect(box!.y + box!.height).toBeLessThanOrEqual(navigation!.y);
  }
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth,
    ),
  ).toBe(true);
  await page.screenshot({
    path: "test-results/piece-switch-compact-playing.png",
    fullPage: true,
  });
});
