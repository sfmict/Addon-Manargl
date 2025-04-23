local addon, ns = ...
local L = ns.L
local listFrame = AddonMgrAddonList
local C_AddOns, C_AddOnProfiler = C_AddOns, C_AddOnProfiler

local LEFT_MOUSE_ICON = C_Texture.GetAtlasInfo("newplayertutorial-icon-mouse-leftbutton") and "|A:newplayertutorial-icon-mouse-leftbutton:0:0|a" or ""
local RIGHT_MOUSE_ICON = C_Texture.GetAtlasInfo("newplayertutorial-icon-mouse-rightbutton") and "|A:newplayertutorial-icon-mouse-rightbutton:0:0|a" or ""
local BANNED = "BANNED"
local SECURE_PROTECTED = "SECURE_PROTECTED"
local SECURE = "SECURE"


listFrame:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)
listFrame:RegisterEvent("ADDON_LOADED")


function listFrame:ADDON_LOADED(addonName)
	if addonName == addon then
		AddonMgrDB = AddonMgrDB or {}
		self.db = AddonMgrDB
		self.db.config = self.db.config or {}
		self.db.profiles = self.db.profiles or {}
		self.db.charProfiles = self.db.charProfiles or {}
		self.db.depCollapsed = self.db.depCollapsed or {}
		self.db.locked = self.db.locked or {}
		self.db.omb = self.db.omb or {}

		self.config = self.db.config
		self.config.listGroup = self.config.listGroup or "dep"
		self.config.sortBy = self.config.sortBy or "name"
		if self.config.memUpdate == nil then self.config.memUpdate = 30 end
		if self.config.cpuUpdate == nil then self.config.cpuUpdate = 1 end
		if self.config.replaceAddonButton == nil then self.config.replaceAddonButton = true end
		if self.config.usePlayer == nil then self.config.usePlayer = true end
		if self.config.showIcon == nil then self.config.showIcon = true end
		if self.config.showNoIcon == nil then self.config.showNoIcon = true end
		self.config.searchBy = self.config.searchBy or {}
		if self.config.searchBy.title == nil then self.config.searchBy.title = true end
		if self.config.searchBy.name == nil then self.config.searchBy.name = true end
		if self.config.searchBy.author == nil then self.config.searchBy.author = true end
		if self.config.searchBy.category == nil then self.config.searchBy.category = true end

		self.profiles = self.db.profiles
		self.charProfiles = self.db.charProfiles
		self.depCollapsed = self.db.depCollapsed
		self.locked = self.db.locked

		self.charName = UnitName("player")
		self.sorted = {}
		self.indexByName = {}
		self.nameByIndex = {}
		self.titleByIndex = {}
		self.startStatus = {}
		self.outOfDateIndexes = {}

		for i = 1, C_AddOns.GetNumAddOns() do
			local name, title, _,_, reason = C_AddOns.GetAddOnInfo(i)
			self.sorted[i] = i
			self.indexByName[name] = i
			self.nameByIndex[i] = name
			self.titleByIndex[i] = title:gsub("|[Cc]%x%x%x%x%x%x%x%x", ""):gsub("|[Rr]", ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):trim():lower()
			self.startStatus[i] = C_AddOns.GetAddOnEnableState(i, self.charName) > Enum.AddOnEnableState.None
			if reason == "INTERFACE_VERSION" then
				self.outOfDateIndexes[i] = true
			end
		end

		for name in next, self.depCollapsed do
			if not self.indexByName[name] then
				self.depCollapsed[name] = nil
			end
		end

		-- MENU BUTTON HOOK
		GameMenuFrame:HookScript("OnShow", function(GameMenuFrame)
			local function overrideScript(widget)
				local oldClick = widget:GetScript("OnClick")
				widget:SetScript("OnClick", function(...)
					if self.config.replaceAddonButton then
						PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
						HideUIPanel(GameMenuFrame)
						self:Show()
					else
						oldClick(...)
					end
				end)
			end

			if GameMenuButtonAddons then
				overrideScript(GameMenuButtonAddons)
			else
				for widget in GameMenuFrame.buttonPool:EnumerateActive() do
					if widget:GetText() == ADDONS then
						overrideScript(widget)
						break
					end
				end
			end
		end)
	elseif self.dataProvider and self.indexByName[addonName] then
		self:updateData()
	end
end


