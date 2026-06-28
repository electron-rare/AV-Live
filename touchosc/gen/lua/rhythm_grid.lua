-- Rhythm grid: rows 0..2 = K, S, H; cols 0..15 = steps.
-- On any cell change: build three 16-char "0"/"1" strings -> /seq/rhythm/set.
-- On /seq/rhythm/state <idx> <k> <s> <h> <name>: load strings into cells.
-- API verified on GrosMac at fidelity gate.
function onValueChanged(key)
  local rows = {"", "", ""}
  for r = 0, 2 do
    for c = 0, 15 do
      local cell = self.children[r * 16 + c + 1]
      local v = (cell and cell.values and cell.values.x) or 0
      rows[r + 1] = rows[r + 1] .. (v > 0.5 and "1" or "0")
    end
  end
  sendOSC("/seq/rhythm/set", rows[1], rows[2], rows[3])
end

function onReceiveOSC(message, connections)
  if message[1] ~= "/seq/rhythm/state" then return end
  local args = message[2]
  -- args: [idx, k_str, s_str, h_str, name]
  for r = 0, 2 do
    local str = args and args[r + 2] and args[r + 2].value or ""
    for c = 0, 15 do
      local cell = self.children[r * 16 + c + 1]
      if cell then
        local ch = str:sub(c + 1, c + 1)
        cell.values.x = (ch == "1") and 1 or 0
      end
    end
  end
end
