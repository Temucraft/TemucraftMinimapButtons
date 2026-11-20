-- Options panel for Temucraft Minimap Buttons (Interface > AddOns).

local panel

local function Check(parent, name, label, tip, x, y, get, set)
	local cb = CreateFrame("CheckButton", name, parent, "InterfaceOptionsCheckButtonTemplate")
	cb:SetPoint("TOPLEFT", x, y)
	_G[name .. "Text"]:SetText(label)
	cb.tooltipText = tip
	cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
	cb.Refresh = function(self) self:SetChecked(get()) end
	return cb
end

local function Slider(parent, name, label, minV, maxV, step, x, y, get, set, fmt)
	local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
	s:SetPoint("TOPLEFT", x, y)
	s:SetWidth(200)
	s:SetMinMaxValues(minV, maxV)
	s:SetValueStep(step)
	_G[name .. "Low"]:SetText(fmt(minV))
	_G[name .. "High"]:SetText(fmt(maxV))
	s:SetScript("OnValueChanged", function(self, value)
		value = tonumber(value) or get()
		value = math.floor(value / step + 0.5) * step
		_G[name .. "Text"]:SetText(label .. ": " .. fmt(value))
		if not self.refreshing then set(value) end
	end)
	s.Refresh = function(self)
		self.refreshing = true
		self:SetValue(get())
		_G[name .. "Text"]:SetText(label .. ": " .. fmt(get()))
		self.refreshing = false
	end
	return s
end

local ROWS = 12
local ROW_H = 22

local function RefreshList()
	local api = TemucraftMinimapButtons
	local db = api.GetDB()
	local list = api.KnownButtons()
	local scroll = panel.scroll
	FauxScrollFrame_Update(scroll, #list, ROWS, ROW_H)
	local offset = FauxScrollFrame_GetOffset(scroll) or 0
	for i = 1, ROWS do
		local row = panel.rows[i]
		local name = list[i + offset]
		if name then
			row.buttonName = name
			row:SetChecked(not db.exclude[name])
			_G[row:GetName() .. "Text"]:SetText(api.ShortName(name) .. "  |cff808080" .. name .. "|r")
			row:Show()
		else
			row:Hide()
		end
	end
	if #list == 0 then panel.empty:Show() else panel.empty:Hide() end
end

local function RefreshAll()
	TemucraftMinimapButtons.Scan()
	for _, c in ipairs(panel.controls) do c:Refresh() end
	RefreshList()
end

function TemucraftMinimapButtons_CreateOptions()
	if panel then return end
	local api = TemucraftMinimapButtons
	local db = api.GetDB()
	panel = CreateFrame("Frame", "TemucraftMinimapButtonsOptions", UIParent)
	panel.name = "Temucraft Minimap Buttons"
	panel.controls = {}

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("Temucraft Minimap Buttons")
	local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	sub:SetText("Puts the addon buttons from around the minimap into one grid. /tmb opens it.")

	local c = panel.controls
	c[#c + 1] = Check(panel, "TMBOptHide", "Hide the minimap button (open with /tmb)", nil, 16, -60,
		function() return db.hideButton end, function(v) db.hideButton = v api.UpdateMainShown() end)
	c[#c + 1] = Check(panel, "TMBOptAuto", "Close the grid when the mouse leaves it", nil, 16, -86,
		function() return db.autoClose end, function(v) db.autoClose = v end)
	c[#c + 1] = Check(panel, "TMBOptClick", "Close the grid after clicking a button in it", nil, 16, -112,
		function() return db.closeOnClick end, function(v) db.closeOnClick = v end)
	c[#c + 1] = Slider(panel, "TMBOptColumns", "Columns", 1, 12, 1, 24, -160,
		function() return db.columns end, function(v) db.columns = v api.Layout() end,
		function(v) return tostring(math.floor(v + 0.5)) end)
	c[#c + 1] = Slider(panel, "TMBOptScale", "Scale", 0.5, 2, 0.05, 260, -160,
		function() return db.scale end, function(v) db.scale = v api.Layout() end,
		function(v) return ("%.2f"):format(v) end)

	local head = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	head:SetPoint("TOPLEFT", 16, -200)
	head:SetText("Buttons (ticked ones go in the grid, the others stay on the minimap)")

	local scroll = CreateFrame("ScrollFrame", "TMBOptScroll", panel, "FauxScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 16, -220)
	scroll:SetWidth(540)
	scroll:SetHeight(ROWS * ROW_H)
	scroll:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, RefreshList)
	end)
	panel.scroll = scroll
	panel.rows = {}
	for i = 1, ROWS do
		local row = CreateFrame("CheckButton", "TMBOptRow" .. i, panel, "InterfaceOptionsCheckButtonTemplate")
		row:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, -(i - 1) * ROW_H)
		row:SetScript("OnClick", function(self)
			if not self.buttonName then return end
			api.SetExcluded(self.buttonName, not self:GetChecked())
			RefreshList()
		end)
		panel.rows[i] = row
	end
	panel.empty = panel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	panel.empty:SetPoint("TOPLEFT", scroll, "TOPLEFT", 4, -4)
	panel.empty:SetText("No addon buttons found yet.")

	local rescan = CreateFrame("Button", "TMBOptRescan", panel, "UIPanelButtonTemplate")
	rescan:SetWidth(110) rescan:SetHeight(22)
	rescan:SetPoint("TOPLEFT", scroll, "BOTTOMLEFT", 0, -10)
	rescan:SetText("Look again")
	rescan:SetScript("OnClick", RefreshAll)
	local reset = CreateFrame("Button", "TMBOptReset", panel, "UIPanelButtonTemplate")
	reset:SetWidth(110) reset:SetHeight(22)
	reset:SetPoint("LEFT", rescan, "RIGHT", 8, 0)
	reset:SetText("Reset all")
	reset:SetScript("OnClick", function()
		api.Reset()
		db = api.GetDB()
		RefreshAll()
	end)

	panel:SetScript("OnShow", RefreshAll)
	InterfaceOptions_AddCategory(panel)
end

function TemucraftMinimapButtons_OpenOptions()
	if not panel then TemucraftMinimapButtons_CreateOptions() end
	-- called twice: the first call on 3.3.5 can open the panel on the wrong page
	InterfaceOptionsFrame_OpenToCategory(panel)
	InterfaceOptionsFrame_OpenToCategory(panel)
end