listFrame:SetScript("OnShow", function(self)
	self:SetScript("OnShow", self.onShow)
	self:SetFrameLevel(2000)
	self:RegisterForDrag("LeftButton")
	self:SetTitle(C_AddOns.GetAddOnMetadata(addon, "Title"))
	tinsert(UISpecialFrames, self:GetName())

	self.addonName = ("%s_ADDON_"):format(addon:upper())
	self.isMainline = WOW_PROJECT_MAINLINE == WOW_PROJECT_ID

	self.performance = self.inset.performance
	self.currentCPU = self.performance.left.current
	self.averageCPU = self.performance.left.average
	self.peakCPU = self.performance.right.peak
	self.encounterCPU = self.performance.right.encounter

	self.currentIcon = CreateSimpleTextureMarkup([[Interface\AddOns\AddonMrgl\media\current]], 16, 16)
	self.averageIcon = CreateSimpleTextureMarkup([[Interface\AddOns\AddonMrgl\media\average]], 16, 16)
	self.peakIcon = CreateSimpleTextureMarkup([[Interface\AddOns\AddonMrgl\media\peak]], 16, 16)
	self.encounterIcon = CreateSimpleTextureMarkup([[Interface\AddOns\AddonMrgl\media\weapon]], 16, 16)

	self.currentStr = self.currentIcon.." %s"
	self.averageStr = "%s |Cff777777|||r "..self.averageIcon.." %s"
	self.peakStr = "%s |Cff777777|||r "..self.peakIcon.." %s"
	self.encounterStr = "%s |Cff777777|||r "..self.encounterIcon.." %s"

	local lsfdd = LibStub("LibSFDropDown-1.5")

	if not self.isMainline then
		self.closeButton:SetPoint("TOPRIGHT", 4, 4)

		self.settingsBtn.Icon:SetTexture([[Interface\Worldmap\Gear_64]])
		self.settingsBtn.Icon:SetTexCoord(0, .5, 0, .5)
		self.settingsBtn.Icon:SetVertexColor(.7, .7, .7)
		self.settingsBtn.Icon:SetDesaturated(true)
		self.settingsBtn.Icon:SetSize(20, 20)
		self.settingsBtn:SetAlpha(.8)
		self.settingsBtn:SetScript("OnEnter", function(self)
			self:SetAlpha(1)
			self.Icon:SetVertexColor(.9, .9, .9)
		end)
		self.settingsBtn:SetScript("OnLeave", function(self)
			self:SetAlpha(.8)
			self.Icon:SetVertexColor(.7, .7, .7)
		end)
		self.settingsBtn:SetScript("OnMouseDown", function(self) self.Icon:AdjustPointsOffset(1, -1) end)
		self.settingsBtn:SetScript("OnMouseUp", function(self) self.Icon:AdjustPointsOffset(-1, 1) end)

		self.inset:SetPoint("BOTTOMRIGHT", -6, 28)
		self.enableAll:SetPoint("BOTTOMLEFT", 8, 6)
		self.cancel:SetPoint("BOTTOMRIGHT", -16, 6)
		self.resize:SetPoint("BOTTOMRIGHT", -4, 6)
	end

	-- SET SIZE & POS
	local minWidth = 600
	local minHeight = 400
	local maxWidth = UIParent:GetWidth() - 100
	local maxHeight = UIParent:GetHeight() - 100
	local width = Clamp(self.config.width or 600, minWidth, maxWidth)
	local height = Clamp(self.config.height or maxHeight * .75, minHeight, maxHeight)
	self:SetSize(width, height)
	if self.config.posX and self.config.posY then
		self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", self.config.posX, self.config.posY)
	end

	-- MOVING
	self:SetScript("OnDragStart", self.StartMoving)
	self:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		self.config.posX, self.config.posY = self:GetCenter()
	end)

	-- RESIZE
	self.resize:SetScript("OnEnter", function() SetCursor("UI_RESIZE_CURSOR") end)
	self.resize:SetScript("OnLeave", function() SetCursor(nil) end)
	self.resize:SetScript("OnMouseDown", function(self)
		local parent = self:GetParent()
		local maxWidth = UIParent:GetWidth() - 100
		local maxHeight = UIParent:GetHeight() - 100
		parent:SetResizeBounds(min(minWidth, maxWidth), min(minHeight, maxHeight), maxWidth, maxHeight)
		parent:StartSizing("BOTTOMRIGHT", true)
	end)
	self.resize:SetScript("OnMouseUp", function(self)
		local parent = self:GetParent()
		parent:StopMovingOrSizing()
		parent.config.width, parent.config.height = parent:GetSize()
	end)

	-- CIRCULAR & CATEGORIES
	local context = {}
	self.circular = {}
	self.catigoriesList = {}
	self.categoriesFilter = {}
	local function checkCirc(i)
		if context[i] then self.circular[i] = true return end
		context[i] = true
		local deps = {C_AddOns.GetAddOnDependencies(i)}
		for i = 1, #deps do
			local di = self.indexByName[deps[i]]
			if di and checkCirc(di) then return end
		end
		context[i] = nil
	end
	for i = 1, C_AddOns.GetNumAddOns() do
		checkCirc(i)
		local category = C_AddOns.GetAddOnMetadata(i, "Category")
		if category then
			if not self.categoriesFilter[category] then
				self.categoriesFilter[category] = true
				self.catigoriesList[#self.catigoriesList + 1] = category
			end
		end
	end
	sort(self.catigoriesList)
	self.categoriesFilter["rest"] = true

	-- CHARACTER
	self.charSelect = self.isMainline and lsfdd:CreateModernButtonOriginal(self) or lsfdd:CreateButtonOriginal(self)
	self.charSelect:SetPoint("TOPLEFT", 12, -30)
	self.charSelect:ddSetSelectedText(self.config.usePlayer and self.charName or ALL)

	self.charSelect:ddSetInitFunc(function(dd)
		local info = {}

		local func = function(btn)
			self.config.usePlayer = btn.value
			self:setAddonCharacter()
			self:updateList()
			dd:ddSetSelectedText(btn.text)
		end

		info.text = ALL
		info.func = func
		info.value = false
		info.checked = not self.config.usePlayer
		dd:ddAddButton(info)

		info.text = self.charName
		info.func = func
		info.value = true
		info.checked = self.config.usePlayer
		dd:ddAddButton(info)
	end)

	-- SEARCH
	self.searchBox = CreateFrame("Editbox", nil, self, "SearchBoxTemplate")
	self.searchBox:SetSize(140, 22)
	self.searchBox:SetPoint("LEFT", self.charSelect, "RIGHT", 15, 0)
	self.searchBox:HookScript("OnTextChanged", function(self) self:GetParent():updateFilters() end)

	-- FILTER
	self.filterBtn = lsfdd:CreateStretchButtonOriginal(self, 90, 26)
	self.filterBtn:SetPoint("LEFT", self.searchBox, "RIGHT", 2, 0)
	self.filterBtn:SetText(FILTER)
	if not self.isMainline then self.filterBtn:ddSetDisplayMode("menuBackdrop") end

	self.filters = {
		enabled = true,
		disabled = true,
	}

	self.filterBtn:ddSetInitFunc(function(dd, level, value)
		local info = {}
		info.keepShownOnClick = true
		info.isNotRadio = true

		if level == 1 then
			info.text = L["Enabled"]
			info.func = function(btn, _,_, checked)
				self.filters.enabled = checked
				self:updateFilters()
			end
			info.checked = self.filters.enabled
			dd:ddAddButton(info, level)

			info.text = L["Disabled"]
			info.func = function(btn, _,_, checked)
				self.filters.disabled = checked
				self:updateFilters()
			end
			info.checked = self.filters.disabled
			dd:ddAddButton(info, level)

			dd:ddAddSpace()

			info.func = nil
			info.checked = nil
			info.notCheckable = true
			info.hasArrow = true
			info.text = CATEGORIES
			info.value = "categories"
			dd:ddAddButton(info, level)

		elseif value == "categories" then
			info.notCheckable = true

			info.text = CHECK_ALL
			info.func = function()
				for k in next, self.categoriesFilter do
					self.categoriesFilter[k] = true
				end
				self:updateFilters()
				dd:ddRefresh(level)
			end
			dd:ddAddButton(info, level)

			info.text = UNCHECK_ALL
			info.func = function()
				for k in next, self.categoriesFilter do
					self.categoriesFilter[k] = false
				end
				self:updateFilters()
				dd:ddRefresh(level)
			end
			dd:ddAddButton(info, level)

			info.notCheckable = nil

			info.func = function(btn, _,_, checked)
				self.categoriesFilter[btn.value] = checked
				self:updateFilters()
				dd:ddRefresh(level)
			end
			info.checked = function(btn) return self.categoriesFilter[btn.value] end

			for i = 1, #self.catigoriesList do
				info.text = self.catigoriesList[i]
				info.value = info.text
				dd:ddAddButton(info, level)
			end

			info.text = L["Rest"]
			info.value = "rest"
			dd:ddAddButton(info, level)
		end
	end)

	--FILTER RESET
	self.resetBtn = CreateFrame("BUTTON", nil, self.filterBtn, "UIResetButtonTemplate")
	self.resetBtn:SetPoint("CENTER", self.filterBtn, "TOPRIGHT", -3, -3)
	self.resetBtn:SetScript("OnClick", function(btn)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		btn:GetParent():GetParent():resetFilters()
		btn:Hide()
	end)

	-- CPU SORT
	local cpuBtnClick = function(btn)
		self.config.cpuSortBy = self.config.cpuSortBy ~= btn.value and btn.value or nil
		self:updateCpuButtons()
	end

	self.currentCPU.value = "current"
	self.currentCPU:SetScript("OnClick", cpuBtnClick)
	self.averageCPU.value = "average"
	self.averageCPU:SetScript("OnClick", cpuBtnClick)
	self.peakCPU.value = "peak"
	self.peakCPU:SetScript("OnClick", cpuBtnClick)
	self.encounterCPU.value = "encounter"
	self.encounterCPU:SetScript("OnClick", cpuBtnClick)

	-- LIST
	local indent = 16
	local pad = 2
	local left = 4
	local spacing = 2
	self.view = CreateScrollBoxListTreeListView(indent, pad, pad, left, pad, spacing)
	self.view:SetElementExtent(20)

	local normalInit = function(...) self:normalInit(...) end
	local parentInit = function(...) self:parentInit(...) end

	self.view:SetElementFactory(function(factory, node)
		if node:GetData().isParent then
			factory("AddonMgrListParent", parentInit)
		else
			factory("AddonMgrListNormal", normalInit)
		end
	end)

	self.scrollBox = self.inset.scrollBox
	ScrollUtil.InitScrollBoxListWithScrollBar(self.scrollBox, self.inset.scrollBar, self.view)

	-- ENABLE & DISABLE
	local width = math.max(self.enableAll:GetFontString():GetStringWidth(), self.disableAll:GetFontString():GetStringWidth()) + 20
	self.enableAll:SetWidth(width)
	self.disableAll:SetWidth(width)

	self.enableAll:SetScript("OnClick", function(btn)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		local parent = btn:GetParent()
		for i = 1, C_AddOns.GetNumAddOns() do
			parent:enableAddon(parent.nameByIndex[i], true)
		end
		parent:updateList()
		parent:updateReloadButton()
	end)

	self.disableAll:SetScript("OnClick", function(btn)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		local parent = btn:GetParent()
		for i = 1, C_AddOns.GetNumAddOns() do
			parent:enableAddon(parent.nameByIndex[i], false)
		end
		parent:updateList()
		parent:updateReloadButton()
	end)

	-- RELOAD & CANCEL
	width = math.max(self.okay:GetFontString():GetStringWidth(), self.cancel:GetFontString():GetStringWidth()) + 20
	self.okay:SetText(OKAY)
	self.okay:SetWidth(width)
	self.cancel:SetWidth(width)

	self.okay:SetScript("onClick", function(btn)
		PlaySound(SOUNDKIT.GS_LOGIN_CHANGE_REALM_OK)
		local parent = btn:GetParent()
		parent.save = true
		parent:Hide()
		if parent.shouldReload then
			ReloadUI()
		end
	end)

	self.cancel:SetScript("OnClick", function(btn)
		PlaySound(SOUNDKIT.GS_LOGIN_CHANGE_REALM_CANCEL)
		local parent = btn:GetParent()
		parent:Hide()
	end)

	-- TABLES
	self.hasParentByIndex = {}
	self.childByPIndex = {}
	self.filtred = {}
	self.metrics = {}

	-- INIT
	self:updatePerformance()
	self:setAddonCharacter()
	self:updateCpuButtons()
	UpdateAddOnMemoryUsage()
	self.memUpdateTimer = self.config.memUpdate
	self.cpuUpdateTimer = self.config.cpuUpdate
	self:SetScript("OnUpdate", self.onUpdate)
end)


