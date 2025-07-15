local addon, ns = ...
local L = ns.L
local listFrame = AddonMgrAddonList
local lastProfileName, profilePopupAction
listFrame.addonName = ("%s_ADDON_"):format(addon:upper())


--POPUPS
StaticPopupDialogs[listFrame.addonName.."NEW_PROFILE"] = {
	text = addon..": "..L["Create profile"],
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = 1,
	maxLetters = 48,
	editBoxWidth = 350,
	hideOnEscape = 1,
	whileDead = 1,
	OnAccept = function(self, cb) cb(self) end,
	EditBoxOnEnterPressed = function(self)
		StaticPopup_OnClick(self:GetParent(), 1)
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide()
	end,
}
local function profileExistsAccept(popup, data)
	if not popup then return end
	popup:Hide()
	profilePopupAction(listFrame, data)
	profilePopupAction = nil
	lastProfileName = nil
end
StaticPopupDialogs[listFrame.addonName.."PROFILE_EXISTS"] = {
	text = addon..": "..L["A profile with the same name exists."],
	button1 = OKAY,
	hideOnEscape = 1,
	whileDead = 1,
	enterClicksFirstButton = 1,
	OnAccept = profileExistsAccept,
	OnCancel = profileExistsAccept,
}
StaticPopupDialogs[listFrame.addonName.."EDIT_PROFILE"] = {
	text = addon..": "..EDIT,
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = 1,
	maxLetters = 48,
	editBoxWidth = 350,
	hideOnEscape = 1,
	whileDead = 1,
	OnAccept = function(self, cb) cb(self) end,
	EditBoxOnEnterPressed = function(self)
		StaticPopup_OnClick(self:GetParent(), 1)
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide()
	end,
}
StaticPopupDialogs[listFrame.addonName.."DELETE_PROFILE"] = {
	text = addon..": "..L["Are you sure you want to delete %s profile?"],
	button1 = DELETE,
	button2 = CANCEL,
	hideOnEscape = 1,
	whileDead = 1,
	OnAccept = function(_, cb) cb() end,
}
StaticPopupDialogs[listFrame.addonName.."YOU_WANT"] = {
	text = addon..": "..L["Are you sure you want to %s?"],
	button1 = OKAY,
	button2 = CANCEL,
	hideOnEscape = 1,
	whileDead = 1,
	OnAccept = function(_, cb) cb() end,
}
StaticPopupDialogs[listFrame.addonName.."CUSTOM_OK_CANCEL"] = {
	text = addon..": %s",
	button1 = OKAY,
	button2 = CANCEL,
	hideOnEscape = 1,
	whileDead = 1,
	enterClicksFirstButton = 1,
	OnAccept = function(_, cb) cb() end,
}


