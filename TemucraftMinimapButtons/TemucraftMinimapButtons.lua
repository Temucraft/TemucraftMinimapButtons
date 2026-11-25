-- Temucraft Minimap Buttons
-- Gathers the addon buttons around the minimap into one grid that opens from a single minimap button.
-- Written for the 3.3.5 client. Our own code, MIT licence.

local ADDON = "TemucraftMinimapButtons"
local TITLE = "|cffffcc00Temucraft|r Minimap Buttons"

local DEFAULTS = {
	angle = 200,          -- position of our button around the minimap, in degrees
	columns = 6,
	scale = 1,
	spacing = 2,
	exclude = {},         -- [frameName] = true: left on the minimap
	hideButton = false,   -- hide our own minimap button (open with /tmb)
	closeOnClick = false, -- close the grid after a button in it is clicked
	autoClose = true,     -- close the grid a few seconds after the mouse leaves it
}

-- Blizzard frames that live on the minimap and must stay where they are.
local BLIZZARD = {
	MiniMapTracking = true, MiniMapTrackingButton = true, MiniMapTrackingFrame = true,
	MiniMapMailFrame = true, MinimapZoomIn = true, MinimapZoomOut = true,
	GameTimeFrame = true, TimeManagerClockButton = true, MiniMapWorldMapButton = true,
	MiniMapBattlefieldFrame = true, MiniMapLFGFrame = true, MiniMapVoiceChatFrame = true,
	MinimapZoneTextButton = true, MinimapToggleButton = true, MiniMapInstanceDifficulty = true,
	MiniMapMeetingStoneFrame = true, MiniMapRecordingButton = true, MinimapPing = true,
	MinimapBackdrop = true, MinimapBorder = true, MinimapBorderTop = true,
	MinimapNorthTag = true, MinimapCompassTexture = true, MiniMapPing = true,
}

-- Map pins and other things that sit on the minimap but are not addon buttons.
local PIN_PATTERNS = {
	"Pin", "Node", "Note", "Questie", "Waypoint", "Arrow", "Blip", "Ping", "POI", "Astrolabe",
	"TomTomMinimap", "MinimapIcon%d", "GatherMate", "Gatherer", "Routes", "HandyNotes",
}

local db
local collected = {}   -- [name] = { frame = btn, saved = {...} }
local seen = {}        -- [name] = frame, every candidate found (collected or excluded)
local order = {}       -- sorted list of collected names
local grid, main

local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage(TITLE .. ": " .. msg) end

