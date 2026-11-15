export interface BrainDraft {
  index: number;
  answer: string;
  answers: Record<number, number>;
  submitted: boolean;
}
export function readBrainDraft(id: string, total: number): BrainDraft {
  const empty: BrainDraft = {
    index: 0,
    answer: "",
    answers: {},
    submitted: false,
  };
  try {
    const saved = JSON.parse(
      sessionStorage.getItem(`cb-brain:${id}`) || "null",
    );
    if (!saved) return empty;
    const answers: Record<number, number> = {};
    for (const [key, value] of Object.entries(saved.answers || {})) {
      const index = Number(key);
      if (
        Number.isInteger(index) &&
        index >= 0 &&
        index < total &&
        typeof value === "number" &&
        Number.isSafeInteger(value)
      )
        answers[index] = value;
    }
    return {
      index: Number.isInteger(saved.index)
        ? Math.min(total, Math.max(0, saved.index))
        : 0,
      answer: typeof saved.answer === "string" ? saved.answer : "",
      answers,
      submitted: saved.submitted === true,
    };
  } catch {
    return empty;
  }
}
export function saveBrainDraft(id: string, draft: BrainDraft) {
  try {
    sessionStorage.setItem(`cb-brain:${id}`, JSON.stringify(draft));
  } catch {
    /* Storage can be disabled; the current round still works in memory. */
  }
}
