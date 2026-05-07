// Hydra patch — coller dans https://hydra.ojack.xyz/
// Lance hydra-sc-bridge dans un terminal AVANT, et SC envoie OSC sur 8000
// Variables exposées par le bridge : a.fft[0..2] (low/mid/high) si SuperDirt-RMS-style

a.show()
a.setBins(3)
a.setSmooth(0.85)

osc(() => 10 + (a.fft[0] || 0) * 40, 0.1, () => (a.fft[1] || 0))
  .color(() => 1 - (a.fft[2] || 0), 0.5, 1)
  .rotate(() => time * 0.1)
  .modulate(noise(2, 0.3))
  .kaleid(5)
  .out()
