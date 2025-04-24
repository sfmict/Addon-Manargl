local addon = ...
local listFrame = AddonMgrAddonList


local addonToggle = function() listFrame:SetShown(not listFrame:IsShown()) end


C_Timer.After(0, function()
	local ldb_icon = LibStub("LibDataBroker-1.1"):NewDataObject(addon, {
		type = "launcher",
		text = addon,
		icon = C_AddOns.GetAddOnMetadata(addon, "IconTexture"),
		OnClick = addonToggle,
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
				tooltip:AddDoubleLine(name, listFrame:formatMemory(topAddons[i].mem), 1,1,1,1,1,1)
			end
		end,
	})
	LibStub("LibDBIcon-1.0"):Register(addon, ldb_icon, listFrame.db.omb)
end)


SLASH_ADDONMRGL1 = "/addonmrgl"
SlashCmdList["ADDONMRGL"] = addonToggle