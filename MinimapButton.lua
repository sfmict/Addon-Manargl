local addon, ns = ...
local L = ns.L
local listFrame = AddonMgrAddonList


local addonToggle = function() listFrame:SetShown(not listFrame:IsShown()) end
local menu = LibStub("LibSFDropDown-1.5"):SetMixin({})
listFrame.minimapBtnMenu = menu
menu:ddSetDisplayMode(listFrame.isMainline and "menu" or "menuBackdrop")


menu:ddSetInitFunc(function(dd, level)
	local info = {}

	info.keepShownOnClick = true
	info.isTitle = true
	info.notCheckable = true
	info.text = L["Profiles"]
	dd:ddAddButton(info, level)

	local func = function(btn) listFrame:loadProfileAddons(btn.value, true) end

	local list = {}
	for i, profile in ipairs(listFrame.profiles) do
		list[i] = {
			notCheckable = true,
			text = ("%s |cff808080(%d %s)"):format(profile.name, profile.count, ADDONS),
			value = profile,
			func = func,
		}
	end

	info.list = list
	dd:ddAddButton(info, level)
end)


local function addOddLine(tooltip, text1, text2)
	tooltip:AddDoubleLine(text1, text2, .8,1,1,.8,1,1)
end


local function addEvenLine(tooltip, text1, text2)
	tooltip:AddDoubleLine(text1, text2, 1,1,1,1,1,1)
end


C_Timer.After(0, function()
	local ldb_icon = LibStub("LibDataBroker-1.1"):NewDataObject(addon, {
		type = "launcher",
		text = addon,
		icon = C_AddOns.GetAddOnMetadata(addon, "IconTexture"),
		OnClick = function(self, button)
			if button == "RightButton" then
				if #listFrame.profiles == 0 then return end
				menu:ddSetNoGlobalMouseEvent(true, self)
				menu:ddToggle(1, nil, self, "TOPRIGHT", "BOTTOMRIGHT")
			else
				menu:ddCloseMenus()
				addonToggle()
			end
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		end,
		OnTooltipShow = function(tooltip)
			local title = C_AddOns.GetAddOnMetadata(addon, "Title")
			local version  = C_AddOns.GetAddOnMetadata(addon, "Version")
			tooltip:SetText(("%s (|cffff7f3f%s|r)"):format(title, version))

			local totalMem = 0
			local maxAddons = 10
			local topAddons = {}
			UpdateAddOnMemoryUsage()

			for i = 1, C_AddOns.GetNumAddOns() do
				local mem = GetAddOnMemoryUsage(i)
				if mem > 0 then
					totalMem = totalMem + mem
					for j = 1, maxAddons do
						if not topAddons[j] or topAddons[j].mem < mem then
							for k = maxAddons, j + 1, -1 do
								topAddons[k] = topAddons[k - 1]
							end
							topAddons[j] = {index = i, mem = mem}
							break
						end
					end
				end
			end

			tooltip:AddLine(" ")

			local text = TOTAL_MEM_MB_ABBR:gsub("%%.+", ""):trim()
			tooltip:AddDoubleLine(text, listFrame:formatMemory(totalMem), 1,1,1,1,1,1)

			for i = 1, #topAddons do
				local name = C_AddOns.GetAddOnInfo(topAddons[i].index)
				local mem = listFrame:formatMemory(topAddons[i].mem)
				if i % 2 == 0 then addEvenLine(tooltip, name, mem)
				else addOddLine(tooltip, name, mem) end
			end

			tooltip:AddLine(" ")

			tooltip:AddLine(listFrame.LEFT_MOUSE_ICON..L["Left click to open the Addon Manargl"])
			if #listFrame.profiles ~= 0 then
				tooltip:AddLine(listFrame.RIGHT_MOUSE_ICON..L["Right click to open the Profile Menu"])
			end
		end,
	})
	local ldbi = LibStub("LibDBIcon-1.0")
	ldbi:Register(addon, ldb_icon, listFrame.db.omb)
	menu:ddHideWhenButtonHidden(ldbi:GetMinimapButton(addon))
end)


SLASH_ADDONMRGL1 = "/addonmrgl"
SLASH_ADDONMRGL2 = "/mrgl"
SLASH_ADDONMRGL3 = "/am"
SlashCmdList["ADDONMRGL"] = function(text)
	local load, name = (" "):split(text:lower(), 2)
	if load == "-lp" then
		listFrame:loadProfileByName(name, true, true)
	else
		addonToggle()
	end
end