-- SAVE CHAR PROFILES
function listFrame:PLAYER_LOGOUT()
	local charName = self.charName.." - "..GetRealmName()
	local curCharProfile
	for i = 1, #self.charProfiles do
		if self.charProfiles[i].name == charName then
			curCharProfile = self.charProfiles[i]
			break
		end
	end
	if not curCharProfile then
		curCharProfile = {name = charName, addons = {}}
		self.charProfiles[#self.charProfiles + 1] = curCharProfile
		sort(self.charProfiles, function(a, b) return a.name < b.name end)
	end
	curCharProfile.class = select(2, UnitClass("player"))
	self:saveProfileAddons(curCharProfile)

	if AddonMgrAutoLoadChar and not next(AddonMgrAutoLoadChar) then
		AddonMgrAutoLoadChar = nil
	end
end
listFrame:RegisterEvent("PLAYER_LOGOUT")


-- AUTOLOAD PROFILES
local function requireLoadProfile(profile, context)
	context = context or {}
	if context[profile] then return end
	context[profile] = true
	for addonName in next, profile.addons do
		local loadable, reason = C_AddOns.IsAddOnLoadable(addonName, listFrame.charName)
		if reason == "DISABLED" then return true end
	end
	if profile.loadProfiles then
		for name in next, profile.loadProfiles do
			local lProfile = listFrame:getProfileByName(name)
			if lProfile and requireLoadProfile(lProfile, context) then return true end
		end
	end
end


local actualInstances
local function setActualInstances()
	if actualInstances ~= nil then return end
	local numTiers = EJ_GetNumTiers()
	if numTiers < 1 then
		actualInstances = false
		return
	end
	local backupTier = EJ_GetCurrentTier()
	actualInstances = {}

	for i = numTiers > 10 and numTiers - 1 or numTiers, numTiers do
		EJ_SelectTier(i)
		for j = 1, 2 do
			local showRaid = j == 2
			local index = 1
			local jInstanceID = EJ_GetInstanceByIndex(index, showRaid)
			while jInstanceID do
				--EJ_SelectInstance(jInstanceID)
				local _,_,_,_,_,_,_,_,_, instanceID = EJ_GetInstanceInfo(jInstanceID)
				actualInstances[instanceID] = true
				index = index + 1
				jInstanceID = EJ_GetInstanceByIndex(index, showRaid)
			end
		end
	end

	EJ_SelectTier(backupTier)
end


function listFrame:PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUi)
	if isInitialLogin or isReloadingUi then
		self:setAutoLoadObj()
		if isReloadingUi then return end
	end
	if not next(self.autoLoadProfiles) then return end
	setActualInstances()

	C_Timer.After(0, function()
		local _, instanceType, difficultyID, _,_,_,_, instanceID = GetInstanceInfo()
		local pName = self.autoLoadProfiles[instanceType]

		if pName and actualInstances and (instanceType == "party" or instanceType == "raid") and not actualInstances[instanceID]
		and difficultyID ~= 24 and difficultyID ~= 33 then return end -- Timewalking

		local profile = self:getProfileByName(pName or self.autoLoadProfiles.none)
		if profile and requireLoadProfile(profile) then
			self:loadProfileAddons(profile, true)
		end
	end)
end
listFrame:RegisterEvent("PLAYER_ENTERING_WORLD")


