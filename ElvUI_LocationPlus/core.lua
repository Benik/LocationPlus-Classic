local E, L, V, P, G = unpack(ElvUI);
local LP = E:NewModule('LocationPlus', 'AceTimer-3.0', 'AceEvent-3.0');
local DT = E:GetModule('DataTexts');
local LSM = LibStub("LibSharedMedia-3.0");
local EP = LibStub("LibElvUIPlugin-1.0");
local addon, ns = ...

local format, tonumber, pairs, print = string.format, tonumber, pairs, print

local CreateFrame = CreateFrame
local ChatEdit_ChooseBoxForSend, ChatEdit_ActivateChat = ChatEdit_ChooseBoxForSend, ChatEdit_ActivateChat
local C_Map_GetBestMapForUnit = C_Map.GetBestMapForUnit
local C_Map_GetPlayerMapPosition = C_Map.GetPlayerMapPosition
local GetMinimapZoneText = GetMinimapZoneText
local GetRealZoneText, GetSubZoneText = GetRealZoneText, GetSubZoneText
local GetZonePVPInfo = GetZonePVPInfo
local IsInInstance, InCombatLockdown = IsInInstance, InCombatLockdown
local UIFrameFadeIn, UIFrameFadeOut, ToggleFrame = UIFrameFadeIn, UIFrameFadeOut, ToggleFrame
local IsControlKeyDown, IsShiftKeyDown = IsControlKeyDown, IsShiftKeyDown
local GameTooltip = _G['GameTooltip']

local UNKNOWN = UNKNOWN
local SANCTUARY_TERRITORY, ARENA, FRIENDLY, HOSTILE, CONTESTED_TERRITORY, COMBAT, AGGRO_WARNING_IN_INSTANCE = SANCTUARY_TERRITORY, ARENA, FRIENDLY, HOSTILE, CONTESTED_TERRITORY, COMBAT, AGGRO_WARNING_IN_INSTANCE

-- GLOBALS: LocationPlusPanel, LocPlusLeftDT, LocPlusRightDT, XCoordsPanel, YCoordsPanel, CUSTOM_CLASS_COLORS

LP.version = GetAddOnMetadata("ElvUI_LocationPlus", "Version")
LP.Config = {}

if E.db.locplus == nil then E.db.locplus = {} end

local classColor = E:ClassColor(E.myclass, true)

local COORDS_WIDTH = 30 -- Coord panels width
local SPACING = 1 		-- Panel spacing

-- mouse over the location panel
local function LocPanel_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM", 0, -4)
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint("BOTTOM", self, "BOTTOM", 0, 0)

	if InCombatLockdown() and E.db.locplus.ttcombathide then
		GameTooltip:Hide()
	else
		LP:UpdateTooltip()
	end

	if E.db.locplus.mouseover then
		UIFrameFadeIn(self, 0.2, self:GetAlpha(), 1)
	end
end

-- mouse leaving the location panel
local function LocPanel_OnLeave(self)
	GameTooltip:Hide()
	if E.db.locplus.mouseover then
		UIFrameFadeOut(self, 0.2, self:GetAlpha(), E.db.locplus.malpha)
	end
end

-- Hide in combat, after fade function ends
local function LocPanelOnFade()
	LocationPlusPanel:Hide()
end

-- Coords Creation
local function CreateCoords()
	local x, y = E.MapInfo.x, E.MapInfo.y

	local dig

	if E.db.locplus.dig then
		dig = 2
	else
		dig = 0
	end

	x = x and E:Round(100 * x, dig) or 0
	y = y and E:Round(100 * y, dig) or 0

	return x, y
end