listFrame:SetScript("OnHide", function(self)
	if self.save then
		C_AddOns.SaveAddOns()
	else
		C_AddOns.ResetAddOns()
	end
	self.save = nil
end)


function listFrame:onShow()
	UpdateAddOnMemoryUsage()
	self:updatePerformance()
	self:updateList()
	self:updateReloadButton()

	self.searchBox:SetText("")
	if self.config.autofocusSearch then
		self.searchBox:SetFocus()
	end
end


local function getColorPercent(percent)
	local color = (100 - math.min(percent, 100)) * 2.55
	return ("|cffff%.2x%.2x%.2f%%|r"):format(color, color, percent)
end


function listFrame:getAddonMetric(name, metric)
	if not C_AddOnProfiler.IsEnabled() then return end

	local addonVal = C_AddOnProfiler.GetAddOnMetric(name, metric)
	local overallVal = self.metrics[metric] or C_AddOnProfiler.GetOverallMetric(metric)
	local relativeTotal = overallVal + addonVal or 0

	if relativeTotal <= 0 then return end

	return addonVal / relativeTotal * 100
end


function listFrame:getAddonMetricPercent(name, metric)
	return getColorPercent(self:getAddonMetric(name, metric) or 0)
end


function listFrame:updateOverallMetric(fontString, metric)
	local appVal = C_AddOnProfiler.GetApplicationMetric(metric) or 0
	if appVal <= 0 then
		fontString:SetText("--")
		return
	end

	local overallVal = C_AddOnProfiler.GetOverallMetric(metric)
	self.metrics[metric] = appVal - overallVal
	fontString:SetText(getColorPercent(overallVal / appVal * 100))
