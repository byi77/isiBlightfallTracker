---@diagnostic disable: undefined-global, lowercase-global
-- Test script: runs outside WoW with standard Lua and stubs WoW globals.
-- Width check for the two-column window (labels left, values right) with
-- worst-case content in both locales. Width estimate: UTF-8 characters x font
-- size x 0.58 (Friz Quadrata averages about 0.55 em; 0.58 keeps a margin).
local ns = {}
GetLocale = function() return "deDE" end
assert(loadfile(arg[1] .. "/Locale.lua"))("x", ns)

local function chars(s) local _, n = s:gsub("[^\128-\191]", "") return n end
-- +2 px: the outline used above 50 % background transparency.
local function width(s, size) return chars(s) * size * 0.58 + 2 end

local FRAME_WIDTH, PAD, ICON, VALUE = 170, 6, 22, 44
local INNER = FRAME_WIDTH - 2 * PAD
local LABEL = INNER - VALUE

local SLOTS = {
  { "number", INNER - ICON - 5, 21, function() return { "~12.34M", "~888k", "-" } end },
  { "signal", INNER, 10, function(L)
      return { L.SIGNAL_IDLE, L.SIGNAL_NO_PLAGUES, L.SIGNAL_CHARGING, L.SIGNAL_NOW_DT_ENDING, L.SIGNAL_NOW_SOUL_REAPER,
        L.SIGNAL_NOW_DT_READY, L.SIGNAL_NOW_PLAGUES_EXPIRING, L.SIGNAL_STOPPED } end },
  { "label", LABEL, 9, function(L)
      return { L.ROW_ENEMIES, L.ROW_PER_TARGET, L.ESTIMATE_OFF, L.BAR_DT, L.BAR_VP, L.BAR_DP, L.ROW_SOUL_REAPER,
        L.ROW_SOUL_REAPER_BONUS, L.ROW_DT_CD, L.ROW_ERUPTS, L.ROW_REAL, L.ROW_PREDICTED } end },
  { "value", VALUE, 9, function(L)
      return { "~12.34M", "21", string.format(L.SECONDS_FMT, 124), string.format(L.SECONDS_FMT, 44),
        L.VALUE_READY, L.VALUE_LOCKED } end },
}

local fail = 0
for _, tag in ipairs({ "deDE", "enUS" }) do
  local L = ns.LOCALE_TABLES[tag]
  for _, slot in ipairs(SLOTS) do
    for _, s in ipairs(slot[4](L)) do
      local w = width(s, slot[3])
      local ok = w <= slot[2]
      if not ok then fail = fail + 1 end
      print(("%s %-5s %-7s %5.0f/%3d px  %s"):format(ok and "OK  " or "FAIL", tag, slot[1], w, slot[2], s))
    end
  end
end
-- Rows {top, height}.
local rows = { { -7, 24 }, { -38, 12 }, { -54, 10 }, { -66, 10 }, { -80, 10 }, { -91, 3 }, { -97, 10 }, { -108, 3 },
  { -114, 10 }, { -125, 3 }, { -133, 10 }, { -147, 1 }, { -153, 10 }, { -165, 10 }, { -177, 10 } }
for i = 2, #rows do
  if rows[i][1] > rows[i - 1][1] - rows[i - 1][2] then print("FAIL row overlap at row " .. i); fail = fail + 1 end
end
if rows[#rows][1] - rows[#rows][2] < -193 then print("FAIL last row outside frame"); fail = fail + 1 end
print(fail == 0 and "layout fits" or ("layout FAIL: " .. fail))
os.exit(fail == 0 and 0 or 1)