-- clicking the location panel
local function LocPanel_OnClick(self, btn)
	local zoneText = GetRealZoneText() or UNKNOWN;
	if btn == "LeftButton" then
		if IsShiftKeyDown() then
			local edit_box = ChatEdit_ChooseBoxForSend()
			local x, y = CreateCoords()
			local message
			local coords = x..", "..y
				if zoneText ~= GetSubZoneText() then
					message = format("%s: %s (%s)", zoneText, GetSubZoneText(), coords)
				else
					message = format("%s (%s)", zoneText, coords)
				end
			ChatEdit_ActivateChat(edit_box)
			edit_box:Insert(message)
		else
			if IsControlKeyDown() then
				LocPlusLeftDT:SetScript("OnShow", function(self) E.db.locplus.dtshow = true; end)
				LocPlusLeftDT:SetScript("OnHide", function(self) E.db.locplus.dtshow = false; end)
				ToggleFrame(LocPlusLeftDT)
				ToggleFrame(LocPlusRightDT)
			else
				ToggleWorldMap()
			end
		end
	end
	if btn == "RightButton" then
		E:ToggleOptionsUI(); LibStub("AceConfigDialog-3.0-ElvUI"):SelectGroup("ElvUI", "locplus")
	end
end

-- Custom text color. Credits: Edoc
local color = { r = 1, g = 1, b = 1 }
local function unpackColor(color)
	return color.r, color.g, color.b
end

-- Location panel
local function CreateLocationPanel()
	local loc_panel = CreateFrame('Frame', 'LocationPlusPanel', E.UIParent)
	loc_panel:Width(E.db.locplus.lpwidth)
	loc_panel:Height(E.db.locplus.dtheight)
	loc_panel:Point('TOP', E.UIParent, 'TOP', 0, -E.mult -22)
	loc_panel:SetFrameStrata('LOW')
	loc_panel:SetFrameLevel(2)
	loc_panel:EnableMouse(true)
	loc_panel:SetScript('OnEnter', LocPanel_OnEnter)
	loc_panel:SetScript('OnLeave', LocPanel_OnLeave)
	loc_panel:SetScript('OnMouseUp', LocPanel_OnClick)

	-- Location Text
	loc_panel.Text = LocationPlusPanel:CreateFontString(nil, "LOW")
	loc_panel.Text:Point("CENTER", 0, 0)
	loc_panel.Text:SetAllPoints()
	loc_panel.Text:SetJustifyH("CENTER")
	loc_panel.Text:SetJustifyV("MIDDLE")

	-- Hide in combat/Pet battle
	loc_panel:SetScript("OnEvent",function(self, event)
		if E.db.locplus.combat then
			if event == "PLAYER_REGEN_DISABLED" then
				UIFrameFadeOut(self, 0.2, self:GetAlpha(), 0)
				self.fadeInfo.finishedFunc = LocPanelOnFade
			elseif event == "PLAYER_REGEN_ENABLED" then
				if E.db.locplus.mouseover then
					UIFrameFadeIn(self, 0.2, self:GetAlpha(), E.db.locplus.malpha)
				else
					UIFrameFadeIn(self, 0.2, self:GetAlpha(), 1)
				end
				self:Show()
			end
		end
	end)

	loc_panel:RegisterEvent("PLAYER_REGEN_DISABLED")
	loc_panel:RegisterEvent("PLAYER_REGEN_ENABLED")

	-- Mover
	E:CreateMover(LocationPlusPanel, "LocationMover", L["LocationPlus "])
end

local function HideDT()
	if E.db.locplus.dtshow then
		LocPlusRightDT:Show()
		LocPlusLeftDT:Show()
	else
		LocPlusRightDT:Hide()
		LocPlusLeftDT:Hide()
	end
end