end


function listFrame:isProfilerEnabled()
	return self.config.cpuUpdate and C_AddOnProfiler.GetApplicationMetric and C_AddOnProfiler.IsEnabled()
end


function listFrame:updatePerformance()
	local enabled = self:isProfilerEnabled()
	self.performance:SetShown(enabled)
	if not enabled then return end

	self:updateOverallMetric(self.currentCPU.bottomStr, Enum.AddOnProfilerMetric.RecentAverageTime)
	self:updateOverallMetric(self.averageCPU.bottomStr, Enum.AddOnProfilerMetric.SessionAverageTime)
	self:updateOverallMetric(self.peakCPU.bottomStr, Enum.AddOnProfilerMetric.PeakTime)
	self:updateOverallMetric(self.encounterCPU.bottomStr, Enum.AddOnProfilerMetric.EncounterAverageTime)
end


function listFrame:onUpdate(elapsed)
	self.elapsed = elapsed
	if self.config.cpuUpdate then
		self.cpuUpdateTimer = self.cpuUpdateTimer - elapsed
		if self.cpuUpdateTimer <= 0 then
			self.cpuUpdateTimer = self.config.cpuUpdate
			self:updatePerformance()
			self:updateTooltip()

			if self.config.cpuSortBy then
				self:sort()
			else
				for i, f in ipairs(self.view:GetFrames()) do
					if f.loaded then self:updateAddonMetrics(f) end
				end
			end
		end
	end

	if self.config.memUpdate then
		self.memUpdateTimer = self.memUpdateTimer - elapsed
		if self.memUpdateTimer <= 0 then
			self.memUpdateTimer = self.config.memUpdate
			UpdateAddOnMemoryUsage()
			self:updateTooltip()
		end
	end
end


function listFrame:setAddonCharacter()
	self.addonCharacter = self.config.usePlayer and self.charName or nil
end


function listFrame:showResetBtn()
	for k in next, self.filters do
		if not self.filters[k] then
			self.resetBtn:Show()
			return
		end
	end
	for k in next, self.categoriesFilter do
		if not self.categoriesFilter[k] then
			self.resetBtn:Show()
			return
		end
	end
	self.resetBtn:Hide()
end


function listFrame:resetFilters()
	for k in next, self.filters do
		self.filters[k] = true
	end
	for k in next, self.categoriesFilter do
		self.categoriesFilter[k] = true
	end
	self:updateFilters()
