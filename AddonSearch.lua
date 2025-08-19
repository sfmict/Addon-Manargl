local addon, ns = ...
local L = ns.L
local listFrame = AddonMgrAddonList


listFrame:HookScript("OnShow", function(self)
	if not self.db.searchAddon then return end

	local function stop(guiltyAddon)
		for name, enabled in next, self.db.searchAddon.initialList do
			self:enableAddon(name, enabled, self.charGUID)
		end
		if guiltyAddon then self:enableAddon(guiltyAddon, false, self.charGUID) end
		self.db.searchAddon = nil
		ReloadUI()
	end

	StaticPopupDialogs[listFrame.addonName.."SEARCH_RESULT"] = {
		text = addon..": "..L["SEARCH_RESULT_QUESTION"],
		button1 = YES,
		button2 = NO,
		whileDead = 1,
		OnAccept = function(_, name) stop(name) end,
		OnCancel = function() stop() end,
	}

	local function continue(inList, popup)
		popup:Hide()
		local suspected, justified = self.db.searchAddon.enabled, self.db.searchAddon.disabled
		if inList then	suspected, justified = justified, suspected end

		for i, name in ipairs(justified) do
			tinsert(self.db.searchAddon.justified, name)
			for pName, list in next, self.db.searchAddon.childByPName do
				tDeleteItem(list, name)
				if #list == 0 then
					self.db.searchAddon.childByPName[pName] = nil
				end
			end
		end

		local function notDepSuspected(name)
			local deps = self.depsByName[name]
			if deps ~= nil then
				for i = 1, #deps do
					if tContains(suspected, deps[i]) then return false end
				end
			end
			return true
		end

		local hasParentByName = self.db.searchAddon.hasParentByName
		for name in next, hasParentByName do
			if notDepSuspected(name) then hasParentByName[name] = nil end
		end

		if #suspected > 1 then
			self:listSifting(suspected)
		else
			StaticPopup_Show(listFrame.addonName.."SEARCH_RESULT", NORMAL_FONT_COLOR:WrapTextInColorCode(suspected[1] or "Not Found!"), nil, suspected[1])
		end
	end

	StaticPopupDialogs[listFrame.addonName.."SEARCH_YES_NO_STOP"] = {
		text = addon..": "..L["SEARCH_PROGRESS_QUESTION"],
		button1 = YES,
		button2 = NO,
		button3 = CANCEL,
		whileDead = 1,
		selectCallbackByIndex = 1,
		OnButton1 = function(self) continue(true, self) end,
		OnButton2 = function(self) continue(false, self) end,
		OnButton3 = function() stop() end,
	}
	StaticPopup_Show(listFrame.addonName.."SEARCH_YES_NO_STOP", #self.db.searchAddon.enabled + #self.db.searchAddon.disabled, #self.db.searchAddon.justified)
end)


function listFrame:startSearch()
	StaticPopupDialogs[listFrame.addonName.."START_SEARCH"] = {
		text = addon..": "..L["Start seearching for the guilty addon?"],
		button1 = ACCEPT,
		button2 = CANCEL,
		hideOnEscape = 1,
		whileDead = 1,
		OnAccept = function(self, cb) cb() end,
	}
	StaticPopup_Show(self.addonName.."START_SEARCH", nil, nil, function()
		local initialList = {}
		local loadedList = {}
		local childByPName = {}
		local hasParentByName = {}

		local function checkDeps(dName, pName)
			if pName == addon or self.circular[pName] then return true end
			local deps = self.depsByName[pName]
			if deps ~= nil then
				for i, name in ipairs(deps) do
					if dName == name or checkDeps(dName, name) then
						return true
					end
				end
			end
			return false
		end

		for i = 1, #self.sorted do
			local name = self.sorted[i]
			local loadable, reason = C_AddOns.IsAddOnLoadable(name, self.charGUID)
			initialList[name] = reason ~= "DISABLED"
			if name ~= addon and (loadable or reason == "DEMAND_LOADED" or reason == "DEP_DEMAND_LOADED") then
				loadedList[#loadedList + 1] = name
				local deps = self.depsByName[name]
				if deps ~= nil then
					for j = 1, #deps do
						local dName = deps[j]
						if dName ~= addon then
							local addChild = true
							for n = 1, #deps do
								if n ~= j and checkDeps(dName, deps[n]) then
									addChild = false
									break
								end
							end
							if addChild then
								hasParentByName[name] = true
								local childs = childByPName[dName]
								if childs then childs[#childs + 1] = name
								else childByPName[dName] = {name} end
							end
						end
					end
				end
			end
		end

		self.db.searchAddon = {
			initialList = initialList,
			childByPName = childByPName,
			hasParentByName = hasParentByName,
			justified = {},
		}
		self:listSifting(loadedList)
	end)
end


function listFrame:listSifting(list)
	local childByPName = self.db.searchAddon.childByPName
	local hasParentByName = self.db.searchAddon.hasParentByName
	local actualList = {}
	local enabled = {}
	local disabled = {}
	self:setAddonsEnabled(false, self.charGUID)
	self:enableAddon(addon, true, self.charGUID)

	for i, name in ipairs(self.db.searchAddon.justified) do
		self:enableAddon(name, true, self.charGUID)
	end

	for i, name in ipairs(list) do
		if childByPName[name] then
			enabled[#enabled + 1] = name
			self:enableAddon(name, true, self.charGUID)
		elseif hasParentByName[name] then
			disabled[#disabled + 1] = name
		else
			actualList[#actualList + 1] = name
		end
	end

	local half = #actualList / 2

	for i, name in ipairs(actualList) do
		if i <= half then
			self:enableAddon(name, true, self.charGUID)
			enabled[#enabled + 1] = name
		else
			disabled[#disabled + 1] = name
		end
	end

	self.db.searchAddon.enabled = enabled
	self.db.searchAddon.disabled = disabled
	ReloadUI()
end