-- Coord panels
local function CreateCoordPanels()

	-- X Coord panel
	local coordsX = CreateFrame('Frame', "XCoordsPanel", LocationPlusPanel)
	coordsX:Width(COORDS_WIDTH)
	coordsX:Height(E.db.locplus.dtheight)
	coordsX:SetFrameStrata('LOW')
	coordsX.Text = XCoordsPanel:CreateFontString(nil, "LOW")
	coordsX.Text:Point("CENTER", coordsX, "CENTER", 2, 0)
	coordsX.Text:SetJustifyH("CENTER")
	coordsX.Text:SetJustifyV("MIDDLE")

	-- Y Coord panel
	local coordsY = CreateFrame('Frame', "YCoordsPanel", LocationPlusPanel)
	coordsY:Width(COORDS_WIDTH)
	coordsY:Height(E.db.locplus.dtheight)
	coordsY:SetFrameStrata('LOW')
	coordsY.Text = YCoordsPanel:CreateFontString(nil, "LOW")
	coordsY.Text:Point("CENTER", coordsY, "CENTER", 2, 0)
	coordsY.Text:SetJustifyH("CENTER")
	coordsY.Text:SetJustifyV("MIDDLE")

	LP:CoordsColor()
end

-- mouse over option
function LP:MouseOver()
	if E.db.locplus.mouseover then
		LocationPlusPanel:SetAlpha(E.db.locplus.malpha)
	else
		LocationPlusPanel:SetAlpha(1)
	end
end

-- datatext panels width
function LP:DTWidth()
	local db = E.db.locplus
	LocPlusLeftDT:Width(db.dtwidth)
	LocPlusRightDT:Width(db.dtwidth)
end

-- all panels height
function LP:DTHeight()
	local db = E.db.locplus
	if db.ht then
		LocationPlusPanel:Height((db.dtheight)+6)
	else
		LocationPlusPanel:Height(db.dtheight)
	end

	LocPlusLeftDT:Height(db.dtheight)
	LocPlusRightDT:Height(db.dtheight)

	XCoordsPanel:Height(db.dtheight)
	YCoordsPanel:Height(db.dtheight)
end

-- Fonts
function LP:ChangeFont()
	local db = E.db.locplus
	E["media"].lpFont = LSM:Fetch("font", db.lpfont)

	local panelsToFont = {LocationPlusPanel, XCoordsPanel, YCoordsPanel}
	for _, frame in pairs(panelsToFont) do
		frame.Text:FontTemplate(E["media"].lpFont, db.lpfontsize, db.lpfontflags)
	end
end

-- Enable/Disable shadows
function LP:ShadowPanels()
	local db = E.db.locplus
	local panelsToAddShadow = {LocationPlusPanel, XCoordsPanel, YCoordsPanel, LocPlusLeftDT, LocPlusRightDT}

	for _, frame in pairs(panelsToAddShadow) do
		frame:CreateShadow()
		if db.shadow then
			frame.shadow:Show()
		else
			frame.shadow:Hide()
		end
	end

	if db.shadow then
		SPACING = 2
	else
		SPACING = 1
	end

	self:HideCoords()
end

-- Show/Hide coord frames
function LP:HideCoords()
	local db = E.db.locplus
	XCoordsPanel:Point('RIGHT', LocationPlusPanel, 'LEFT', -SPACING, 0)
	YCoordsPanel:Point('LEFT', LocationPlusPanel, 'RIGHT', SPACING, 0)

	LocPlusLeftDT:ClearAllPoints()
	LocPlusRightDT:ClearAllPoints()

	if (db.hidecoords) or (db.hidecoordsInInstance and IsInInstance()) then
		XCoordsPanel:Hide()
		YCoordsPanel:Hide()
		LocPlusLeftDT:Point('RIGHT', LocationPlusPanel, 'LEFT', -SPACING, 0)
		LocPlusRightDT:Point('LEFT', LocationPlusPanel, 'RIGHT', SPACING, 0)
	else
		XCoordsPanel:Show()
		YCoordsPanel:Show()
		LocPlusLeftDT:Point('RIGHT', XCoordsPanel, 'LEFT', -SPACING, 0)
		LocPlusRightDT:Point('LEFT', YCoordsPanel, 'RIGHT', SPACING, 0)
	end
end

