-- Pad GROUP: reflect armed state from SC engine onto the arm button color.
-- API verified on GrosMac at fidelity gate.
-- self.children[1] is the arm BUTTON; color driven by /armed/<name>.
-- State int: 0=off, 1=playing (solid green), 2=queued-launch (blink), 3=queued-stop (blink).
local blinking = false

function onReceiveOSC(message, connections)
  local path = message[1]
  local name = self.name:gsub("pad_", "")
  if path == "/armed/" .. name then
    local args = message[2]
    local state = math.floor((args and args[1] and tonumber(args[1].value)) or 0)
    if self.children and self.children[1] then
      if state == 0 then
        blinking = false
        self.children[1].color = Color(0.11, 0.11, 0.11, 1)
      elseif state == 1 then
        blinking = false
        self.children[1].color = Color(0.27, 0.80, 0.40, 1)
      else
        -- state 2 (queued-launch) or 3 (queued-stop): blink amber
        blinking = true
      end
    end
  end
end

function onFrame()
  if blinking and self.children and self.children[1] then
    local phase = (math.sin(getTime() * math.pi * 2.5) + 1) * 0.5
    self.children[1].color = Color(0.80 * phase, 0.60 * phase, 0.10, 1)
  end
end
