-- Run the retained helper scenarios against their new standalone owner.
local dir = arg[1]
local Assert = assert(loadfile(dir .. "/tests/dk_assert.lua"))()
if not rawget(_G, "UnitExists") then UnitExists = function() return true end end
local function WithGlobals(stubs, fn)
  local old = {}
  for key, value in pairs(stubs) do old[key] = rawget(_G, key); _G[key] = value end
  local ok, message = pcall(fn)
  for key in pairs(stubs) do _G[key] = old[key] end
  if not ok then error(message, 0) end
end
local function LoadModules()
  local ns = {}
  isiBlightfallTrackerDB = rawget(_G, "IsiLiveDB") or {}
  for _, file in ipairs({
    "Locale.lua", "Log.lua", "Settings.lua", "Model.lua",
    "DkSupport.lua", "ActionButtonOverlay.lua", "DkAssist.lua",
  }) do assert(loadfile(dir .. "/" .. file))("isiBlightfallTracker", ns) end
  return ns
end
local passed, failed = 0, 0
local function test(name, fn)
  local ok, message = pcall(fn)
  if ok then passed = passed + 1 else failed = failed + 1 end
  io.write((ok and "PASS " or "FAIL ") .. name .. "\n")
  if not ok then io.write(tostring(message) .. "\n") end
end
assert(loadfile(dir .. "/tests/dk_assist_scenarios.lua"))()(test, {
  assert = Assert, with_globals = WithGlobals, load_modules = LoadModules,
})
io.write(string.format("DK helpers: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