-- Toggle transparency
function LP:TransparentPanels()
	local db = E.db.locplus
	local panelsToAddTrans = {LocationPlusPanel, XCoordsPanel, YCoordsPanel, LocPlusLeftDT, LocPlusRightDT}

	for _, frame in pairs(panelsToAddTrans) do
		frame:SetTemplate('NoBackdrop')
		if not db.noback then
			db.shadow = false
		elseif db.trans then
			frame:SetTemplate('Transparent')
		else
			frame:SetTemplate('Default', true)
		end
	end
end

function LP:StrataAndLevel()
	local db = E.db.locplus
	LocationPlusPanel:SetFrameStrata(db.frameStrata)
	LocationPlusPanel:SetFrameLevel(db.frameLevel)
end

function LP:UpdateLocation()
	local subZoneText = GetMinimapZoneText() or ""
	local zoneText = GetRealZoneText() or UNKNOWN;
	local displayLine

	-- zone and subzone
	if E.db.locplus.both then
		if (subZoneText ~= "") and (subZoneText ~= zoneText) then
			displayLine = zoneText .. ": " .. subZoneText
		else
			displayLine = subZoneText
		end
	else
		displayLine = subZoneText
	end

	if E.db.locplus.displayOther == 'PFISH' then
		local displayfish = LP:GetFishingLvl(true) or ""
		if displayfish ~= "" then
			displayLine = displayLine..displayfish
		end
	else
		displayLine = displayLine
	end

	LocationPlusPanel.Text:SetText(displayLine)

	-- Coloring
	if displayLine ~= "" then
		if E.db.locplus.customColor == 1 then
			LocationPlusPanel.Text:SetTextColor(LP:GetStatus(true))
		elseif E.db.locplus.customColor == 2 then
			LocationPlusPanel.Text:SetTextColor(classColor.r, classColor.g, classColor.b)
		else
			LocationPlusPanel.Text:SetTextColor(unpackColor(E.db.locplus.userColor))
		end
	end

	-- Sizing
	local fixedwidth = (E.db.locplus.lpwidth + 18)
	local autowidth = (LocationPlusPanel.Text:GetStringWidth() + 18)

	if E.db.locplus.lpauto then
		LocationPlusPanel:Width(autowidth)
		LocationPlusPanel.Text:Width(autowidth)
	else
		LocationPlusPanel:Width(fixedwidth)
		if E.db.locplus.trunc then
			LocationPlusPanel.Text:Width(fixedwidth - 18)
			LocationPlusPanel.Text:SetWordWrap(false)
		elseif autowidth > fixedwidth then
			LocationPlusPanel:Width(autowidth)
			LocationPlusPanel.Text:Width(autowidth)
		end
	end
end

function LP:UpdateCoords()
	local x, y = CreateCoords()
	local xt,yt

	if (x == 0 or x == nil) and (y == 0 or y == nil) then
		XCoordsPanel.Text:SetText("-")
		YCoordsPanel.Text:SetText("-")
	else
		if x < 10 then
			xt = "0"..x
		else
			xt = x
		end

		if y < 10 then
			yt = "0"..y
		else
			yt = y
		end
		XCoordsPanel.Text:SetText(xt)
		YCoordsPanel.Text:SetText(yt)
	end
end

-- Coord panels width
function LP:CoordsDigit()
	if E.db.locplus.dig then
		XCoordsPanel:Width(COORDS_WIDTH*1.5)
		YCoordsPanel:Width(COORDS_WIDTH*1.5)
	else
		XCoordsPanel:Width(COORDS_WIDTH)
		YCoordsPanel:Width(COORDS_WIDTH)
	end
end

function LP:CoordsColor()
	local db = E.db.locplus
	if db.customCoordsColor == 1 then
		XCoordsPanel.Text:SetTextColor(unpackColor(db.userColor))
		YCoordsPanel.Text:SetTextColor(unpackColor(db.userColor))
	elseif db.customCoordsColor == 2 then
		XCoordsPanel.Text:SetTextColor(classColor.r, classColor.g, classColor.b)
		YCoordsPanel.Text:SetTextColor(classColor.r, classColor.g, classColor.b)
	else
		XCoordsPanel.Text:SetTextColor(unpackColor(db.userCoordsColor))
		YCoordsPanel.Text:SetTextColor(unpackColor(db.userCoordsColor))
	end