-- DROPDOWN
listFrame:HookScript("OnShow", function(self)
	local dd = LibStub("LibSFDropDown-1.5"):CreateStretchButton(self, 90, 26)
	if not self.isMainline then dd:ddSetDisplayMode("menuBackdrop") end
	self.profileBtn = dd
	dd:SetPoint("TOPRIGHT", -6, -30)
	dd:SetText(L["Profiles"])

	dd:ddSetInitFunc(function(dd, level, value)
		local info = {}

		if level == 1 then
			info.keepShownOnClick = true
			info.notCheckable = true
			info.hasArrow = true

			info.text = L["Characters"]
			info.value = "chars"
			dd:ddAddButton(info, level)

			info.text = L["Autoload profile"]
			info.value = "autoload"
			dd:ddAddButton(info, level)

			if #self.profiles ~= 0 then
				dd:ddAddSeparator(level)

				local widgets = {
					{
						icon = [[Interface\WorldMap\GEAR_64GREY]],
						OnClick = function(btn)
							self:editProfile(btn.value)
							dd:ddCloseMenus()
						end,
						OnTooltipShow = function(_, tooltip)
							tooltip:SetText(EDIT)
						end,
					},
				}
				local func = function(btn) self:loadProfileAddons(btn.value) end
				local remove = function(btn) self:removeProfile(btn.value, self.profiles) end

				local list = {}
				for i, profile in ipairs(self.profiles) do
					list[i] = {
						hasArrow = true,
						notCheckable = true,
						text = ("%s |cff808080(%d %s)"):format(profile.name, profile.count, ADDONS),
						value = profile,
						func = func,
						remove = remove,
						widgets = widgets,
					}
				end

				info.list = list
				dd:ddAddButton(info, level)
				info.list = nil
			end

			dd:ddAddSeparator(level)

			info.keepShownOnClick = nil
			info.hasArrow = nil
			info.text = L["Create profile"]
			info.func = function() self:createProfile() end
			dd:ddAddButton(info, level)

		elseif value == "chars" then
			local list = {}
			local charName = self.charName.." - "..GetRealmName()
			local empty = true

			local func = function(btn) self:loadProfileAddons(btn.value) end
			local remove = function(btn) self:removeProfile(btn.value, self.charProfiles) end

			for i = 1, #self.charProfiles do
				local profile = self.charProfiles[i]
				if profile.name ~= charName then
					empty = false
					local _,_,_, color = GetClassColor(profile.class)
					list[#list + 1] = {
						notCheckable = true,
						text = ("|c%s%s|r |cff808080(%d %s)|r"):format(color, profile.name, profile.count, ADDONS),
						value = profile,
						func = func,
						remove = remove,
					}
				end
			end

			if empty then
				info.notCheckable = true
				info.disabled = true
				info.text = EMPTY
			else
				list[#list + 1] = {
					notCheckable = true,
					text = L["Clear all"],
					func = function() self:removeAllCharProfiles() end,
				}

				info.list = list
			end
			dd:ddAddButton(info, level)

		elseif value == "autoload" then
			info.keepShownOnClick = true
			info.notCheckable = true
			info.hasArrow = true

			info.text = WORLD
			info.value = "none"
			dd:ddAddButton(info, level)

			info.text = TRACKER_HEADER_DUNGEON
			info.value = "party"
			dd:ddAddButton(info, level)

			info.text = RAID
			info.value = "raid"
			dd:ddAddButton(info, level)

			info.text = ARENA
			info.value = "arena"
			dd:ddAddButton(info, level)

			info.text = BATTLEGROUND
			info.value = "pvp"
			dd:ddAddButton(info, level)

			info.list = nil
			info.hasArrow = nil
			info.notCheckable = nil
			info.value = nil
			info.isNotRadio = true

			info.text = L["Character Specific"]
			info.func = function(_,_,_, checked)
				self.config.autoLoadChar = checked
				self:setAutoLoadObj()
			end
			info.checked = self.config.autoLoadChar
			dd:ddAddButton(info, level)

		elseif level == 2 and type(value) == "table" then
			info.notCheckable = true
			info.isTitle = true
			info.text = value.name
			dd:ddAddButton(info, level)

			info.isTitle = nil
			info.text = L["Load"]
			info.value = value
			info.func = function(btn) self:loadProfileAddons(btn.value) end
			dd:ddAddButton(info, level)

			info.text = L["Save"]
			info.func = function(btn) self:rewriteProfileAddons(btn.value) end
			dd:ddAddButton(info, level)

			info.text = L["Enable Addons"]
			info.func = function(btn) self:enableProfileAddons(btn.value) end
			dd:ddAddButton(info, level)

			info.text = L["Disable Addons"]
			info.func = function(btn) self:disableProfileAddons(btn.value) end
			dd:ddAddButton(info, level)

			dd:ddAddSpace(level)

			info.notCheckable = nil
			info.keepShownOnClick = true
			info.isNotRadio = true
			info.text = L["Highlight Addons"]
			info.value = value.addons
			info.func = function(btn, _,_, checked)
				self.selProfileAddons = checked and btn.value or nil
				self:updateList()
			end
			info.checked = self.selProfileAddons == value.addons
			dd:ddAddButton(info, level)

			dd:ddAddSpace(level)

			info.func = nil
			info.notCheckable = true
			info.hasArrow = true
			info.text = L["Also load profiles"]
			info.value = value
			dd:ddAddButton(info, level)

		elseif level == 3 then
			if type(value) == "string" then
				if #self.profiles == 0 then
					info.notCheckable = true
					info.disabled = true
					info.text = EMPTY
					dd:ddAddButton(info, level)
					return
				end

				local func = function(btn)
					self.autoLoadProfiles[value] = btn.value
					dd:ddRefresh(level)
				end
				local check = function(btn) return btn.value == self.autoLoadProfiles[value] end

				local list = {
					{
						keepShownOnClick = true,
						text = NONE,
						func = func,
						checked = check,
					},
				}

				for i, profile in ipairs(self.profiles) do
					list[#list + 1] = {
						keepShownOnClick = true,
						text = profile.name,
						value = profile.name,
						func = func,
						checked = check,
					}
				end

				info.list = list
				dd:ddAddButton(info, level)

			else
				local list = {}
				local func = function(btn, _,_, checked) self:setLoadProfiles(value, btn.value, checked) end

				for i, profile in ipairs(self.profiles) do
					if profile ~= value then
						list[#list + 1] = {
							keepShownOnClick = true,
							isNotRadio = true,
							text = profile.name,
							value = profile.name,
							func = func,
							checked = value.loadProfiles and value.loadProfiles[profile.name],
						}
					end
				end

				if #list == 0 then
					info.notCheckable = true
					info.disabled = true
					info.text = EMPTY
				else
					info.list = list
				end
				dd:ddAddButton(info, level)
			end
		end
	end)
end)


