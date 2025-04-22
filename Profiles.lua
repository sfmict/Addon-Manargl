local addon, ns = ...
local L = ns.L
local listFrame = AddonMgrAddonList


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
		curCharProfile = {name = charName}
		self.charProfiles[#self.charProfiles + 1] = curCharProfile
		sort(self.charProfiles, function(a, b) return a.name < b.name end)
	end
	curCharProfile.class = select(2, UnitClass("player"))
	self:saveProfileAddons(curCharProfile)
end
listFrame:RegisterEvent("PLAYER_LOGOUT")


listFrame:HookScript("OnShow", function(self)
	local dd = LibStub("LibSFDropDown-1.5"):CreateStretchButtonOriginal(self, 90, 26)
	self.profileBtn = dd
	dd:SetPoint("TOPRIGHT", -35, -30)
	dd:SetText(L["Profiles"])
	local lastProfileName, profilePopupAction

	--POPUP
	StaticPopupDialogs[self.addonName.."NEW_PROFILE"] = {
		text = addon..": "..L["New profile"],
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
		self:profilePopupAction(data)
		self.profilePopupAction = nil
		self.lastProfileName = nil
	end
	StaticPopupDialogs[self.addonName.."PROFILE_EXISTS"] = {
		text = addon..": "..L["A profile with the same name exists."],
		button1 = OKAY,
		hideOnEscape = 1,
		whileDead = 1,
		OnAccept = profileExistsAccept,
		OnCancel = profileExistsAccept,
	}
	StaticPopupDialogs[self.addonName.."EDIT_PROFILE"] = {
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
	StaticPopupDialogs[self.addonName.."DELETE_PROFILE"] = {
		text = addon..": "..L["Are you sure you want to delete %s profile?"],
		button1 = DELETE,
		button2 = CANCEL,
		hideOnEscape = 1,
		whileDead = 1,
		OnAccept = function(_, cb) cb() end,
	}
	StaticPopupDialogs[self.addonName.."YOU_WANT"] = {
		text = addon..": "..L["Are you sure you want to %s?"],
		button1 = OKAY,
		button2 = CANCEL,
		hideOnEscape = 1,
		whileDead = 1,
		OnAccept = function(_, cb) cb() end,
	}
	StaticPopupDialogs[self.addonName.."CUSTOM_OK_CANCEL"] = {
		text = addon..": %s",
		button1 = OKAY,
		button2 = CANCEL,
		hideOnEscape = 1,
		whileDead = 1,
		OnAccept = function(_, cb) cb() end,
	}

	-- DROPDOWN
	dd:ddSetInitFunc(function(dd, level, value)
		local info = {}

		if level == 1 then
			info.keepShownOnClick = true
			info.notCheckable = true
			info.hasArrow = true
			info.text = L["Charactes"]
			info.value = "chars"
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
				local remove = function(btn) self:removeProfile(btn.value, self.profiles) end

				local list = {}
				for i, profile in ipairs(self.profiles) do
					list[#list + 1] = {
						keepShownOnClick = true,
						hasArrow = true,
						notCheckable = true,
						text = ("%s |cff808080(%d %s)"):format(profile.name, #profile, ADDONS),
						value = profile,
						widgets = widgets,
						remove = remove,
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
						text = ("|C%s%s|r |cff808080(%d %s)"):format(color, profile.name, #profile, ADDONS),
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

		elseif type(value) == "table" and level == 2 then
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
			info.value = value
			info.func = function(btn) self:rewriteProfileAddons(btn.value) end
			dd:ddAddButton(info, level)

			info.text = L["Enable Addons"]
			info.value = value
			info.func = function(btn) self:enableProfileAddons(btn.value) end
			dd:ddAddButton(info, level)

			info.text = L["Disable Addons"]
			info.value = value
			info.func = function(btn) self:disableProfileAddons(btn.value) end
			dd:ddAddButton(info, level)

			dd:ddAddSpace(level)

			info.func = nil
			info.hasArrow = true
			info.text = L["Also load profiles"]
			info.value = value
			dd:ddAddButton(info, level)

		elseif level == 3 then
			local list = {}
			local EMPTY = true

			local func = function(btn, _,_, checked) self:setLoadProfiles(value, btn.value, checked) end

			for i, profile in ipairs(self.profiles) do
				if profile ~= value then
					count = false
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

			if empty then
				info.notCheckable = true
				info.disabled = true
				info.text = EMPTY
			else
				info.list = list
			end
			dd:ddAddButton(info, level)
		end
	end)
end)


function listFrame:saveProfileAddons(profile)
	for i = 1, #profile do profile[i] = nil end
	for i = 1, C_AddOns.GetNumAddOns() do
		if C_AddOns.GetAddOnEnableState(i, self.charName) > Enum.AddOnEnableState.None then
			profile[#profile + 1] = C_AddOns.GetAddOnInfo(i)
		end
	end
end


function listFrame:rewriteProfileAddons(profile)
	StaticPopup_Show(self.addonName.."CUSTOM_OK_CANCEL", L["Rewrite addon to %s profile?"]:format(NORMAL_FONT_COLOR:WrapTextInColorCode(profile.name)), nil, function()
		self:saveProfileAddons(profile)
	end)
end


function listFrame:enableAddonsTree(profile, enabled, context)
	context = context or {}
	if context[profile] then return end
	context[profile] = true
	for i, addonName in ipairs(profile) do
		if self.indexByName[addonName] then
			self:enableAddon(addonName, enabled)
		end
	end
	if profile.loadProfiles then
		for name in next, profile.loadProfiles do
			for _, p in ipairs(self.profiles) do
				if p.name == name then
					self:enableAddonsTree(p, enabled, context)
					break
				end
			end
		end
	end
end


function listFrame:loadProfileAddons(profile)
	StaticPopup_Show(self.addonName.."CUSTOM_OK_CANCEL", L["Load %s profile?"]:format(NORMAL_FONT_COLOR:WrapTextInColorCode(profile.name)), nil, function()
		for i = 1, C_AddOns.GetNumAddOns() do self:enableAddon(self.nameByIndex[i], false) end
		self:enableAddonsTree(profile, true)
		self:updateList()
		self:updateReloadButton()
	end)
end


function listFrame:enableProfileAddons(profile)
	StaticPopup_Show(self.addonName.."CUSTOM_OK_CANCEL", L["Enable addons from %s profile?"]:format(NORMAL_FONT_COLOR:WrapTextInColorCode(profile.name)), nil, function()
		self:enableAddonsTree(profile, true)
		self:updateList()
		self:updateReloadButton()
	end)
end


function listFrame:disableProfileAddons(profile)
	StaticPopup_Show(self.addonName.."CUSTOM_OK_CANCEL", L["Disable addons from %s profile?"]:format(NORMAL_FONT_COLOR:WrapTextInColorCode(profile.name)), nil, function()
		self:enableAddonsTree(profile, false)
		self:updateList()
		self:updateReloadButton()
	end)
end


function listFrame:createProfile()
	local dialog = StaticPopup_Show(self.addonName.."NEW_PROFILE", nil, nil, function(popup)
		local text = popup.editBox:GetText()
		popup:Hide()
		if text and text ~= "" then
			for i, profile in ipairs(self.profiles) do
				if profile.name == text then
					self.lastProfileName = text
					self.profilePopupAction = self.createProfile
					StaticPopup_Show(self.addonName.."PROFILE_EXISTS")
					return
				end
			end
			local profile = {name = text}
			self:saveProfileAddons(profile)
			self.profiles[#self.profiles + 1] = profile
			sort(self.profiles, function(a, b) return a.name < b.name end)
		end
	end)
	if dialog and self.lastProfileName then
		dialog.editBox:SetText(self.lastProfileName)
		dialog.editBox:HighlightText()
	end
end


function listFrame:editProfile(editProfile)
	local dialog = StaticPopup_Show(self.addonName.."EDIT_PROFILE", nil, nil, function(popup)
		local text = popup.editBox:GetText()
		popup:Hide()
		if text and text ~= editProfile.name and text ~= "" then
			for _, profile in ipairs(self.profiles) do
				if profile.name == text then
					self.lastProfileName = text
					self.profilePopupAction = self.editProfile
					StaticPopup_Show(self.addonName.."PROFILE_EXISTS", nil, nil, editProfile)
					return
				end
			end
			editProfile.name = text
			sort(self.profiles, function(a, b) return a.name < b.name end)
		end
	end)
	if dialog then
		dialog.editBox:SetText(self.lastProfileName or editProfile.name)
		dialog.editBox:HighlightText()
	end
end


function listFrame:removeProfile(removeProfile, profiles)
	StaticPopup_Show(self.addonName.."DELETE_PROFILE", NORMAL_FONT_COLOR:WrapTextInColorCode(removeProfile.name), nil, function()
		for i, profile in ipairs(profiles) do
			if profile == removeProfile then
				tremove(profiles, i)
				break
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