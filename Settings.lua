local addon, ns = ...
local L = ns.L
local listFrame = AddonMgrAddonList


listFrame:HookScript("OnShow", function(self)
	-- scale
	self.scaleSlider:SetMinMaxValues(50, 200)
	self.scaleSlider:SetValueStep(1)
	self.scaleSlider:SetValue(self.config.scale)

	self.scaleSlider:SetScript("OnValueChanged", function(scaleSlider, value)
		if self.config.scale == value then return end
		if scaleSlider.ignore then scaleSlider:SetValue(100) return end
		if scaleSlider.cur == nil then scaleSlider.cur = self:GetScale() end
		self.config.scale = value
		local scale = value * .01
		local ks = scale / self:GetScale()
		local right = self:GetRight() / ks
		local top = self:GetTop() / ks
		self:SetScale(scale)
		self:ClearAllPoints()
		self:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", right, top)
		self:GetScript("OnDragStop")(self)
		scaleSlider:SetScale(scaleSlider.cur / scale)
		if scaleSlider.isHover then scaleSlider:GetScript("OnEnter")(scaleSlider) end
	end)
	self.scaleSlider:SetScript("OnMouseDown", function(scaleSlider, button)
		if button == "RightButton" then
			scaleSlider:SetValue(100)
			scaleSlider:SetScale(1)
			scaleSlider.ignore = true
		end
	end)
	self.scaleSlider:SetScript("OnMouseUp", function(scaleSlider)
		scaleSlider.cur = nil
		scaleSlider.ignore = nil
		scaleSlider:SetScale(1)
	end)
	self.scaleSlider:SetScript("OnMouseWheel", function(scaleSlider, delta)
		scaleSlider:SetValue(scaleSlider:GetValue() + delta)
		scaleSlider.cur = nil
		scaleSlider:SetScale(1)
	end)
	self.scaleSlider:SetScript("OnEnter", function(scaleSlider)
		scaleSlider.isHover = true
		GameTooltip:SetOwner(scaleSlider, "ANCHOR_RIGHT")
		GameTooltip:AddLine(L["Scale"].." ("..scaleSlider:GetValue().."%)")
		GameTooltip:AddLine(self.RIGHT_MOUSE_ICON..L["Right click to reset"], 1, 1, 1)
		GameTooltip:Show()
	end)
	self.scaleSlider:SetScript("OnLeave", function(scaleSlider)
		scaleSlider.isHover = nil
		GameTooltip:Hide()
	end)

	-- settings
	LibStub("LibSFDropDown-1.5"):SetMixin(self.settingsBtn)
	self.settingsBtn:ddHideWhenButtonHidden()
	self.settingsBtn:ddSetNoGlobalMouseEvent(true)
	self.settingsBtn:ddSetDisplayMode(self.isMainline and "menu" or "menuBackdrop")
	self.settingsBtn:SetScript("OnClick", function(self)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		local scale = self:GetEffectiveScale() / UIParent:GetScale()
		self:ddToggle(1, nil, self, scale < 1 and -10 * scale or -10, 0)
	end)

	self.settingsBtn:ddSetInitFunc(function(dd, level, value)
		local info = {}

		if level == 1 then
			info.keepShownOnClick = true
			info.notCheckable = true
			info.isTitle = true
			info.text = L["Options"]
			dd:ddAddButton(info, level)

			info.notCheckable = nil
			info.isTitle = nil
			info.isNotRadio = true
			info.text = ADDON_FORCE_LOAD
			info.func = function(btn, _,_, checked)
				C_AddOns.SetAddonVersionCheck(not checked)
				self:updateReloadButton()
				self:updateList()
			end
			info.checked = not C_AddOns.IsAddonVersionCheckEnabled()
			dd:ddAddButton(info, level)

			info.text = L["Show minimap button"]
			info.func = function(_,_,_, checked)
				self.db.omb.hide = not checked
				if self.db.omb.hide then
					LibStub("LibDBIcon-1.0"):Hide(addon)
				else
					LibStub("LibDBIcon-1.0"):Show(addon)
				end
			end
			info.checked = not self.db.omb.hide
			dd:ddAddButton(info, level)

			info.indent = 16
			info.text = L["Do not show tooltip"]
			info.func = function(_,_,_, checked)
				self.db.omb.dontShowTooltip = checked or nil
			end
			info.checked = self.db.omb.dontShowTooltip
			dd:ddAddButton(info, level)

			info.indent = nil
			info.text = L["Replace Addon wow menu button"]
			info.func = function(_,_,_, checked)
				self.config.replaceAddonButton = checked
			end
			info.checked = self.config.replaceAddonButton
			dd:ddAddButton(info, level)

			info.isNotRadio = nil
			info.func = nil
			info.checked = nil
			info.notCheckable = true
			info.hasArrow = true

			info.text = L["Memory Update"]
			info.value = "memUpdate"
			dd:ddAddButton(info, level)

			if C_AddOnProfiler.GetApplicationMetric then
				info.text = L["CPU Update"]
				info.value = "cpuUpdate"
				dd:ddAddButton(info, level)

				info.text = L["CPU Accuracy"]
				info.value = "cpuAccuracy"
				dd:ddAddButton(info, level)
			end

			dd:ddAddSeparator(level)

			info.hasArrow = nil
			info.isTitle = true
			info.text = L["List Options"]
			dd:ddAddButton(info, level)

			info.isTitle = nil
			info.text = L["Collapse All"]
			info.func = function()
				self:setAllCollapsed(true)
				self:updateData()
			end
			dd:ddAddButton(info, level)

			info.text = L["Expand All"]
			info.func = function()
				self:setAllCollapsed(false)
				self:updateData()
			end
			dd:ddAddButton(info, level)

			info.notCheckable = nil
			info.isNotRadio = true
			info.text = L["Show Name instead of Title"]
			info.func = function(_,_,_, checked)
				self.config.showNameInsteadOfTitle = checked or nil
				self:updateList()
			end
			info.checked = self.config.showNameInsteadOfTitle
			dd:ddAddButton(info, level)

			info.text = L["Show Icon"]
			info.func = function(_,_,_, checked)
				self.config.showIcon = checked
				self:updateList()
				dd:ddRefresh(level)
			end
			info.checked = self.config.showIcon
			dd:ddAddButton(info, level)

			info.indent = 16
			info.disabled = function() return not self.config.showIcon end
			info.text = L["Show no Icon Texture"]
			info.func = function(_,_,_, checked)
				self.config.showNoIcon = checked
				self:updateList()
			end
			info.checked = self.config.showNoIcon
			dd:ddAddButton(info, level)

			info.indent = nil
			info.disabled = nil
			info.text = L["Show Version"]
			info.func = function(_,_,_, checked)
				self.config.showVersion = checked or nil
				self:updateList()
			end
			info.checked = self.config.showVersion
			dd:ddAddButton(info, level)

			info.text = L["Infinity Nesting of Subtags"]
			info.func = function(_,_,_, checked)
				self.config.infinitySubtags = checked or nil
			end
			info.checked = self.config.infinitySubtags
			dd:ddAddButton(info, level)

			info.func = nil
			info.checked = nil
			info.notCheckable = true
			info.hasArrow = true
			info.text = L["Categories by"]
			info.value = "listCat"
			dd:ddAddButton(info, level)

			info.text = L["Group by"]
			info.value = "listGroup"
			dd:ddAddButton(info, level)

			info.text = L["Sort by"]
			info.value = "sort"
			dd:ddAddButton(info, level)

			dd:ddAddSeparator(level)

			info.value = nil
			info.hasArrow = nil
			info.isTitle = true
			info.text = L["Search Options"]
			dd:ddAddButton(info, level)

			info.isTitle = nil
			info.notCheckable = nil
			info.text = L["Autofocus search when opening addon"]
			info.func = function(_,_,_, checked)
				self.config.autofocusSearch = checked
			end
			info.checked = self.config.autofocusSearch
			dd:ddAddButton(info, level)

			info.notCheckable = true
			info.hasArrow = true
			info.text = L["Search by"]
			info.value = "searchBy"
			dd:ddAddButton(info, level)

			info.hasArrow = nil
			info.keepShownOnClick = nil
			info.text = L["Search for the guilty addon"]
			info.func = function() self:startSearch() end
			info.OnTooltipShow = function(btn, tooltip)
				tooltip:SetText(L["Search for the guilty addon"])
				tooltip:AddLine(L["SEARCH_ADDON_TOOLTIP"], 1,1,1, true)
			end
			dd:ddAddButton(info, level)

		elseif value == "memUpdate" then
			info.keepShownOnClick = true

			info.func = function(btn)
				self.memUpdateTimer = btn.value or 0
				self.config.memUpdate = btn.value
				dd:ddRefresh(level)
			end
			info.checked = function(btn) return btn.value == self.config.memUpdate end

			info.text = L["Disable"]
			info.value = false
			dd:ddAddButton(info, level)

			info.text = L["%s seconds"]:format(1)
			info.value = 1
			dd:ddAddButton(info, level)

			info.text = L["%s seconds"]:format(5)
			info.value = 5
			dd:ddAddButton(info, level)

			info.text = L["%s seconds"]:format(10)
			info.value = 10
			dd:ddAddButton(info, level)

			info.text = L["%s seconds"]:format(15)
			info.value = 15
			dd:ddAddButton(info, level)

			info.text = L["%s seconds"]:format(30)
			info.value = 30
			dd:ddAddButton(info, level)

		elseif value == "cpuUpdate" then
			info.keepShownOnClick = true
			info.disabled = not C_AddOnProfiler.IsEnabled()

			info.func = function(btn)
				self.cpuUpdateTimer = btn.value or 0
				self.config.cpuUpdate = btn.value
				if not self.config.cpuUpdate then
					self.config.cpuSortBy = nil
					self:updateCpuButtons()
				else
					self:updateList()
				end
				self:updatePerformance()
				dd:ddRefresh(level)
			end
			info.checked = function(btn) return btn.value == self.config.cpuUpdate end

			info.text = L["Disable"]
			info.value = false
			dd:ddAddButton(info, level)

			info.text = L["%s seconds"]:format(.1)
			info.value = .1
			dd:ddAddButton(info, level)

			info.text = L["%s seconds"]:format(.25)
			info.value = .25
			dd:ddAddButton(info, level)

			info.text = L["%s seconds"]:format(.5)
			info.value = .5
			dd:ddAddButton(info, level)

			info.text = L["%s seconds"]:format(1)
			info.value = 1
			dd:ddAddButton(info, level)

			info.text = L["%s seconds"]:format(5)
			info.value = 5
			dd:ddAddButton(info, level)

		elseif value == "cpuAccuracy" then
			info.keepShownOnClick = true
			info.disabled = not C_AddOnProfiler.IsEnabled()

			info.func = function(btn)
				self.config.cpuAccuracy = btn.value
				self:setCpuAccuracyStr()
				self:updatePerformance()
				self:updateList()
				dd:ddRefresh(level)
			end
			info.checked = function(btn) return btn.value == self.config.cpuAccuracy end

			for i = 1, 4 do
				info.text = tostring(1 / 10^i)
				info.value = i
				dd:ddAddButton(info, level)
			end

		elseif value == "listCat" then
			info.keepShownOnClick = true

			info.func = function(btn)
				self.config.catGroup = btn.value
				self.config.cpuSortBy = nil
				self:updateCpuButtons()
				dd:ddRefresh(level)
			end
			info.checked = function(btn) return btn.value == self.config.catGroup end

			info.text = CATEGORIES
			info.value = "cat"
			dd:ddAddButton(info, level)

			info.text = L["tags"]
			info.value = "tag"
			dd:ddAddButton(info, level)

			info.text = NONE
			info.value = nil
			dd:ddAddButton(info, level)

		elseif value == "listGroup" then
			info.keepShownOnClick = true

			info.func = function(btn)
				self.config.listGroup = btn.value
				self.config.cpuSortBy = nil
				self:updateCpuButtons()
				dd:ddRefresh(level)
			end
			info.checked = function(btn) return btn.value == self.config.listGroup end

			info.text = L["Dependencies"]
			info.value = "dep"
			dd:ddAddButton(info, level)

			info.text = L["Dependency tree"]
			info.value = "treeDep"
			dd:ddAddButton(info, level)

			info.text = L["Group"]
			info.value = "group"
			dd:ddAddButton(info, level)

			info.text = NONE
			info.value = "none"
			dd:ddAddButton(info, level)

		elseif value == "sort" then
			info.keepShownOnClick = true

			info.func = function(btn)
				self.config.sortBy = btn.value
				self:setCategories()
				dd:ddRefresh(level)
			end
			info.checked = function(btn) return btn.value == self.config.sortBy end

			info.text = L["Title"]
			info.value = "title"
			dd:ddAddButton(info, level)

			info.text = NAME
			info.value = "name"
			dd:ddAddButton(info, level)

			if not self:isProfilerEnabled() then return end

			dd:ddAddSeparator(level)

			info.func = function(btn)
				self.config.cpuSortBy = btn.value
				self:updateCpuButtons()
				dd:ddRefresh(level)
			end
			info.checked = function(btn) return btn.value == self.config.cpuSortBy end

			info.text = L["Current CPU"]
			info.value = "current"
			dd:ddAddButton(info, level)

			info.text = L["Average CPU"]
			info.value = "average"
			dd:ddAddButton(info, level)

			info.text = L["Peak CPU"]
			info.value = "peak"
			dd:ddAddButton(info, level)

			info.text = L["Encounter CPU"]
			info.value = "encounter"
			dd:ddAddButton(info, level)

			info.text = NONE
			info.value = nil
			dd:ddAddButton(info, level)

		elseif value == "searchBy" then
			info.keepShownOnClick = true
			info.isNotRadio = true

			info.func = function(btn, _,_, checked)
				self.config.searchBy[btn.value] = checked
				self:updateFilters()
			end
			info.checked = function(btn) return self.config.searchBy[btn.value] end

			info.text = L["Title"]
			info.value = "title"
			dd:ddAddButton(info, level)

			info.text = NAME
			info.value = "name"
			dd:ddAddButton(info, level)

			info.text = L["Author"]
			info.value = "author"
			dd:ddAddButton(info, level)

			info.text = CATEGORY
			info.value = "category"
			dd:ddAddButton(info, level)

			info.text = L["tags"]
			info.value = "tags"
			dd:ddAddButton(info, level)
		end
	end)
end)