function listFrame:setAutoLoadObj()
	if self.config.autoLoadChar then
		AddonMgrAutoLoadChar = AddonMgrAutoLoadChar or {}
		self.autoLoadProfiles = AddonMgrAutoLoadChar
	else
		self.autoLoadProfiles = self.db.autoLoadProfiles
	end
end


function listFrame:saveProfileAddons(profile)
	wipe(profile.addons)
	profile.count = 0
	for i = 1, C_AddOns.GetNumAddOns() do
		if C_AddOns.GetAddOnEnableState(i, self.addonCharacter) > Enum.AddOnEnableState.None then
			profile.count = profile.count + 1
			profile.addons[C_AddOns.GetAddOnInfo(i)] = 1
		end
	end
end


function listFrame:rewriteProfileAddons(profile)
	StaticPopup_Show(self.addonName.."CUSTOM_OK_CANCEL", L["Rewrite addons to %s profile?"]:format(NORMAL_FONT_COLOR:WrapTextInColorCode(profile.name)), nil, function()
		self:saveProfileAddons(profile)
		self:updateList()
	end)
end


function listFrame:getProfileByName(name)
	if name then
		for _, profile in ipairs(self.profiles) do
			if profile.name == name then return profile end
		end
	end
end


function listFrame:enableAddonsTree(profile, enabled, context)
	context = context or {}
	if context[profile] then return end
	context[profile] = true
	for addonName in next, profile.addons do
		self:enableAddon(addonName, enabled)
	end
	if profile.loadProfiles then
		for name in next, profile.loadProfiles do
			local lProfile = self:getProfileByName(name)
			if lProfile then self:enableAddonsTree(lProfile, enabled, context) end
		end
	end
end


function listFrame:loadProfile(profile, reloadCheck)
	self:setAddonsEnabled(false)
	self:enableAddonsTree(profile, true)

	if reloadCheck then
		if self:hasAnyChanges() then
			ReloadUI()
			return
		end
		C_AddOns.SaveAddOns()
	end

	if self:IsShown() then
		self:updateFilters()
		self:updateReloadButton()
	end
end


function listFrame:loadProfileByName(name, reloadCheck, hwEvent)
	local profile = self:getProfileByName(name)
	if profile then
		if hwEvent then self:loadProfile(profile, reloadCheck)
		else self:loadProfileAddons(profile, reloadCheck) end
	end
end


function listFrame:loadProfileAddons(profile, reloadCheck)
	local actionText = reloadCheck and L["Load %s profile and reload UI?"] or L["Load %s profile?"]
	local dialog = StaticPopup_Show(self.addonName.."CUSTOM_OK_CANCEL", actionText:format(NORMAL_FONT_COLOR:WrapTextInColorCode(profile.name)), nil, function()
		self:loadProfile(profile, reloadCheck)
	end)
end


