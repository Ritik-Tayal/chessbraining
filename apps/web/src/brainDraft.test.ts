import { afterEach, expect, it, vi } from "vitest";
import { readBrainDraft, saveBrainDraft } from "./brainDraft";
afterEach(() => vi.unstubAllGlobals());
it("restores answered questions, the current answer and submission state", () => {
  const values = new Map<string, string>();
  vi.stubGlobal("sessionStorage", {
    getItem: (key: string) => values.get(key) || null,
    setItem: (key: string, value: string) => values.set(key, value),
  });
  const draft = {
    index: 3,
    answer: "12",
    answers: { 0: 2, 1: 4, 2: 6 },
    submitted: false,
  };
  saveBrainDraft("round-one", draft);
  expect(readBrainDraft("round-one", 30)).toEqual(draft);
  expect(readBrainDraft("another-round", 30).answers).toEqual({});
});
it("ignores malformed or unavailable browser storage", () => {
  vi.stubGlobal("sessionStorage", { getItem: () => "{broken" });
  expect(readBrainDraft("round", 30).index).toBe(0);
  vi.stubGlobal("sessionStorage", {
    getItem: () => {
      throw Error("disabled");
    },
    setItem: () => {
      throw Error("disabled");
    },
  });
  expect(() =>
    saveBrainDraft("round", {
      index: 0,
      answer: "",
      answers: {},
      submitted: false,
    }),
  ).not.toThrow();
  expect(readBrainDraft("round", 30).answers).toEqual({});
});
