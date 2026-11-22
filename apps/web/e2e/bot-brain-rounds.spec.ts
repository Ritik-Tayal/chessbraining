import { test, expect } from "@playwright/test";

for (const type of ["MENTAL_MATH", "DOT_CONNECT", "MEMORY"]) {
  test(`expert bot scores, wins BP and resumes chess in ${type}`, async ({
    page,
  }) => {
    test.setTimeout(210000);
    const guest = {
      playerId: `bot_brain_${type}_${Date.now()}`,
      playerName: "Brain challenger",
    };
    async function post(path: string, data: unknown) {
      const response = await page.request.post(`/api/v1${path}`, { data });
      expect(response.ok(), await response.text()).toBe(true);
      return response.json();
    }
    let selected: any;
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
      const round = await (
        await page.request.get(
          `/api/v1/matches/${match.matchId}/brain-rounds/current`,
        )
      ).json();
      if (round.puzzleType === type) {
        selected = match;
        break;
      }
      await post(`/matches/${match.matchId}/resign`, {
        playerId: guest.playerId,
      });
    }
    expect(selected, `Random chooser should produce ${type}`).toBeTruthy();
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
    await expect(page.locator(".brain-game")).toBeVisible();
    // The human deliberately waits: Memory must pass expired turns without human submissions.
    await expect
      .poll(
        async () => {
          const response = await page.request.get(
            `/api/v1/matches/${selected.matchId}/brain-rounds/current`,
          );
          if (response.ok()) return (await response.json()).blackCorrectCount;
          expect(response.status()).toBe(409);
          const match = await (
            await page.request.get(`/api/v1/matches/${selected.matchId}`)
          ).json();
          return match.latestBrainRoundResult?.blackCorrectCount ?? 0;
        },
        { timeout: type === "MEMORY" ? 100000 : 20000, intervals: [1000] },
      )
      .toBeGreaterThan(0);
    if (await page.locator(".round-scores").isVisible()) {
      await expect
        .poll(async () =>
          Number(
            await page
              .locator(".round-scores span")
              .nth(1)
              .locator("b")
              .innerText(),
          ),
        )
        .toBeGreaterThan(0);
    }
    await expect
      .poll(
        async () =>
          (
            await (
              await page.request.get(`/api/v1/matches/${selected.matchId}`)
            ).json()
          ).phase,
        { timeout: type === "MEMORY" ? 140000 : 40000, intervals: [1000] },
      )
      .toBe("CHESS_PHASE");
    await expect(page.locator(".result-notice")).toBeVisible({
      timeout: 10000,
    });
    const match = await (
      await page.request.get(`/api/v1/matches/${selected.matchId}`)
    ).json();
    expect(match.latestBrainRoundResult.blackCorrectCount).toBeGreaterThan(0);
    expect(match.latestBrainRoundResult.whiteCorrectCount).toBe(0);
    expect(match.black.brainPoints).toBe(2);
    expect(match.sideToMove).toBe("WHITE");
    await post(`/matches/${selected.matchId}/resign`, {
      playerId: guest.playerId,
    });
  });
}
