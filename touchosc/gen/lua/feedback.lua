-- Global feedback receiver: beat flash + master RMS VU.
-- Attached to the beat BOX and master VU FADER on page 1.
-- API verified on GrosMac at fidelity gate.
function onReceiveOSC(message, connections)
  local p = message[1]
  local args = message[2]
  if p == "/sync/beat" then
    self.color = Color(1, 1, 1, 1)
  elseif p == "/sync/rms" then
    local amp = (args and args[1] and tonumber(args[1].value)) or 0
    self.values.x = amp
  end
end

function onFrame()
  local c = self.color
  if c and c.r then
    local decay = 0.85
    self.color = Color(c.r * decay, c.g * decay, c.b * decay, 1)
  end
end
