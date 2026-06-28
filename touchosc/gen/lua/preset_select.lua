-- Seq page GROUP: update rhythm name labels and melody fader values from SC state.
-- /seq/rhythm/state <idx> <k> <s> <h> <name>  -> updates rhythm label R(idx+1)
-- /seq/melody/state <idx> <d0..dN>             -> loads degree values into m0..m7
-- API verified on GrosMac at fidelity gate.
local LO, HI = -7, 14

function onReceiveOSC(message, connections)
  local p = message[1]
  local args = message[2]
  if not args then return end

  if p == "/seq/rhythm/state" then
    local idx = tonumber(args[1] and args[1].value) or 0
    local name = (args[#args] and args[#args].value) or ""
    local lbl = self:findByName("R" .. (idx + 1), true)
    if lbl then lbl.values.text = name end

  elseif p == "/seq/melody/state" then
    local idx = tonumber(args[1] and args[1].value) or 0
    -- remaining args are degrees d0..dN
    local range = HI - LO
    for i = 1, 8 do
      local a = args[i + 1]
      if a then
        local deg = tonumber(a.value) or 0
        local f = self:findByName("m" .. (i - 1), true)
        if f then
          f.values.x = (deg - LO) / range
        end
      end
    end
  end
end
