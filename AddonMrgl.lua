local addon, ns = ...
local L = ns.L
local listFrame = AddonMgrAddonList
local C_AddOns = C_AddOns

listFrame.isMainline = WOW_PROJECT_MAINLINE == WOW_PROJECT_ID
listFrame.LEFT_MOUSE_ICON = C_Texture.GetAtlasInfo("newplayertutorial-icon-mouse-leftbutton") and "|A:newplayertutorial-icon-mouse-leftbutton:0:0|a " or ""
listFrame.RIGHT_MOUSE_ICON = C_Texture.GetAtlasInfo("newplayertutorial-icon-mouse-rightbutton") and "|A:newplayertutorial-icon-mouse-rightbutton:0:0|a " or ""
listFrame.MIDDLE_MOUSE_ICON = C_Texture.GetAtlasInfo("newplayertutorial-icon-mouse-middlebutton") and "|A:newplayertutorial-icon-mouse-middlebutton:0:0|a " or ""
local BANNED = "BANNED"
local SECURE_PROTECTED = "SECURE_PROTECTED"
local SECURE = "SECURE"


listFrame:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)
listFrame:RegisterEvent("ADDON_LOADED")


function listFrame:ADDON_LOADED(addonName)
	if addonName ~= addon then return end
	AddonMgrDB = AddonMgrDB or {}
	self.db = AddonMgrDB
	self.db.config = self.db.config or {}
	self.db.profiles = self.db.profiles or {}
	self.db.charProfiles = self.db.charProfiles or {}
	self.db.depCollapsed = self.db.depCollapsed or {}
	self.db.locked = self.db.locked or {}
	self.db.omb = self.db.omb or {}
	self.db.autoLoadProfiles = self.db.autoLoadProfiles or {}

	self.config = self.db.config
	self.config.listGroup = self.config.listGroup or "dep"
	self.config.sortBy = self.config.sortBy or "name"
	if self.config.memUpdate == nil then self.config.memUpdate = 30 end
	if self.config.cpuUpdate == nil then self.config.cpuUpdate = 1 end
	if self.config.cpuAccuracy == nil then self.config.cpuAccuracy = 2 end
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
	self.indexByName = {}
	self.nameByIndex = {}

	for i = 1, C_AddOns.GetNumAddOns() do
		local name = C_AddOns.GetAddOnInfo(i)
		self.indexByName[name] = i
		self.nameByIndex[i] = name
	end

	for name in next, self.depCollapsed do
		if not self.indexByName[name] then
			self.depCollapsed[name] = nil
		end
	end

	function self:ADDON_LOADED(addonName)
		if self.dataProvider and self.indexByName[addonName] and self:IsShown() then
			UpdateAddOnMemoryUsage()
			self:sort()
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
end


