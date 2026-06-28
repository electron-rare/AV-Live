// Matrix audio-reactive glow — pure decay math (Approach A, trigger envelope).
// Imported directly by node:test; surfaced to the classic control.js via a
// one-line module shim in index.html (window.MatrixGlow).
export const GLOW_DECAY = 0.86; // per-60fps-frame multiplier (~200 ms visible tail)
export const GLOW_MIN = 0.02;   // floor: at/below this, the glow is treated as 0

// Exponential decay of `level` over dtMs milliseconds, normalized to 60 fps.
export function nextGlow(level, dtMs) {
  if (level <= GLOW_MIN) return 0;
  const decayed = level * Math.pow(GLOW_DECAY, dtMs / (1000 / 60));
  return decayed <= GLOW_MIN ? 0 : decayed;
}