end


do
	local icon = " "..CreateAtlasMarkup(C_Texture.GetAtlasInfo("dropdown-hover-arrow") and "dropdown-hover-arrow" or "auctionhouse-ui-sortarrow", 10, 10)
	local function getOrderIcon(metric)
		return listFrame.config.cpuSortBy == metric and icon or ""
	end

	function listFrame:updateCpuButtons()
		self.currentCPU.topStr:SetFormattedText("%s %s%s", self.currentIcon, L["Current CPU"], getOrderIcon("current"))
		self.averageCPU.topStr:SetFormattedText("%s %s%s", self.averageIcon, L["Average CPU"], getOrderIcon("average"))
		self.peakCPU.topStr:SetFormattedText("%s %s%s", self.peakIcon, L["Peak CPU"], getOrderIcon("peak"))
		self.encounterCPU.topStr:SetFormattedText("%s %s%s", self.encounterIcon, L["Encounter CPU"], getOrderIcon("encounter"))
		self:sort()
	end
end


function listFrame:sort()
	local metric, copy
	if self.config.cpuSortBy then
		if self.config.cpuSortBy == "current" then
			metric = Enum.AddOnProfilerMetric.RecentAverageTime
		elseif self.config.cpuSortBy == "average" then
			metric = Enum.AddOnProfilerMetric.SessionAverageTime
		elseif self.config.cpuSortBy == "peak" then
			metric = Enum.AddOnProfilerMetric.PeakTime
		elseif self.config.cpuSortBy == "encounter" then
			metric = Enum.AddOnProfilerMetric.EncounterAverageTime
		end
		copy = {}
		for i = 1, #self.sorted do copy[i] = self.sorted[i] end
	end

	sort(self.sorted, function(a, b)
		if a == b then return false end
		local nameA = self.nameByIndex[a]
		local nameB = self.nameByIndex[b]

		if self.config.cpuSortBy then
			local loadedA = C_AddOns.IsAddOnLoaded(a)
			local loadedB = C_AddOns.IsAddOnLoaded(b)

			if loadedA and loadedB then
				local ma = self:getAddonMetric(nameA, metric)
				local mb = self:getAddonMetric(nameB, metric)

				if ma and mb then
					if ma > mb then return true
					elseif ma < mb then return false end
				elseif ma then return true
				elseif mb then return false end

			elseif loadedA then return true
			elseif loadedB then return false end
		end

		if self.config.sortBy == "title" then
			local titleA = self.titleByIndex[a]
			local titleB = self.titleByIndex[b]
			if titleA < titleB then return true
			elseif titleA > titleB then return false end
		end

		nameA = nameA:lower()
		nameB = nameB:lower()

		if nameA < nameB then return true
		elseif nameA > nameB then return false end

		return a < b
	end)

	if self.config.cpuSortBy then
		local continue = true
		for i = 1, #self.sorted do
			if self.sorted[i] ~= copy[i] then
				continue = false
				break
			end
		end
		if continue then
			for i, f in ipairs(self.view:GetFrames()) do
				if f.loaded then
					self:updateAddonMetrics(f)
				else
					break
				end
			end
			return
		end
	end
	self:updateFilters()
end


function listFrame:setCollapsed(index, collapsed)
	self.depCollapsed[self.nameByIndex[index]] = collapsed or nil
end


function listFrame:isCollapsed(index)
	return self.depCollapsed[self.nameByIndex[index]]
end


function listFrame:setListGroup()
	if self.config.cpuSortBy then
		wipe(self.hasParentByIndex)
		wipe(self.childByPIndex)
		self:updateData()
		return
	end

	if self.config.listGroup == "dep" then
		self:setChildByDeps()
	elseif self.config.listGroup == "treeDep" then
		self:setChildByTreeDeps()
	elseif self.config.listGroup == "group" then
		self:setChildByGroup()
	else
		wipe(self.hasParentByIndex)
		wipe(self.childByPIndex)
	end
	self:updateData()
end


function listFrame:setChildByDeps()
	wipe(self.hasParentByIndex)
	wipe(self.childByPIndex)

	local function addMaxParents(index, pList)
		if self.circular[index] then return end
		local deps = {C_AddOns.GetAddOnDependencies(index)}
		if #deps > 0 then
			for i = 1, #deps do
				local depIndex = self.indexByName[deps[i]]
				if depIndex then addMaxParents(depIndex, pList) end
			end
		else
			pList[index] = true
		end
	end

	for i = 1, #self.filtred do
		local index = self.filtred[i]
		local deps = {C_AddOns.GetAddOnDependencies(index)}
		for j = 1, #deps do
			local depIndex = self.indexByName[deps[j]]
			if depIndex then
				local pList = {}
				addMaxParents(depIndex, pList)
				if next(pList) then
					self.hasParentByIndex[index] = true
					for pIndex in next, pList do
						self.childByPIndex[pIndex] = self.childByPIndex[pIndex] or {}
						tInsertUnique(self.childByPIndex[pIndex], index)
					end
				end
			end
		end
	end
end