listFrame:SetScript("OnShow", function(self)
	self:SetScript("OnShow", self.onShow)
	self:SetFrameLevel(2000)
	self:RegisterForDrag("LeftButton")
	self:SetTitle(C_AddOns.GetAddOnMetadata(addon, "Title"))
	tinsert(UISpecialFrames, self:GetName())

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

	if C_Texture.GetAtlasInfo("questlog-icon-setting") then
		self.settingsBtn.icon:SetAtlas("questlog-icon-setting", true)
		self.settingsBtn.highlight = self.settingsBtn:CreateTexture(nil, "HIGHLIGHT")
		self.settingsBtn.highlight:SetPoint("CENTER")
		self.settingsBtn.highlight:SetAtlas("questlog-icon-setting", true)
		self.settingsBtn.highlight:SetBlendMode("ADD")
		self.settingsBtn.highlight:SetAlpha(.4)
	else
		self.closeButton:SetPoint("TOPRIGHT", 4, 4)

		self.settingsBtn.icon:SetTexture([[Interface\Worldmap\Gear_64]])
		self.settingsBtn.icon:SetTexCoord(0, .5, 0, .5)
		self.settingsBtn.icon:SetVertexColor(.7, .7, .7)
		self.settingsBtn.icon:SetDesaturated(true)
		self.settingsBtn.icon:SetSize(20, 20)
		self.settingsBtn:SetAlpha(.8)
		self.settingsBtn:SetScript("OnEnter", function(self)
			self:SetAlpha(1)
			self.icon:SetVertexColor(.9, .9, .9)
		end)
		self.settingsBtn:SetScript("OnLeave", function(self)
			self:SetAlpha(.8)
			self.icon:SetVertexColor(.7, .7, .7)
		end)

		self.inset:SetPoint("BOTTOMRIGHT", -6, 28)
		self.enableAll:SetPoint("BOTTOMLEFT", 8, 6)
		self.cancel:SetPoint("BOTTOMRIGHT", -16, 6)
		self.resize:SetPoint("BOTTOMRIGHT", -4, 6)
	end

	-- SET SIZE & POS
	local minWidth = 550
	local minHeight = 400
	local maxWidth = UIParent:GetWidth() - 100
	local maxHeight = UIParent:GetHeight() - 100
	local width = Clamp(self.config.width or 600, minWidth, maxWidth)
	local height = Clamp(self.config.height or maxHeight * .75, minHeight, maxHeight)
	self:SetSize(width, height)
	if self.config.posX and self.config.posY then
		local scale = self:GetEffectiveScale()
		self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", self.config.posX / scale, self.config.posY / scale)
	end

	-- MOVING
	self:SetScript("OnDragStart", self.StartMoving)
	self:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local x, y = self:GetCenter()
		local scale = self:GetEffectiveScale()
		self.config.posX = x * scale
		self.config.posY = y * scale
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
	self.sorted = {}
	self.titleByIndex = {}
	self.catigoriesList = {}
	self.categoriesFilter = {}
	local function checkCirc(i)
		if context[i] then self.circular[i] = true return end
		context[i] = true
		local deps = {C_AddOns.GetAddOnDependencies(i)}
		for i = 1, #deps do
			local di = self.indexByName[deps[i]]
			if di ~= nil then checkCirc(di) end
		end
		context[i] = nil
	end
	for i = 1, C_AddOns.GetNumAddOns() do
		local name, title = C_AddOns.GetAddOnInfo(i)
		self.sorted[i] = i
		self.titleByIndex[i] = title:gsub("|[Cc]%x%x%x%x%x%x%x%x", ""):gsub("|[Rr]", ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):trim():lower()
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
	self.charSelect = self.isMainline and lsfdd:CreateModernButton(self) or lsfdd:CreateButton(self)
	self.charSelect:SetPoint("TOPLEFT", 12, -30)
	self.charSelect:ddSetSelectedText(self.config.usePlayer and self.charName or ALL)

	self.charSelect:ddSetInitFunc(function(dd)
		local info = {}

		local func = function(btn)
			self.config.usePlayer = btn.value
			self:setAddonCharacter()
			self:updateFilters()
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
	self.filterBtn = lsfdd:CreateStretchButton(self, 90, 26)
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
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	end

	local cpuBtnOnEnter = function(btn)
		if btn.ms then
			GameTooltip:SetOwner(self.performance, "ANCHOR_NONE")
			GameTooltip:SetPoint("RIGHT", self.performance, "LEFT", -2, 3)
			GameTooltip:SetText(L["%.2f ms"]:format(btn.ms))
			GameTooltip:Show()
		end
	end

	self.currentCPU.value = "current"
	self.currentCPU:SetScript("OnClick", cpuBtnClick)
	self.currentCPU:SetScript("OnEnter", cpuBtnOnEnter)
	self.currentCPU:SetScript("OnLeave", GameTooltip_Hide)
	self.averageCPU.value = "average"
	self.averageCPU:SetScript("OnClick", cpuBtnClick)
	self.averageCPU:SetScript("OnEnter", cpuBtnOnEnter)
	self.averageCPU:SetScript("OnLeave", GameTooltip_Hide)
	self.peakCPU.value = "peak"
	self.peakCPU:SetScript("OnClick", cpuBtnClick)
	self.peakCPU:SetScript("OnEnter", cpuBtnOnEnter)
	self.peakCPU:SetScript("OnLeave", GameTooltip_Hide)
	self.encounterCPU.value = "encounter"
	self.encounterCPU:SetScript("OnClick", cpuBtnClick)
	self.encounterCPU:SetScript("OnEnter", cpuBtnOnEnter)
	self.encounterCPU:SetScript("OnLeave", GameTooltip_Hide)

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
		parent:setAddonsEnabled(true)
		parent:updateList()
		parent:updateReloadButton()
	end)

	self.disableAll:SetScript("OnClick", function(btn)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		local parent = btn:GetParent()
		parent:setAddonsEnabled(false)
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

	-- INIT
	self:setCpuAccuracyStr()
	self:updatePerformance()
	self:setAddonCharacter()
	self:updateCpuButtons()
	UpdateAddOnMemoryUsage()
	self.uTimer = .1
	self.syncCounter = 0
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
	self:updateReloadButton()
	if self.config.cpuSortBy then
		self:sort(true)
	else
		self:updateList()
	end
	self.uTimer = .1
	self.syncCounter = 0
	self.searchBox:SetText("")
	if self.config.autofocusSearch then
		self.searchBox:SetFocus()
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


function listFrame:sort(force)
	local cpuSortBy = self.config.cpuSortBy
	local sortByTitle = self.config.sortBy == "title"
	local metric, copy
	if cpuSortBy ~= nil then
		if cpuSortBy == "current" then
			metric = self.enumRecentAverageTime
		elseif cpuSortBy == "average" then
			metric = self.enumSessionAverageTime
		elseif cpuSortBy == "peak" then
			metric = self.enumPeakTime
		elseif cpuSortBy == "encounter" then
			metric = self.enumEncounterAverageTime
		end
		if not force then
			copy = {}
			for i = 1, #self.sorted do copy[i] = self.sorted[i] end
		end
	end

	sort(self.sorted, function(a, b)
		if a == b then return false end
		local nameA = self.nameByIndex[a]
		local nameB = self.nameByIndex[b]

		if cpuSortBy ~= nil then
			local loadedA = C_AddOns.IsAddOnLoaded(a)
			local loadedB = C_AddOns.IsAddOnLoaded(b)

			if loadedA and loadedB then
				local ma = self:getAddonMetric(nameA, metric)
				local mb = self:getAddonMetric(nameB, metric)

				if ma > mb then return true
				elseif ma < mb then return false end

			elseif loadedA then return true
			elseif loadedB then return false end
		end

		if sortByTitle then
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

	if cpuSortBy and not force then
		for i = 1, #self.sorted do
			if self.sorted[i] ~= copy[i] then
				self:updateFilters()
				return
			end
		end
		for i, f in ipairs(self.view:GetFrames()) do
			if f.loaded then self:updateAddonMetrics(f) end
		end
		return
	end
	self:updateFilters()
end


function listFrame:setCollapsed(index, collapsed)
	self.depCollapsed[self.nameByIndex[index]] = collapsed or nil
end


function listFrame:isCollapsed(index)
	return self.depCollapsed[self.nameByIndex[index]] and self.notSearched
end


function listFrame:setListGroup()
	wipe(self.hasParentByIndex)
	wipe(self.childByPIndex)

	if not self.config.cpuSortBy and self.config.listGroup ~= "none" then
		if self.config.listGroup == "dep" then
			self:setChildByDeps()
		elseif self.config.listGroup == "treeDep" then
			self:setChildByTreeDeps()
		elseif self.config.listGroup == "group" then
			self:setChildByGroup()
		end
	end

	self:updateData()
end


function listFrame:setChildByDeps()
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
						local childs = self.childByPIndex[pIndex]
						if childs then tInsertUnique(childs, index)
						else self.childByPIndex[pIndex] = {index} end
					end
				end
			end
		end
	end
end


function listFrame:setChildByTreeDeps()
	local cache = {}
	local function checkDeps(dIndex, pIndex)
		if self.circular[pIndex] then return true end
		local cacheKey = dIndex.."|"..pIndex
		if cache[cacheKey] ~= nil then
			return cache[cacheKey]
		end
		local deps = {C_AddOns.GetAddOnDependencies(pIndex)}
		for i = 1, #deps do
			local index = self.indexByName[deps[i]]
			if index and (dIndex == index or checkDeps(dIndex, index)) then
				cache[cacheKey] = true
				return true
			end
		end
		cache[cacheKey] = false
		return false
	end

	for i = 1, #self.filtred do
		local index = self.filtred[i]
		local deps = {C_AddOns.GetAddOnDependencies(index)}
		for j = 1, #deps do
			local depIndex = self.indexByName[deps[j]]
			if depIndex then
				local addChild = true
				for n = 1, #deps do
					if n ~= j then
						local pIndex = self.indexByName[deps[n]]
						if pIndex and checkDeps(depIndex, pIndex) then
							addChild = false
							break
						end
					end
				end
				if addChild then
					self.hasParentByIndex[index] = true
					local childs = self.childByPIndex[depIndex]
					if childs then childs[#childs + 1] = index
					else self.childByPIndex[depIndex] = {index} end
				end
			end
		end
	end
end


function listFrame:setChildByGroup()
	for i = 1, #self.filtred do
		local index = self.filtred[i]
		local name = self.nameByIndex[index]
		local group = C_AddOns.GetAddOnMetadata(index, "Group")

		if group and name ~= group then
			local pIndex = self.indexByName[group]
			if pIndex then
				self.hasParentByIndex[index] = true
				local childs = self.childByPIndex[pIndex]
				if childs then childs[#childs + 1] = index
				else self.childByPIndex[pIndex] = {index} end
			end
		end
	end
end


function listFrame:setAddonsEnabled(enabled, char)
	for i = 1, C_AddOns.GetNumAddOns() do
		self:enableAddon(self.nameByIndex[i], enabled, char)
	end
end


function listFrame:enableAddon(name, enabled, char)
	if self.locked[name] and not char then return end
	if enabled then
		C_AddOns.EnableAddOn(name, char or self.addonCharacter)
	else
		C_AddOns.DisableAddOn(name, char or self.addonCharacter)
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


function listFrame:getAddonDepsString(name)
	local deps = {C_AddOns.GetAddOnDependencies(name)}
	if #deps == 0 then return "" end
	for i = 1, #deps do
		local dName = deps[i]
		local loadable, reason = C_AddOns.IsAddOnLoadable(dName, self.charName)
		local color = HIGHLIGHT_FONT_COLOR
		if reason == "MISSING" then
			color = RED_FONT_COLOR
		elseif reason ~= "DISABLED" then
			color = GREEN_FONT_COLOR
		end
		deps[i] = color:WrapTextInColorCode(dName)
	end
	return ADDON_DEPENDENCIES..table.concat(deps, ", ")
end


function listFrame:formatMemory(mem)
	if mem >= 1024 then
		return L["%.2f MB"]:format(mem / 1024)
	else
		return L["%.2f KB"]:format(mem)
	end
end


do
	local function addDoubleLine(left, right, wrap)
		GameTooltip:AddDoubleLine(left, right, 1, .78, 0, 1, 1, 1, wrap or false)
	end

	local str = "%s: |Cffffffff%s|r"
	local msStr = "%s: |Cffffffff%s|r |cff808080("..L["%.2f ms"]..")|r"
	local function addLineNotEmpty(text, val, ms)
		if val and val ~= "" then
			if ms then
				GameTooltip:AddLine(msStr:format(text, val, ms))
			else
				GameTooltip:AddLine(str:format(text, val))
			end
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
					addLineNotEmpty(L["Current CPU"], self:getAddonMetricPercent(name, self.enumRecentAverageTime))
					addLineNotEmpty(L["Average CPU"], self:getAddonMetricPercent(name, self.enumSessionAverageTime))
					addLineNotEmpty(L["Peak CPU"], self:getAddonMetricPercent(name, self.enumPeakTime))
					addLineNotEmpty(L["Encounter CPU"], self:getAddonMetricPercent(name, self.enumEncounterAverageTime))
					addLineNotEmpty(L["Ticks over %sms"]:format(5), self:getAddonMetricCount(name, self.enumCountTimeOver5Ms))
					addLineNotEmpty(L["Ticks over %sms"]:format(10), self:getAddonMetricCount(name, self.enumCountTimeOver10Ms))
					addLineNotEmpty(L["Ticks over %sms"]:format(50), self:getAddonMetricCount(name, self.enumCountTimeOver50Ms))
					addLineNotEmpty(L["Ticks over %sms"]:format(100), self:getAddonMetricCount(name, self.enumCountTimeOver100Ms))
					addLineNotEmpty(L["Ticks over %sms"]:format(500), self:getAddonMetricCount(name, self.enumCountTimeOver500Ms))
				end

				if security ~= SECURE_PROTECTED and security ~= SECURE then
					addLineNotEmpty(L["Memory Usage"], self:formatMemory(GetAddOnMemoryUsage(name)))
				end
			end

			GameTooltip:AddLine(self:getAddonDepsString(name), nil, nil, nil, true)
			addLineNotEmpty(CATEGORIES, C_AddOns.GetAddOnMetadata(name, "Category"))
			addLineNotEmpty(L["Profiles with addon"], self:getProfilesWithAddon(name))
			--@do-not-package@
			addLineNotEmpty("Index", self.tooltipIndex)
			--@end-do-not-package@

			if notes then
				GameTooltip:AddLine(" ")
				GameTooltip:AddLine(notes, 1, 1, 1, true)
			end

			GameTooltip:AddLine(" ");
			if self.childByPIndex[self.tooltipIndex] then
				GameTooltip:AddLine(self.LEFT_MOUSE_ICON..L["Left+Shift with children"])
			end
			GameTooltip:AddLine(self.LEFT_MOUSE_ICON..L["Left+Alt to lock/unclock"])
			GameTooltip:AddLine(self.RIGHT_MOUSE_ICON..L["Right For more options"])
		end

		GameTooltip:Show()
	end
end


function listFrame:hasAnyChanges()
	for i = 1, C_AddOns.GetNumAddOns() do
		local loadable, reason = C_AddOns.IsAddOnLoadable(i, self.charName)
		if reason ~= "DEMAND_LOADED" and reason ~= "DEP_DEMAND_LOADED" and loadable ~= C_AddOns.IsAddOnLoaded(i) then
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


function listFrame:isAddonLoadOnDemand(index)
	local deps = {C_AddOns.GetAddOnDependencies(index)}
	for i = 1, #deps do
		if not C_AddOns.IsAddOnLoaded(deps[i]) then return false end
	end
	return true
end


function listFrame:normalInit(f, node)
	local index = node:GetData().index
	local name, title = C_AddOns.GetAddOnInfo(index)
	f.name = name

	if self.config.showIcon then
		local iconTexture = C_AddOns.GetAddOnMetadata(index, "IconTexture")
		local iconAtlas = C_AddOns.GetAddOnMetadata(index, "IconAtlas")

		if self.config.showNoIcon and not (iconTexture or iconAtlas) then
			iconTexture = [[Interface\ICONS\INV_Misc_QuestionMark]]
		end

		if iconTexture then
			f.icon:SetTexture(iconTexture)
		else
			f.icon:SetAtlas(iconAtlas)
		end

		f.icon:Show()
	else
		f.icon:Hide()
	end
	f.select:SetShown(self.selProfileAddons and self.selProfileAddons[name])

	local loadable, reason = C_AddOns.IsAddOnLoadable(index, self.charName)
	local checkboxState = C_AddOns.GetAddOnEnableState(index, self.addonCharacter)
	local enabled = checkboxState > Enum.AddOnEnableState.None
	local charEnabled = reason ~= "DISABLED"
	local loaded = C_AddOns.IsAddOnLoaded(index)
	f.loaded = loaded

	local titleText = self.config.showNameInsteadOfTitle and name or title
	if loadable or charEnabled and (reason == "DEMAND_LOADED" or reason == "DEP_DEMAND_LOADED") then
		f.title:SetTextColor(1, .78, 0)
	elseif charEnabled and reason ~= "DEP_DISABLED" then
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
		if enabled then
			f.lock:SetVertexColor(1, .78, 0)
		else
			f.lock:SetVertexColor(1, 1, 1)
		end
	else
		f.lock:Hide()
		f.check:Show()
		f.check:SetChecked(enabled)
		if enabled then
			if checkboxState ~= Enum.AddOnEnableState.All then
				if charEnabled then
					f.check.tooltip = L["Enabled for current character"]
					f.check.CheckedTexture:SetDesaturated(false)
					f.check.CheckedTexture:SetVertexColor(0,1,0)
				else
					f.check.tooltip = L["Enabled for some other characters"]
					f.check.CheckedTexture:SetDesaturated(true)
					f.check.CheckedTexture:SetVertexColor(1,1,1)
				end
			else
				f.check.tooltip = nil
				f.check.CheckedTexture:SetDesaturated(false)
				f.check.CheckedTexture:SetVertexColor(1,1,1)
			end
		end
	end

	if not loaded and reason == "DEMAND_LOADED" then
		if self:isAddonLoadOnDemand(index) then
			f.loadButton:Show()
			f.status:Hide()
		else
			f.loadButton:Hide()
			f.status:Show()
			f.status:SetText(_G["ADDON_"..reason])
		end
	else
		f.loadButton:Hide()
		f.status:Show()
		if loadable ~= loaded and reason ~= "DEMAND_LOADED" and reason ~= "DEP_DEMAND_LOADED" then
			f.loaded = false
			f.status:SetText(RED_FONT_COLOR:WrapTextInColorCode(REQUIRES_RELOAD))
		elseif loaded then
			self:updateAddonMetrics(f)
		else
			f.status:SetText(reason and _G["ADDON_"..reason] or "")
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
	local function addChilds(self, pNode, pList)
		for i = 1, #pList do
			local index = pList[i]
			local list = self.childByPIndex[index]
			local node = pNode:Insert({index = index, isParent = list and true})
			if list then
				node:SetCollapsed(self:isCollapsed(index))
				addChilds(self, node, list)
			end
		end
	end

	function listFrame:updateData()
		self.dataProvider = CreateTreeDataProvider()

		for i = 1, #self.filtred do
			local index = self.filtred[i]
			if not self.hasParentByIndex[index] then
				local list = self.childByPIndex[index]
				local node = self.dataProvider:Insert({index = index, isParent = list and true})
				if list then
					node:SetCollapsed(self:isCollapsed(index))
					addChilds(self, node, list)
				end
			end
		end

		self:updateList()
	end
end


function listFrame:updateFilters()
	local text = self.searchBox:GetText():trim():lower()
	local searchBy = self.config.searchBy
	local notSearched = #text == 0
	self.notSearched = notSearched
	wipe(self.indexByName)
	wipe(self.filtred)

	for i = 1, #self.sorted do
		local index = self.sorted[i]
		local name = self.nameByIndex[index]
		local author = searchBy.author and C_AddOns.GetAddOnMetadata(index, "Author")
		local category = C_AddOns.GetAddOnMetadata(index, "Category")
		local loadable, reason = C_AddOns.IsAddOnLoadable(index, self.addonCharacter)
		local enabled = loadable or reason == "DEMAND_LOADED"

		if (enabled and self.filters.enabled or not enabled and self.filters.disabled)
		and self.categoriesFilter[category or "rest"]
		and (notSearched
			or searchBy.name and name:lower():find(text, 1, true)
			or searchBy.title and self.titleByIndex[index]:find(text, 1, true)
			or author and author:lower():find(text, 1, true)
			or searchBy.category and category and category:lower():find(text, 1, true))
		then
			self.indexByName[name] = index
			self.filtred[#self.filtred + 1] = index
		end
	end

	self:showResetBtn()
	self:setListGroup()
end