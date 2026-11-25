-- Plain Lua 5.1 test for TemucraftMinimapButtons with small stub frames.
local dir = arg[1]
local fails = 0
local function ok(cond, msg) if not cond then fails = fails + 1 print("FAIL " .. msg) else print("ok   " .. msg) end end

local Methods = {}
local MT = { __index = Methods }
local function NewFrame(otype, name, parent)
	local f = setmetatable({ otype = otype, name = name, children = {}, scripts = {}, points = {},
		w = 31, h = 31, shown = true, scale = 1, alpha = 1, strata = "MEDIUM" }, MT)
	if parent then f:SetParent(parent) end
	if name then _G[name] = f end
	return f
end
function Methods:GetName() return self.name end
function Methods:SetParent(p)
	if self.parent then for i, c in ipairs(self.parent.children) do if c == self then table.remove(self.parent.children, i) break end end end
	self.parent = p
	if p then table.insert(p.children, self) end
end
function Methods:GetParent() return self.parent end
function Methods:GetChildren() return unpack(self.children) end
function Methods:IsObjectType(t) return self.otype == t or (t == "Frame") end
function Methods:GetObjectType() return self.otype end
function Methods:SetPoint(...) table.insert(self.points, { ... }) end
function Methods:ClearAllPoints() self.points = {} end
function Methods:GetNumPoints() return #self.points end
function Methods:GetPoint(i) return unpack(self.points[i]) end
function Methods:SetWidth(w) self.w = w end
function Methods:SetHeight(h) self.h = h end
function Methods:GetWidth() return self.w end
function Methods:GetHeight() return self.h end
function Methods:Show() local was = self.shown self.shown = true if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end
function Methods:Hide() local was = self.shown self.shown = false if was and self.scripts.OnHide then self.scripts.OnHide(self) end end
function Methods:IsShown() return self.shown end
function Methods:IsVisible() return self.shown end
function Methods:SetScript(k, fn) self.scripts[k] = fn end
function Methods:GetScript(k) return self.scripts[k] end
function Methods:HookScript(k, fn) local old = self.scripts[k] self.scripts[k] = function(...) if old then old(...) end fn(...) end end
function Methods:SetScale(s) self.scale = s end
function Methods:GetScale() return self.scale end
function Methods:GetEffectiveScale() return self.scale end
function Methods:SetAlpha(a) self.alpha = a end
function Methods:GetAlpha() return self.alpha end
function Methods:SetFrameStrata(s) self.strata = s end
function Methods:GetFrameStrata() return self.strata end
function Methods:GetCenter() return self.cx or 500, self.cy or 500 end
function Methods:CreateTexture() return NewFrame("Texture") end
function Methods:CreateFontString() local fs = NewFrame("FontString") function fs:SetText(t) self.text = t end return fs end
for _, m in ipairs({ "SetTexture", "SetTexCoord", "SetClampedToScreen", "EnableMouse", "SetBackdrop", "SetBackdropColor",
	"SetBackdropBorderColor", "SetFrameLevel", "RegisterForClicks", "RegisterForDrag", "SetHighlightTexture", "RegisterEvent" }) do
	Methods[m] = function() end
end

