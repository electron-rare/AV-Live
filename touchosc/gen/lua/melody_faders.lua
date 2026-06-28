-- Melody step faders: map 0..1 -> integer degree -7..14.
-- On value change: read all 8 step faders (m0..m7) -> /seq/melody/set.
-- API verified on GrosMac at fidelity gate.
local LO, HI = -7, 14

function onValueChanged(key)
  if key ~= "x" then return end
  local parent = self.parent
  local degs = {}
  for i = 1, 8 do
    local f = parent and parent:findByName("m" .. (i - 1), true)
    local fx = (f and f.values and f.values.x) or 0
    degs[i] = math.floor(LO + (HI - LO) * fx + 0.5)
  end
  sendOSC("/seq/melody/set", table.unpack(degs))
end
