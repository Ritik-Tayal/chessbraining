let context: AudioContext | undefined;
let enabled = localStorage.getItem("cb-sound") !== "off";
export function toggleSound() {
  enabled = !enabled;
  localStorage.setItem("cb-sound", enabled ? "on" : "off");
  unlockSound();
  return enabled;
}
export function soundEnabled() {
  return enabled;
}
export function unlockSound() {
  if (!enabled) return;
  context ??= new AudioContext();
  void context.resume();
}
export function playSound(
  kind: "move" | "start" | "end" | "power" | "answer" | "flip" = "move",
) {
  if (!enabled || !context || context.state !== "running") return;
  const notes =
    kind === "answer"
      ? [660]
      : kind === "flip"
        ? [440]
        : kind === "move"
          ? [330, 220]
          : kind === "end"
            ? [523, 659, 784, 1046]
            : kind === "power"
              ? [330, 660, 990]
              : [392, 523, 659];
  notes.forEach((frequency, i) => {
    const oscillator = context!.createOscillator();
    const gain = context!.createGain();
    oscillator.type = kind === "move" ? "triangle" : "sine";
    oscillator.frequency.value = frequency;
    const t = context!.currentTime + i * 0.085;
    gain.gain.setValueAtTime(0.0001, t);
    gain.gain.exponentialRampToValueAtTime(0.11, t + 0.008);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.14);
    oscillator.connect(gain).connect(context!.destination);
    oscillator.start(t);
    oscillator.stop(t + 0.15);
  });
}