end

-- Datatext panels
local function CreateDatatextPanels()
	local db = E.db.locplus
	-- Left coords Datatext panel
	local left_dtp = CreateFrame('Frame', 'LocPlusLeftDT', E.UIParent)
	left_dtp:Width(db.dtwidth)
	left_dtp:Height(db.dtheight)
	left_dtp:SetFrameStrata('LOW')
	left_dtp:SetParent(LocationPlusPanel)

	DT:RegisterPanel(LocPlusLeftDT, 1, 'ANCHOR_BOTTOM', 0, -4)
	DT:UpdatePanelInfo('LocPlusLeftDT')

	-- Right coords Datatext panel
	local right_dtp = CreateFrame('Frame', 'LocPlusRightDT', E.UIParent)
	right_dtp:Width(db.dtwidth)
	right_dtp:Height(db.dtheight)
	right_dtp:SetFrameStrata('LOW')
	right_dtp:SetParent(LocationPlusPanel)

	DT:RegisterPanel(LocPlusRightDT, 1, 'ANCHOR_BOTTOM', 0, -4)
	DT:UpdatePanelInfo('LocPlusRightDT')
end

-- Update changes
function LP:Update()
	LP:TransparentPanels()
	LP:ShadowPanels()
	LP:DTHeight()
	LP:StrataAndLevel()
	HideDT()
	LP:CoordsDigit()
	LP:MouseOver()
	LP:HideCoords()
end

function LP:ToggleBlizZoneText()
	if E.db.locplus.zonetext then
		ZoneTextFrame:UnregisterAllEvents()
	else
		ZoneTextFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
		ZoneTextFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
		ZoneTextFrame:RegisterEvent("ZONE_CHANGED")
	end
end

function LP:TimerUpdate()
	self:ScheduleRepeatingTimer('UpdateCoords', E.db.locplus.timer)
end

function LP:AddOptions()
	for _, func in pairs(LP.Config) do
		func()
	end
end

local function InjectDatatextOptions()
	E.Options.args.datatexts.args.panels.args.LocPlusLeftDT.name = L['LocationPlus Left Panel']
	E.Options.args.datatexts.args.panels.args.LocPlusLeftDT.order = 1101

	E.Options.args.datatexts.args.panels.args.LocPlusRightDT.name = L['LocationPlus Right Panel']
	E.Options.args.datatexts.args.panels.args.LocPlusRightDT.order = 1102
end

function LP:PLAYER_ENTERING_WORLD(...)
	self:ChangeFont()
	self:UpdateCoords()
	self:HideCoords()
	DT:UpdatePanelInfo('LocPlusRightDT')
	DT:UpdatePanelInfo('LocPlusLeftDT')
end

function LP:Initialize()
	CreateLocationPanel()
	CreateDatatextPanels()
	CreateCoordPanels()
	self:Update()
	self:TimerUpdate()
	self:ToggleBlizZoneText()
	self:ScheduleRepeatingTimer('UpdateLocation', 0.5)
	self:RegisterEvent('PLAYER_ENTERING_WORLD')
	hooksecurefunc(DT, 'UpdatePanelInfo', LP.Update)
	hooksecurefunc(DT, 'UpdatePanelAttributes', LP.Update)

	EP:RegisterPlugin(addon, LP.AddOptions)
	tinsert(LP.Config, InjectDatatextOptions)

	if E.db.locplus.LoginMsg then
		print(L["Location Plus Classic "]..format("v|cff33ffff%s|r",LP.version)..L[" is loaded. Thank you for using it."])
	end
end

local function InitializeCallback()
	LP:Initialize()
end

E:RegisterModule(LP:GetName(), InitializeCallback)