UIParent = NewFrame("Frame", "UIParent")
UIParent.cx, UIParent.cy = 500, 400
MinimapCluster = NewFrame("Frame", "MinimapCluster", UIParent)
Minimap = NewFrame("Minimap", "Minimap", MinimapCluster)
Minimap.w, Minimap.h = 140, 140
Minimap.cx, Minimap.cy = 900, 700
MinimapBackdrop = NewFrame("Frame", "MinimapBackdrop", Minimap)
UISpecialFrames = {}
SlashCmdList = {}
local printed = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) printed[#printed + 1] = m end }
GameTooltip = setmetatable({}, { __index = function() return function() end end })
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
tinsert = table.insert
function MouseIsOver() return false end
function GetCursorPosition() return 900, 800 end
local opened = 0
function InterfaceOptions_AddCategory() end
function InterfaceOptionsFrame_OpenToCategory() opened = opened + 1 end
FauxScrollFrame_Update = function() end
FauxScrollFrame_GetOffset = function() return 0 end
local inCombat = false
function InCombatLockdown() return inCombat end

-- Blizzard frames that must stay
local blizz = {}
for _, n in ipairs({ "MiniMapTracking", "MiniMapMailFrame", "MinimapZoomIn", "MinimapZoomOut", "GameTimeFrame",
	"MiniMapWorldMapButton", "MiniMapBattlefieldFrame", "MiniMapLFGFrame", "MiniMapVoiceChatFrame" }) do
	blizz[n] = NewFrame("Button", n, Minimap)
end
-- addon buttons
local ldbA = NewFrame("Button", "LibDBIcon10_Questie", Minimap)
ldbA:SetPoint("CENTER", Minimap, "CENTER", 52, -52)
local ldbB = NewFrame("Button", "LibDBIcon10_Pawn", Minimap)
local plain = NewFrame("Button", "AtlasButton", MinimapBackdrop)
plain:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 3, -3)
local dragStart = function() end
plain:SetScript("OnDragStart", dragStart)
-- things that are not buttons
local big = NewFrame("Button", "SomeBigFrame", Minimap) big.w, big.h = 120, 120
local unnamed = NewFrame("Button", nil, Minimap)
for i = 1, 4 do NewFrame("Button", "SomeAddonDot" .. i, Minimap) end
NewFrame("Button", "GatherMatePin1", Minimap)
NewFrame("Frame", "PlainTexFrame", Minimap)

