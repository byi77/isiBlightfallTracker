-- Richer widget stub: frames, textures, font strings, status bars and
-- animation groups. Unknown methods are no-ops; arguments are type-checked
-- where a wrong value would also fail in the client.
local frames = {}
FONTS = {}
BARS = {}
local function Widget(kind)
  local w = { kind = kind, shown = (kind ~= "Frame"), scripts = {} }
  local methods = {
    SetText = function(self, t)
      assert(t == nil or type(t) == "string" or type(t) == "number", "SetText expects string")
      self.text = t
    end,
    GetFont = function() return "Fonts/FRIZQT__.TTF", 12, "" end,
    SetFont = function(self, path, size) assert(type(path) == "string" and type(size) == "number", "SetFont args"); self.size = size end,
    SetWidth = function(self, w) self.width = w end,
    SetTextColor = function(self, r, g, b) assert(type(r) == "number" and type(g) == "number" and type(b) == "number", "color") self.color = { r, g, b } end,
    SetVertexColor = function(self, r, g, b) assert(type(r) == "number" and type(g) == "number" and type(b) == "number", "vertex color") self.color = { r, g, b } end,
    SetMinMaxValues = function(self, lo, hi) assert(type(lo) == "number" and type(hi) == "number" and hi >= lo, "minmax") self.min, self.max = lo, hi end,
    SetValue = function(self, v) assert(type(v) == "number", "SetValue number") self.value = v end,
    Show = function(self) self.shown = true end,
    Hide = function(self) self.shown = false end,
    IsShown = function(self) return self.shown end,
    SetScript = function(self, name, fn) self.scripts[name] = fn end,
    GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end,
    CreateFontString = function() local fs = Widget("FontString"); table.insert(FONTS, fs); return fs end,
    CreateTexture = function() return Widget("Texture") end,
    CreateAnimationGroup = function()
      local g = Widget("AnimationGroup")
      g.CreateAnimation = function() return Widget("Animation") end
      g.Play = function(self) self.playing = true end
      g.Stop = function(self) self.playing = false end
      return g
    end,
  }
  return setmetatable(w, { __index = function(_, k) return methods[k] or function() end end })
end
CreateFrame = function(kind)
  local f = Widget(kind or "Frame")
  if kind == "StatusBar" then table.insert(BARS, f) end
  table.insert(frames, f)
  return f
end
STUB_FRAMES = frames
UIParent = {}
