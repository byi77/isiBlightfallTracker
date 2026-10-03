---@diagnostic disable: undefined-global, lowercase-global
-- Test script: runs outside WoW with standard Lua and stubs WoW globals.
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
    SetFont = function(self, path, size, flags)
      assert(type(path) == "string" and type(size) == "number", "SetFont args")
      self.size, self.flags = size, flags
    end,
    SetShadowColor = function(self, _, _, _, a) self.shadowAlpha = a end,
    SetWidth = function(self, w) self.width = w end,
    SetTextColor = function(self, r, g, b) assert(type(r) == "number" and type(g) == "number" and type(b) == "number", "color") self.color = { r, g, b } end,
    SetVertexColor = function(self, r, g, b) assert(type(r) == "number" and type(g) == "number" and type(b) == "number", "vertex color") self.color = { r, g, b } end,
    SetMinMaxValues = function(self, lo, hi) assert(type(lo) == "number" and type(hi) == "number" and hi >= lo, "minmax") self.min, self.max = lo, hi end,
    SetValue = function(self, v) assert(type(v) == "number", "SetValue number") self.value = v end,
    Show = function(self) self.shown = true end,
    Hide = function(self) self.shown = false end,
    IsShown = function(self) return self.shown end,
    SetShown = function(self, show) self.shown = show and true or false end,
    SetScale = function(self, s) assert(type(s) == "number", "SetScale number"); self.scale = s end,
    EnableMouse = function(self, on) self.mouseEnabled = on and true or false end,
    SetBackdropColor = function(self, r, g, b, a) self.bgAlpha = a or 1 end,
    SetBackdropBorderColor = function(self, r, g, b, a) self.borderAlpha = a or 1 end,
    SetScript = function(self, name, fn) self.scripts[name] = fn end,
    GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end,
    GetScale = function(self) return rawget(self, "scale") or 1 end,
    SetSize = function(self, width, height) self.w, self.h = width, height end,
    ClearAllPoints = function(self) self.point = nil end,
    SetPoint = function(self, point, rel, relPoint, x, y)
      if rel == UIParent then self.point = { point, relPoint, x or 0, y or 0 } end
    end,
    -- Edges in the frame's own (scaled) units, on a 1920 x 1080 UIParent.
    -- Only the anchors the addon uses on its main window are modelled.
    GetLeft = function(self)
      local p = rawget(self, "point")
      if not p then return nil end
      local s = rawget(self, "scale") or 1
      if p[1] == "TOPLEFT" and p[2] == "BOTTOMLEFT" then return p[3] end
      if p[1] == "CENTER" and p[2] == "CENTER" then return 960 / s + p[3] - (rawget(self, "w") or 0) / 2 end
    end,
    GetTop = function(self)
      local p = rawget(self, "point")
      if not p then return nil end
      local s = rawget(self, "scale") or 1
      if p[1] == "TOPLEFT" and p[2] == "BOTTOMLEFT" then return p[4] end
      if p[1] == "CENTER" and p[2] == "CENTER" then return 540 / s + p[4] + (rawget(self, "h") or 0) / 2 end
    end,
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