local all = {}
local oldNew = NewFrame
CreateFrame = function(t, name, parent, tmpl)
	local f = oldNew(t, name, parent) all[#all + 1] = f
	if name and tmpl then for _, sfx in ipairs({ "Text", "Low", "High" }) do _G[name .. sfx] = f:CreateFontString() end end
	f.SetMinMaxValues = function() end f.SetValueStep = function() end f.SetText = function() end
	f.SetValue = function(self, v) self.value = v end f.SetChecked = function(self, v) self.checked = v end
	f.GetChecked = function(self) return self.checked end
	return f
end
dofile(dir .. "/TemucraftMinimapButtons.lua")
dofile(dir .. "/Options.lua")
local function FireAll(event, ...)
	for _, f in ipairs(all) do if f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end end
end
TemucraftMinimapButtonsDB = { columns = 2, exclude = { LibDBIcon10_Pawn = true } }
FireAll("ADDON_LOADED", "TemucraftMinimapButtons")
FireAll("PLAYER_LOGIN")

local grid = TemucraftMinimapButtonsGrid
local db = TemucraftMinimapButtonsDB
ok(db.scale == 1 and db.columns == 2, "saved variables merged with defaults")
ok(TemucraftMinimapButtonsButton ~= nil and TemucraftMinimapButtonsButton.parent == Minimap, "own minimap button made")
ok(ldbA.parent == grid.content, "LibDBIcon button collected")
ok(plain.parent == grid.content, "plain addon button from MinimapBackdrop collected")
ok(ldbB.parent == Minimap, "excluded button left on the minimap")
for n, f in pairs(blizz) do ok(f.parent == Minimap, "Blizzard " .. n .. " left alone") end
ok(big.parent == Minimap, "large frame skipped")
ok(unnamed.parent == Minimap, "unnamed frame skipped")
ok(SomeAddonDot1.parent == Minimap, "numbered pool (pins) skipped")
ok(GatherMatePin1.parent == Minimap, "map pin skipped")
ok(PlainTexFrame.parent == Minimap, "frame without mouse scripts skipped")
ok(TemucraftMinimapButtonsButton.parent == Minimap, "own button not collected")
ok(plain:GetScript("OnDragStart") == nil, "drag turned off while in the grid")

-- the owner addon tries to move its button back: must be ignored
local before = #ldbA.points
ldbA:SetPoint("CENTER", Minimap, "CENTER", 10, 10)
ldbA:ClearAllPoints()
ok(#ldbA.points == before and ldbA.points[1][2] == grid.content, "owner SetPoint ignored while collected")

-- grid layout: 2 columns, 2 buttons -> one row
ok(grid.title.text == "Buttons (2)", "grid title counts buttons: " .. tostring(grid.title.text))
local p1 = AtlasButton.points[1]
local p2 = ldbA.points[1]
ok(p1[4] ~= p2[4] and p1[5] == p2[5], "two buttons side by side in one row")

-- hidden button leaves the grid
ldbA:Hide()
ok(grid.title.text == "Buttons (1)", "hidden button not laid out")
ldbA:Show()

-- slash commands
SlashCmdList.TEMUCRAFTMINIMAPBUTTONS("")
ok(grid:IsShown(), "/tmb opens the grid")
SlashCmdList.TEMUCRAFTMINIMAPBUTTONS("toggle")
ok(not grid:IsShown(), "/tmb toggle closes it")
SlashCmdList.TEMUCRAFTMINIMAPBUTTONS("columns 1")
ok(db.columns == 1, "/tmb columns 1")
ok(AtlasButton.points[1][4] == ldbA.points[1][4], "one column stacks buttons")
SlashCmdList.TEMUCRAFTMINIMAPBUTTONS("scale 1.5")
ok(db.scale == 1.5 and grid.scale == 1.5, "/tmb scale 1.5")
SlashCmdList.TEMUCRAFTMINIMAPBUTTONS("scale 9")
ok(db.scale == 1.5, "/tmb scale out of range ignored")
SlashCmdList.TEMUCRAFTMINIMAPBUTTONS("exclude atlasbutton")
ok(db.exclude.AtlasButton and AtlasButton.parent == MinimapBackdrop, "/tmb exclude gives the button back")
ok(AtlasButton.points[1][1] == "TOPLEFT" and AtlasButton.points[1][4] == 3, "original position restored")
ok(AtlasButton:GetScript("OnDragStart") == dragStart, "original drag script restored")
ok(rawget(AtlasButton, "SetPoint") == nil, "SetPoint block removed")
SlashCmdList.TEMUCRAFTMINIMAPBUTTONS("include AtlasButton")
ok(not db.exclude.AtlasButton and AtlasButton.parent == grid.content, "/tmb include takes it again")
SlashCmdList.TEMUCRAFTMINIMAPBUTTONS("include pawn")
ok(ldbB.parent == grid.content, "/tmb include by short name (LibDBIcon10_ removed)")
SlashCmdList.TEMUCRAFTMINIMAPBUTTONS("button")
ok(db.hideButton and not TemucraftMinimapButtonsButton:IsShown(), "/tmb button hides our button")
SlashCmdList.TEMUCRAFTMINIMAPBUTTONS("options")
ok(opened == 2, "/tmb options opens the panel")
SlashCmdList.TEMUCRAFTMINIMAPBUTTONS("list")
SlashCmdList.TEMUCRAFTMINIMAPBUTTONS("nonsense")
SlashCmdList.TEMUCRAFTMINIMAPBUTTONS("reset")
ok(db.columns == 6 and db.scale == 1 and not db.hideButton and TemucraftMinimapButtonsButton:IsShown(), "/tmb reset")
ok(ldbB.parent == grid.content and ldbA.parent == grid.content, "after reset all buttons collected again")

-- a button made late is found by the timed scans
local late = NewFrame("Button", "LibDBIcon10_Late", Minimap)
for _, f in ipairs(all) do if f.scripts.OnUpdate and f ~= grid then f.scripts.OnUpdate(f, 3) end end
ok(late.parent == grid.content, "late button picked up by a later scan")

-- options panel refresh runs
TemucraftMinimapButtonsOptions.scripts.OnShow(TemucraftMinimapButtonsOptions)
ok(TMBOptRow1.shown, "options list shows rows")
TMBOptRow1.GetChecked = function() return nil end
local first = TMBOptRow1.buttonName
TMBOptRow1.scripts.OnClick(TMBOptRow1)
ok(db.exclude[first], "unticking a row excludes " .. tostring(first))

-- dragging our button changes the angle
local mb = TemucraftMinimapButtonsButton
mb.scripts.OnDragStart(mb)
mb.scripts.OnUpdate(mb, 0.1)
ok(math.abs(db.angle - 90) < 0.01, "dragging sets the angle (" .. db.angle .. ")")

-- a protected button found in combat is left on the minimap until a scan out of combat
local secure = NewFrame("Button", "SecureThingButton", Minimap)
secure.IsProtected = function() return true end
secure:SetScript("OnClick", function() end)
inCombat = true
TemucraftMinimapButtons.Scan()
ok(secure.parent == Minimap, "protected button not taken in combat")
inCombat = false
TemucraftMinimapButtons.Scan()
ok(secure.parent ~= Minimap, "protected button taken after combat")

print(fails == 0 and "ALL PASSED" or (fails .. " FAILED"))
os.exit(fails == 0 and 0 or 1)
