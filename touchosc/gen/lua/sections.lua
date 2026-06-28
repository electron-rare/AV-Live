-- SECTIONS GROUP: color the 8 launch slot buttons from /scene/state.
-- API verified on GrosMac at fidelity gate.
-- /scene/state <cur:int> <fill0:int> ... <fill7:int>
-- cur=-1 means no active section; fillN=1 means slot N is saved.
function onReceiveOSC(message, connections)
  local path = message[1]
  if path ~= "/scene/state" then return end
  local args = message[2]
  local cur = math.floor((args[1] and tonumber(args[1].value)) or -1)
  for i = 0, 7 do
    local fill = math.floor((args[i + 2] and tonumber(args[i + 2].value)) or 0)
    local slot = self:findByName("slot" .. i, true)
    if slot then
      if i == cur then
        slot.color = Color(0.27, 0.8, 0.4, 1)        -- current (green)
      elseif fill == 1 then
        slot.color = Color(0.2, 0.4, 0.8, 1)          -- filled (blue)
      else
        slot.color = Color(0.15, 0.15, 0.15, 1)       -- empty (dark)
      end
    end
  end
end