function listFrame:setChildByTreeDeps()
	wipe(self.hasParentByIndex)
	wipe(self.childByPIndex)

	local function checkDeps(dIndex, pIndex, list)
		if self.circular[pIndex] then return false end
		for i = 1, #list do
			local index = self.indexByName[list[i]]
			if index then
				local deps = {C_AddOns.GetAddOnDependencies(list[i])}
				for j = 1, #deps do
					local depIndex = self.indexByName[deps[j]]
					if depIndex then
						if dIndex == depIndex or not checkDeps(dIndex, index, deps) then
							return false
						end
					end
				end
			end
		end
		return true
	end

	for i = 1, #self.filtred do
		local index = self.filtred[i]
		local deps = {C_AddOns.GetAddOnDependencies(index)}
		for j = 1, #deps do
			local depIndex = self.indexByName[deps[j]]
			if depIndex then
				if checkDeps(depIndex, index, deps) then
					self.hasParentByIndex[index] = true
					self.childByPIndex[depIndex] = self.childByPIndex[depIndex] or {}
					tinsert(self.childByPIndex[depIndex], index)
				end
			end
		end
	end
end


function listFrame:setChildByGroup()
	wipe(self.hasParentByIndex)
	wipe(self.childByPIndex)

	for i = 1, #self.filtred do
		local index = self.filtred[i]
		local name = C_AddOns.GetAddOnInfo(index)
		local group = C_AddOns.GetAddOnMetadata(index, "Group")

		if group and name ~= group then
			local pIndex = self.indexByName[group]
			if pIndex then
				self.hasParentByIndex[index] = true
				self.childByPIndex[pIndex] = self.childByPIndex[pIndex] or {}
				tinsert(self.childByPIndex[pIndex], index)
			end
		end
	end
end


function listFrame:enableAddon(name, enabled)
	if self.locked[name] then return end
	if enabled then
		C_AddOns.EnableAddOn(name, listFrame.addonCharacter)
	else
		C_AddOns.DisableAddOn(name, listFrame.addonCharacter)
	end
end


function listFrame:enableAddonDependencies(name, enabled, context)
	context = context or {}
	if context[name] then return end
	context[name] = true
	for _, aName in ipairs({C_AddOns.GetAddOnDependencies(name)}) do
		if self.indexByName[aName] then
			self:enableAddon(aName, enabled)
			self:enableAddonDependencies(aName, enabled, context)
		end
	end
end


function listFrame:enableAddonChildren(name, enabled)
	local childs = self.childByPIndex[self.indexByName[name]]
	if not childs then return end
	for _, index in ipairs(childs) do
		local aName = self.nameByIndex[index]
		self:enableAddon(aName, enabled)
		self:enableAddonChildren(aName, enabled)
	end
end


function listFrame:getAddonDepsString(name, reason)
	local deps = {C_AddOns.GetAddOnDependencies(name)}
	local depsString = ""
	for i = 1, #deps do
		local dName = deps[i]
		local loadable, reason = C_AddOns.IsAddOnLoadable(dName, self.addonCharacter)
		local color = HIGHLIGHT_FONT_COLOR
		if reason == "MISSING" then
			color = RED_FONT_COLOR
		elseif C_AddOns.GetAddOnEnableState(dName, self.addonCharacter) > Enum.AddOnEnableState.None then
			color = GREEN_FONT_COLOR
		end
		if i == 1 then
			depsString = ADDON_DEPENDENCIES..color:WrapTextInColorCode(dName)
		else
			depsString = depsString..", "..color:WrapTextInColorCode(dName)
		end
	end
	return depsString
end


function listFrame:formatMemory(mem)
	if mem >= 1024 then
		return ("%.2f MB"):format(mem / 1024)
	else
		return ("%.2f KB"):format(mem)
	end
end