local function CopyDefaults(src, dst)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			CopyDefaults(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
	return dst
end

local function ShortName(name)
	return (name:gsub("^LibDBIcon10_", ""):gsub("MinimapButton$", ""):gsub("_?Minimap_?Button", ""))
end

local function noop() end

------------------------------------------------------------------------
-- Deciding what is an addon button
------------------------------------------------------------------------
local function LooksLikePin(name)
	for _, p in ipairs(PIN_PATTERNS) do
		if name:find(p) then return true end
	end
	return false
end

local function IsCandidate(f)
	if type(f) ~= "table" or type(f.GetName) ~= "function" then return false end
	local name = f:GetName()
	if not name or BLIZZARD[name] then return false end
	if f == main or f == grid then return false end
	if name:find("^LibDBIcon10_") then
		return name ~= "LibDBIcon10_" .. ADDON
	end
	if f.IsObjectType and not (f:IsObjectType("Button") or f:IsObjectType("CheckButton")) then
		-- some old addons use a plain Frame with mouse scripts
		if not (f.GetScript and (f:GetScript("OnMouseUp") or f:GetScript("OnMouseDown"))) then return false end
	end
	if LooksLikePin(name) then return false end
	local w, h = f:GetWidth() or 0, f:GetHeight() or 0
	if w < 14 or h < 14 or w > 48 or h > 48 then return false end
	return true
end

-- Pins are made in pools with numbered names (SomethingPin1, SomethingPin2...). Drop names whose
-- non-number part shows up three or more times.
local function DropPools(list)
	local count = {}
	for _, f in ipairs(list) do
		local base = f:GetName():match("^(.-)%d+$")
		if base then count[base] = (count[base] or 0) + 1 end
	end
	local out = {}
	for _, f in ipairs(list) do
		local name = f:GetName()
		local base = name:match("^(.-)%d+$")
		if not base or count[base] < 3 or name:find("^LibDBIcon10_") then out[#out + 1] = f end
	end
	return out
end

local libIcons -- LibDBIcon buttons found in _G (walking all of _G is slow: only at login and on a rescan)
local function FindCandidates(full)
	local list, added = {}, {}
	local function add(f)
		if IsCandidate(f) then
			local name = f:GetName()
			if not added[name] then added[name] = true list[#list + 1] = f end
		end
	end
	for _, parent in ipairs({ Minimap, MinimapBackdrop }) do
		if parent and parent.GetChildren then
			for _, f in ipairs({ parent:GetChildren() }) do add(f) end
		end
	end
	-- LibDBIcon buttons, even if an addon parented them somewhere else
	if full or not libIcons then
		libIcons = {}
		for name, f in pairs(_G) do
			if type(name) == "string" and name:find("^LibDBIcon10_") and type(f) == "table" and f.GetParent then
				libIcons[#libIcons + 1] = f
			end
		end
	end
	for _, f in ipairs(libIcons) do
		local p = f:GetParent()
		if p == Minimap or p == MinimapBackdrop or p == MinimapCluster then add(f) end
	end
	return DropPools(list)
end

------------------------------------------------------------------------
-- Taking a button in and giving it back
------------------------------------------------------------------------
local function Capture(f)
	local name = f:GetName()
	local s = {
		parent = f:GetParent(), scale = f:GetScale(), strata = f:GetFrameStrata(),
		alpha = f:GetAlpha(), points = {},
		dragStart = f:GetScript("OnDragStart"), dragStop = f:GetScript("OnDragStop"),
		shown = f:IsShown(),
	}
	for i = 1, (f:GetNumPoints() or 0) do s.points[i] = { f:GetPoint(i) } end
	-- keep the real methods, so we can still move it after we block its own SetPoint
	local real = { SetPoint = f.SetPoint, ClearAllPoints = f.ClearAllPoints, SetParent = f.SetParent }
	collected[name] = { frame = f, saved = s, real = real }

	real.SetParent(f, grid.content)
	f:SetScale(1)
	f:SetFrameStrata("DIALOG")
	f:SetAlpha(1)
	f:SetScript("OnDragStart", nil)
	f:SetScript("OnDragStop", nil)
	-- the owner addon may try to move it back on the minimap: ignore that while it is with us
	f.SetPoint, f.ClearAllPoints, f.SetParent = noop, noop, noop
	if not f.tmbHooked then
		f.tmbHooked = true
		f:HookScript("OnShow", function() if collected[name] then TemucraftMinimapButtons_Layout() end end)
		f:HookScript("OnHide", function() if collected[name] then TemucraftMinimapButtons_Layout() end end)
		if f:IsObjectType("Button") then
			f:HookScript("OnClick", function()
				if collected[name] and db.closeOnClick and grid:IsShown() then grid:Hide() end
			end)
		end
	end
end

local function Release(name)
	local c = collected[name]
	if not c then return end
	local f, s = c.frame, c.saved
	collected[name] = nil
	f.SetPoint, f.ClearAllPoints, f.SetParent = nil, nil, nil
	f:SetParent(s.parent or Minimap)
	f:SetScale(s.scale or 1)
	f:SetFrameStrata(s.strata or "MEDIUM")
	f:SetAlpha(s.alpha or 1)
	f:SetScript("OnDragStart", s.dragStart)
	f:SetScript("OnDragStop", s.dragStop)
	f:ClearAllPoints()
	if #s.points > 0 then
		for _, p in ipairs(s.points) do f:SetPoint(unpack(p)) end
	else
		f:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
	end
end

------------------------------------------------------------------------
-- Grid
------------------------------------------------------------------------
local CELL = 33

function TemucraftMinimapButtons_Layout()
	if not grid then return end
	wipe(order)
	for name in pairs(collected) do order[#order + 1] = name end
	table.sort(order, function(a, b) return ShortName(a):lower() < ShortName(b):lower() end)
	local cols = math.max(1, math.floor(db.columns or 6))
	local step = CELL + (db.spacing or 2)
	local n = 0
	for _, name in ipairs(order) do
		local c = collected[name]
		local f = c.frame
		if f:IsShown() then
			local col, row = n % cols, math.floor(n / cols)
			c.real.ClearAllPoints(f)
			c.real.SetPoint(f, "CENTER", grid.content, "TOPLEFT", col * step + CELL / 2, -(row * step + CELL / 2))
			n = n + 1
		end
	end
	local usedCols = math.min(cols, math.max(n, 1))
	local rows = math.max(1, math.ceil(n / cols))
	grid.content:SetWidth(usedCols * step)
	grid.content:SetHeight(rows * step)
	grid:SetWidth(math.max(usedCols * step + 16, 120))
	grid:SetHeight(rows * step + 34)
	grid.title:SetText(n == 0 and "No buttons" or ("Buttons (" .. n .. ")"))
	grid:SetScale(db.scale or 1)
end

local function AnchorGrid()
	grid:ClearAllPoints()
	if not main:IsShown() then
		grid:SetPoint("TOPRIGHT", Minimap, "BOTTOMLEFT", 0, 0)
		return
	end
	local x, y = main:GetCenter()
	local ux, uy = UIParent:GetCenter()
	local ms, us = main:GetEffectiveScale(), UIParent:GetEffectiveScale()
	x, y = (x or 0) * ms, (y or 0) * ms
	ux, uy = (ux or 0) * us, (uy or 0) * us
	local v = (y > uy) and "TOP" or "BOTTOM"
	local h = (x > ux) and "RIGHT" or "LEFT"
	local ov = v == "TOP" and "BOTTOM" or "TOP"
	local oh = h == "RIGHT" and "LEFT" or "RIGHT"
	grid:SetPoint(v .. h, main, ov .. oh, 0, 0)
end

-- full: look through _G again for LibDBIcon buttons (login, rescan, options)
local function Scan(full)
	local combat = InCombatLockdown()
	for _, f in ipairs(FindCandidates(full)) do
		local name = f:GetName()
		seen[name] = f
		-- a protected button can't be re-parented in combat (ADDON_ACTION_BLOCKED): it's taken after combat
		if not db.exclude[name] and not collected[name] and not (combat and f.IsProtected and f:IsProtected()) then Capture(f) end
	end
	TemucraftMinimapButtons_Layout()
end

local function ShowGrid()
	Scan()
	AnchorGrid()
	grid.idle = 0
	grid:Show()
end

local function ToggleGrid()
	if grid:IsShown() then grid:Hide() else ShowGrid() end
end

local function CreateGrid()
	grid = CreateFrame("Frame", "TemucraftMinimapButtonsGrid", UIParent)
	grid:SetFrameStrata("DIALOG")
	grid:SetClampedToScreen(true)
	grid:EnableMouse(true)
	grid:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	grid:SetBackdropColor(0, 0, 0, 0.85)
	grid:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
	grid:Hide()
	grid.title = grid:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	grid.title:SetPoint("TOPLEFT", 9, -8)
	grid.content = CreateFrame("Frame", nil, grid)
	grid.content:SetPoint("TOPLEFT", 8, -24)
	grid.content:SetWidth(CELL)
	grid.content:SetHeight(CELL)
	tinsert(UISpecialFrames, "TemucraftMinimapButtonsGrid")
	-- close a while after the mouse leaves the grid and our button
	grid.idle = 0
	grid:SetScript("OnUpdate", function(self, elapsed)
		if not db.autoClose then return end
		if MouseIsOver(self) or (main:IsShown() and MouseIsOver(main)) then
			self.idle = 0
		else
			self.idle = self.idle + elapsed
			if self.idle > 3 then self:Hide() end
		end
	end)
end

------------------------------------------------------------------------
-- Our own minimap button
------------------------------------------------------------------------
local function PlaceMain()
	local a = math.rad(db.angle or 200)
	local r = (Minimap:GetWidth() or 140) / 2 + 10
	main:ClearAllPoints()
	main:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function DragUpdate()
	local mx, my = Minimap:GetCenter()
	local cx, cy = GetCursorPosition()
	local s = Minimap:GetEffectiveScale()
	cx, cy = cx / s, cy / s
	db.angle = math.deg(math.atan2(cy - my, cx - mx)) % 360
	PlaceMain()
end

local function CreateMain()
	main = CreateFrame("Button", "TemucraftMinimapButtonsButton", Minimap)
	main:SetWidth(31)
	main:SetHeight(31)
	main:SetFrameStrata("MEDIUM")
	main:SetFrameLevel(8)
	main:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	main:RegisterForDrag("LeftButton")
	main:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	local bg = main:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetWidth(20) bg:SetHeight(20)
	bg:SetPoint("TOPLEFT", 7, -5)
	local icon = main:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
	icon:SetWidth(20) icon:SetHeight(20)
	icon:SetPoint("TOPLEFT", 7, -5)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local border = main:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetWidth(53) border:SetHeight(53)
	border:SetPoint("TOPLEFT")
	main:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			TemucraftMinimapButtons_OpenOptions()
		else
			ToggleGrid()
		end
	end)
	main:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", DragUpdate) end)
	main:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	main:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("Minimap Buttons")
		GameTooltip:AddLine("Left-click: show or hide the buttons", 1, 1, 1)
		GameTooltip:AddLine("Right-click: options", 1, 1, 1)
		GameTooltip:AddLine("Drag: move this button", 1, 1, 1)
		GameTooltip:Show()
	end)
	main:SetScript("OnLeave", function() GameTooltip:Hide() end)
	PlaceMain()
end

local function UpdateMainShown()
	if db.hideButton then main:Hide() else main:Show() end
end

------------------------------------------------------------------------
-- Public helpers (used by the options panel)
------------------------------------------------------------------------
TemucraftMinimapButtons = {}
local API = TemucraftMinimapButtons

function API.GetDB() return db end
function API.Layout() TemucraftMinimapButtons_Layout() end
function API.Scan() Scan(true) end
function API.UpdateMainShown() UpdateMainShown() end
function API.ShortName(name) return ShortName(name) end
function API.IsCollected(name) return collected[name] ~= nil end

-- every button we know about, sorted, for the options list
function API.KnownButtons()
	local list = {}
	for name in pairs(seen) do list[#list + 1] = name end
	for name in pairs(db.exclude) do if not seen[name] then list[#list + 1] = name end end
	table.sort(list, function(a, b) return ShortName(a):lower() < ShortName(b):lower() end)
	return list
end

function API.SetExcluded(name, excluded)
	if excluded then
		db.exclude[name] = true
		Release(name)
	else
		db.exclude[name] = nil
		local f = seen[name] or _G[name]
		if f and not collected[name] and IsCandidate(f) then Capture(f) end
	end
	TemucraftMinimapButtons_Layout()
end

function API.Reset()
	for name in pairs(collected) do Release(name) end
	wipe(db)
	CopyDefaults(DEFAULTS, db)
	PlaceMain()
	UpdateMainShown()
	Scan()
end

------------------------------------------------------------------------
-- Slash command
------------------------------------------------------------------------
local function FindByName(arg)
	arg = arg:lower()
	for _, name in ipairs(API.KnownButtons()) do
		if name:lower() == arg or ShortName(name):lower() == arg then return name end
	end
end

SLASH_TEMUCRAFTMINIMAPBUTTONS1 = "/tmb"
SLASH_TEMUCRAFTMINIMAPBUTTONS2 = "/minimapbuttons"
SlashCmdList.TEMUCRAFTMINIMAPBUTTONS = function(msg)
	msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local cmd, rest = msg:match("^(%S*)%s*(.-)$")
	cmd = (cmd or ""):lower()
	if cmd == "" or cmd == "toggle" then
		ToggleGrid()
	elseif cmd == "options" or cmd == "config" then
		TemucraftMinimapButtons_OpenOptions()
	elseif cmd == "rescan" or cmd == "scan" then
		Scan(true)
		Print(#order .. " buttons collected.")
	elseif cmd == "columns" or cmd == "cols" then
		local n = tonumber(rest)
		if n and n >= 1 and n <= 20 then db.columns = math.floor(n) TemucraftMinimapButtons_Layout() end
		Print("columns: " .. db.columns)
	elseif cmd == "scale" then
		local n = tonumber(rest)
		if n and n >= 0.5 and n <= 2 then db.scale = n TemucraftMinimapButtons_Layout() end
		Print("scale: " .. db.scale)
	elseif cmd == "exclude" or cmd == "include" then
		local name = FindByName(rest)
		if not name then Print("no button called '" .. rest .. "'. Try /tmb list.") return end
		API.SetExcluded(name, cmd == "exclude")
		Print(ShortName(name) .. (cmd == "exclude" and " stays on the minimap." or " goes in the grid."))
	elseif cmd == "list" then
		Scan()
		for _, name in ipairs(API.KnownButtons()) do
			Print(("%s (%s)%s"):format(ShortName(name), name, db.exclude[name] and " |cffff8080excluded|r" or ""))
		end
	elseif cmd == "button" then
		db.hideButton = not db.hideButton
		UpdateMainShown()
		Print("minimap button " .. (db.hideButton and "hidden" or "shown") .. ".")
	elseif cmd == "reset" then
		API.Reset()
		Print("settings reset.")
	else
		Print("/tmb: show or hide the buttons")
		Print("/tmb options | rescan | list | columns <n> | scale <0.5-2>")
		Print("/tmb exclude <name> | include <name> | button (show or hide the minimap button) | reset")
	end
end

------------------------------------------------------------------------
-- Start up
------------------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
local pending = {}
loader:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON then
		TemucraftMinimapButtonsDB = CopyDefaults(DEFAULTS, TemucraftMinimapButtonsDB or {})
		db = TemucraftMinimapButtonsDB
	elseif event == "PLAYER_LOGIN" then
		db = db or CopyDefaults(DEFAULTS, TemucraftMinimapButtonsDB or {})
		CreateGrid()
		CreateMain()
		UpdateMainShown()
		if TemucraftMinimapButtons_CreateOptions then TemucraftMinimapButtons_CreateOptions() end
		Scan(true)
		-- addons that make their button late get picked up by later scans
		pending = { 2, 6, 15 }
		self.t = 0
		self:SetScript("OnUpdate", function(f, elapsed)
			f.t = f.t + elapsed
			if pending[1] and f.t >= pending[1] then
				table.remove(pending, 1)
				Scan(true)
			end
			if not pending[1] then f:SetScript("OnUpdate", nil) end
		end)
	end
end)