function listFrame:enableProfileAddons(profile)
	StaticPopup_Show(self.addonName.."CUSTOM_OK_CANCEL", L["Enable addons from %s profile?"]:format(NORMAL_FONT_COLOR:WrapTextInColorCode(profile.name)), nil, function()
		self:enableAddonsTree(profile, true)
		self:updateFilters()
		self:updateReloadButton()
	end)
end


function listFrame:disableProfileAddons(profile)
	StaticPopup_Show(self.addonName.."CUSTOM_OK_CANCEL", L["Disable addons from %s profile?"]:format(NORMAL_FONT_COLOR:WrapTextInColorCode(profile.name)), nil, function()
		self:enableAddonsTree(profile, false)
		self:updateFilters()
		self:updateReloadButton()
	end)
end


function listFrame:createProfile()
	local dialog = StaticPopup_Show(self.addonName.."NEW_PROFILE", nil, nil, function(popup)
		local editBox = popup.editBox or popup.EditBox
		local text = editBox:GetText()
		popup:Hide()
		if text and text ~= "" then
			local profile = self:getProfileByName(text)
			if profile then
				lastProfileName = text
				profilePopupAction = self.createProfile
				StaticPopup_Show(self.addonName.."PROFILE_EXISTS")
				return
			end
			local profile = {name = text, addons = {}}
			self:saveProfileAddons(profile)
			self.profiles[#self.profiles + 1] = profile
			sort(self.profiles, function(a, b) return a.name < b.name end)
		end
	end)
	if dialog and lastProfileName then
		local editBox = dialog.editBox or dialog.EditBox
		editBox:SetText(lastProfileName)
		editBox:HighlightText()
	end
end


function listFrame:editProfile(editProfile)
	local dialog = StaticPopup_Show(self.addonName.."EDIT_PROFILE", nil, nil, function(popup)
		local editBox = popup.editBox or popup.EditBox
		local text = editBox:GetText()
		popup:Hide()
		if text and text ~= editProfile.name and text ~= "" then
			local profile = self:getProfileByName(text)
			if profile then
				lastProfileName = text
				profilePopupAction = self.editProfile
				StaticPopup_Show(self.addonName.."PROFILE_EXISTS", nil, nil, editProfile)
				return
			end
			editProfile.name = text
			sort(self.profiles, function(a, b) return a.name < b.name end)
		end
	end)
	if dialog then
		local editBox = dialog.editBox or dialog.EditBox
		editBox:SetText(lastProfileName or editProfile.name)
		editBox:HighlightText()
	end
end


function listFrame:removeProfile(removeProfile, profiles)
	StaticPopup_Show(self.addonName.."DELETE_PROFILE", NORMAL_FONT_COLOR:WrapTextInColorCode(removeProfile.name), nil, function()
		for i, profile in ipairs(profiles) do
			if profile == removeProfile then
				tremove(profiles, i)
				if self.selProfileAddons == removeProfile.addons then
					self.selProfileAddons = nil
					self:updateList()
				end
			else
				self:setLoadProfiles(profile, removeProfile.name, false)
			end
		end
	end)
end


function listFrame:removeAllCharProfiles()
	StaticPopup_Show(self.addonName.."YOU_WANT", NORMAL_FONT_COLOR:WrapTextInColorCode(L["Remove all character profiles"]), nil, function()
		wipe(self.charProfiles)
	end)
end


function listFrame:setLoadProfiles(pProfile, cName, enabled)
	if enabled then
		pProfile.loadProfiles = pProfile.loadProfiles or {}
		pProfile.loadProfiles[cName] = 1
	elseif pProfile.loadProfiles then
		pProfile.loadProfiles[cName] = nil
		if not next(pProfile.loadProfiles) then
			pProfile.loadProfiles = nil
		end
	end
end


function listFrame:getProfilesWithAddon(name)
	local list = {}
	for i = 1, #self.profiles do
		local profile = self.profiles[i]
		if profile.addons[name] then
			list[#list + 1] = profile.name
		end
	end
	return table.concat(list, ", ")
end