do
	local function addDoubleLine(left, right, wrap)
		GameTooltip:AddDoubleLine(left, right, 1, .78, 0, 1, 1, 1, wrap or false)
	end


	local function addLineNotEmpty(text, val)
		if val and val ~= "" then
			GameTooltip:AddLine(("%s: |Cffffffff%s|r"):format(text, val))
		end
	end


	function listFrame:updateTooltip()
		if not self.tooltipIndex then return end
		local name, title, notes, _, reason, security = C_AddOns.GetAddOnInfo(self.tooltipIndex)

		GameTooltip:ClearLines()
		if security == BANNED then
			GameTooltip:SetText(ADDON_BANNED_TOOLTIP)
		elseif reason == "MISSING" then
			GameTooltip:AddLine(name)
			GameTooltip:AddLine(_G["ADDON_"..reason], 1,0,0)
		else
			local version = C_AddOns.GetAddOnMetadata(name, "Version")
			addDoubleLine(title, version)
			GameTooltip:AddLine(name, .7, .7, .7)
			addLineNotEmpty(L["Author"], C_AddOns.GetAddOnMetadata(name, "Author"))

			local loaded = C_AddOns.IsAddOnLoaded(name)
			if loaded then
				if self:isProfilerEnabled() then
					addLineNotEmpty(L["Current CPU"], self:getAddonMetricPercent(name, Enum.AddOnProfilerMetric.RecentAverageTime))
					addLineNotEmpty(L["Average CPU"], self:getAddonMetricPercent(name, Enum.AddOnProfilerMetric.SessionAverageTime))
					addLineNotEmpty(L["Peak CPU"], self:getAddonMetricPercent(name, Enum.AddOnProfilerMetric.PeakTime))
					addLineNotEmpty(L["Encounter CPU"], self:getAddonMetricPercent(name, Enum.AddOnProfilerMetric.EncounterAverageTime))
					addLineNotEmpty(L["Ticks over"].." 5ms", C_AddOnProfiler.GetAddOnMetric(name, Enum.AddOnProfilerMetric.CountTimeOver5Ms))
					addLineNotEmpty(L["Ticks over"].." 10ms", C_AddOnProfiler.GetAddOnMetric(name, Enum.AddOnProfilerMetric.CountTimeOver10Ms))
					addLineNotEmpty(L["Ticks over"].." 50ms", C_AddOnProfiler.GetAddOnMetric(name, Enum.AddOnProfilerMetric.CountTimeOver50Ms))
					addLineNotEmpty(L["Ticks over"].." 100ms", C_AddOnProfiler.GetAddOnMetric(name, Enum.AddOnProfilerMetric.CountTimeOver100Ms))
					addLineNotEmpty(L["Ticks over"].." 500ms", C_AddOnProfiler.GetAddOnMetric(name, Enum.AddOnProfilerMetric.CountTimeOver500Ms))
				end

				if security ~= SECURE_PROTECTED and security ~= SECURE then
					addLineNotEmpty(L["Memory Usage"], self:formatMemory(GetAddOnMemoryUsage(name)))
				end
			end

			GameTooltip:AddLine(self:getAddonDepsString(name), nil, nil, nil, true)
			addLineNotEmpty(CATEGORIES, C_AddOns.GetAddOnMetadata(name, "Category"))

			if notes then
				GameTooltip:AddLine(" ")
				GameTooltip:AddLine(notes, 1, 1, 1, true)
			end

			GameTooltip:AddLine(" ");
			if self.childByPIndex[self.tooltipIndex] then
				GameTooltip:AddLine(LEFT_MOUSE_ICON..L["Left+Shift with children"])
			end
			GameTooltip:AddLine(LEFT_MOUSE_ICON..L["Left+Alt to lock/unclock"])
			GameTooltip:AddLine(RIGHT_MOUSE_ICON..L["Right For more options"])
		end

		GameTooltip:Show()
	end
end


function listFrame:hasAnyChanges()
	for i = 1, C_AddOns.GetNumAddOns() do
		local enabled = C_AddOns.GetAddOnEnableState(i, self.charName) > Enum.AddOnEnableState.None
		local loadable, reason = C_AddOns.IsAddOnLoadable(i, self.charName)

		if (enabled ~= self.startStatus[i] and reason ~= "DEP_DISABLED"
			or reason ~= "INTERFACE_VERSION" and self.outOfDateIndexes[i]
			or reason == "INTERFACE_VERSION" and not self.outOfDateIndexes[i])
		and (enabled or C_AddOns.IsAddOnLoaded(i)) then
			return true
		end
	end
	return false
end


function listFrame:updateReloadButton()
	if self:hasAnyChanges() then
		self.okay:SetText(RELOADUI)
		self.shouldReload = true
	else
		self.okay:SetText(OKAY)
		self.shouldReload = nil
	end
end


function listFrame:updateAddonMetrics(f)
	local name = f.name
	local str = ""
	if self:isProfilerEnabled() then
		str = self.currentStr:format(self:getAddonMetricPercent(name, Enum.AddOnProfilerMetric.RecentAverageTime))
		if self.config.cpuSortBy == "average" then
			str = self.averageStr:format(str, self:getAddonMetricPercent(name, Enum.AddOnProfilerMetric.SessionAverageTime))
		elseif self.config.cpuSortBy == "peak" then
			str = self.peakStr:format(str, self:getAddonMetricPercent(name, Enum.AddOnProfilerMetric.PeakTime))
		elseif self.config.cpuSortBy == "encounter" then
			local val = self:getAddonMetricPercent(name, Enum.AddOnProfilerMetric.EncounterAverageTime)
			str = self.encounterStr:format(str, val)
		end
	end
	f.status:SetText(str)
end


function listFrame:isAddonLoadOnDemand(index)
	local deps = {C_AddOns.GetAddOnDependencies(index)}
	for i = 1, #deps do
		if not C_AddOns.IsAddOnLoaded(deps[i]) then return false end
	end
	return true
end


