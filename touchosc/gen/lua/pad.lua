-- Pad GROUP: reflect armed state from SC engine onto the arm button color.
-- API verified on GrosMac at fidelity gate.
-- self.children[1] is the arm BUTTON; color driven by /armed/<name>.
function onReceiveOSC(message, connections)
  local path = message[1]
  local name = self.name:gsub("pad_", "")
  if path == "/armed/" .. name then
    local args = message[2]
    local on = (args and args[1] and tonumber(args[1].value)) or 0
    if self.children and self.children[1] then
      self.children[1].color = on > 0.5
        and Color(0.27, 0.80, 0.40, 1)
        or  Color(0.11, 0.11, 0.11, 1)
    end
  end
end