function listFrame:normalInit(f, node)
	local index = node:GetData().index
	local name, title, notes, _,_, security, updateAvailable = C_AddOns.GetAddOnInfo(index)
	local iconTexture = C_AddOns.GetAddOnMetadata(index, "IconTexture")
	local iconAtlas = C_AddOns.GetAddOnMetadata(index, "IconAtlas")
	f.name = name

	if self.config.showIcon then
		if not iconTexture and not iconAtlas then
			iconTexture = self.config.showNoIcon and [[Interface\ICONS\INV_Misc_QuestionMark]]
		end

		if iconTexture then
			f.icon:SetTexture(iconTexture)
		elseif iconAtlas then
			f.icon:SetAtlas(iconAtlas)
		else
			f.icon:SetTexture()
		end
		f.icon:Show()
	else
		f.icon:Hide()
	end

	local loadable, reason = C_AddOns.IsAddOnLoadable(index, self.addonCharacter)
	local checkboxState = C_AddOns.GetAddOnEnableState(index, self.addonCharacter)
	local charCheckboxState = C_AddOns.GetAddOnEnableState(index, self.charName)
	local enabled = checkboxState > Enum.AddOnEnableState.None
	local loaded = C_AddOns.IsAddOnLoaded(index)
	f.loaded = loaded
	--fprint(name, loadable, reason, checkboxState)

	local titleText = self.config.showNameInsteadOfTitle and name or title
	if loadable or enabled and (reason == "DEP_DEMAND_LOADED" or reason == "DEMAND_LOADED") then
		f.title:SetTextColor(1, .78, 0)
	elseif enabled and reason ~= "DEP_DISABLED" then
		f.title:SetTextColor(1, .1, .1)
		titleText = titleText:gsub("|[Cc]%x%x%x%x%x%x%x%x", ""):gsub("|[Rr]", "")
	else
		f.title:SetTextColor(.5, .5, .5)
		titleText = titleText:gsub("|[Cc]%x%x%x%x%x%x%x%x", ""):gsub("|[Rr]", "")
	end

	if self.config.showVersion then
		local version = C_AddOns.GetAddOnMetadata(index, "Version")
		if version then
			titleText = ("%s |Cff606060(%s)|r"):format(titleText, version)
		end
	end
	f.title:SetText(titleText)

	if self.locked[name] then
		f.lock:Show()
		f.check:Hide()
	else
		f.lock:Hide()
		f.check:Show()
		f.check:SetChecked(enabled)
		if enabled then
			if checkboxState ~= Enum.AddOnEnableState.All then
				if charCheckboxState > Enum.AddOnEnableState.None then
					f.check.CheckedTexture:SetVertexColor(0,1,0)
					f.check.CheckedTexture:SetDesaturated(false)
				else
					f.check.CheckedTexture:SetVertexColor(1,1,1)
					f.check.CheckedTexture:SetDesaturated(true)
				end
			else
				f.check.CheckedTexture:SetVertexColor(1,1,1)
				f.check.CheckedTexture:SetDesaturated(false)
			end
		end
	end

	if loaded then
		self:updateAddonMetrics(f)
	else
		f.status:SetText(reason and _G["ADDON_"..reason] or "")
	end

	if not loaded and reason == "DEMAND_LOADED" then
		local isAddonLoadOnDemand = self:isAddonLoadOnDemand(index)
		f.loadButton:SetShown(isAddonLoadOnDemand)
		f.status:SetShown(not isAddonLoadOnDemand)
	else
		f.loadButton:Hide()
		f.status:Show()

		if (charCheckboxState > Enum.AddOnEnableState.None ~= self.startStatus[index] and reason ~= "DEP_DISABLED"
			or reason ~= "INTERFACE_VERSION" and self.outOfDateIndexes[index]
			or reason == "INTERFACE_VERSION" and not self.outOfDateIndexes[index])
		and (charCheckboxState > Enum.AddOnEnableState.None or loaded) then
			f.loaded = false
			f.status:SetText(RED_FONT_COLOR:WrapTextInColorCode(REQUIRES_RELOAD))
		end
	end
end


function listFrame:parentInit(f, node)
	self:normalInit(f, node)
	f.collapseExpand.node = node
	f.collapseExpand:updateState()
end


function listFrame:updateList()
	self.doNotHideMenu = true
	self.scrollBox:SetDataProvider(self.dataProvider, ScrollBoxConstants.RetainScrollPosition)
	self.doNotHideMenu = nil
end


do
	local function addChilds(self, pNode, pIndex)
		for i = 1, #self.childByPIndex[pIndex] do
			local index = self.childByPIndex[pIndex][i]
				local node = pNode:Insert({index = index, isParent = self.childByPIndex[index] and true})
				if self.childByPIndex[index] then
					node:SetCollapsed(self:isCollapsed(index))
					addChilds(self, node, index)
				end
		end
	end


	function listFrame:updateData()
		self.dataProvider = CreateTreeDataProvider()

		for i = 1, #self.filtred do
			local index = self.filtred[i]
			if not self.hasParentByIndex[index] then
				local node = self.dataProvider:Insert({index = index, isParent = self.childByPIndex[index] and true})
				if self.childByPIndex[index] then
					node:SetCollapsed(self:isCollapsed(index))
					addChilds(self, node, index)
				end
			end
		end

		self:updateList()
	end
end


function listFrame:updateFilters()
	local text = self.searchBox:GetText():trim():lower()
	local searchBy = self.config.searchBy
	wipe(self.indexByName)
	wipe(self.filtred)

	for i = 1, #self.sorted do
		local index = self.sorted[i]
		local name = self.nameByIndex[index]
		local title = self.titleByIndex[index]
		local author = C_AddOns.GetAddOnMetadata(index, "Author")
		local category = C_AddOns.GetAddOnMetadata(index, "Category")
		local loadable, reason = C_AddOns.IsAddOnLoadable(index, self.addonCharacter)
		local enabled = loadable or reason == "DEMAND_LOADED"

		if (enabled and self.filters.enabled or not enabled and self.filters.disabled)
		and (#text == 0
			or searchBy.name and name:lower():find(text, 1, true)
			or searchBy.title and title:find(text, 1, true)
			or searchBy.author and author and author:lower():find(text, 1, true)
			or searchBy.category and category and category:lower():find(text, 1, true))
		and self.categoriesFilter[category or "rest"]
		then
			self.indexByName[name] = index
			self.filtred[#self.filtred + 1] = index
		end
	end

	self:showResetBtn()
	self:setListGroup()
end