local addon, ns = ...
local L = ns.L
local listFrame = AddonMgrAddonList


listFrame:HookScript("OnShow", function(self)
	self.contextMenu = LibStub("LibSFDropDown-1.5"):SetMixin({})
	self.contextMenu:ddHideWhenButtonHidden(self.scrollBox)
	self.contextMenu:ddSetDisplayMode("menu")

	self.addonContextMenu = function(dd, level, value)
		local name = self.contextMenuData.name
		local info = {}

		if level == 1 then
			local checked = C_AddOns.GetAddOnEnableState(name, self.charName) > Enum.AddOnEnableState.None

			info.keepShownOnClick = true
			info.notCheckable = true
			info.isTitle = true
			info.text = self.config.showNameInsteadOfTitle and name or select(2, C_AddOns.GetAddOnInfo(name))
			dd:ddAddButton(info, level)

			info.isTitle = nil
			info.notCheckable = nil
			info.isNotRadio = true
			info.text = L["Lock addon"]
			info.func = function(_,_,_, checked)
				self.locked[name] = checked
				local button = self.scrollBox:FindFrameByPredicate(function(btn, node)
					return node:GetData().name == name
				end)
				if button then self:normalInit(button, button:GetElementData()) end
				dd:ddRefresh(level)
			end
			info.checked = self.locked[name]
			dd:ddAddButton(info, level)

			info.checked = nil
			info.keepShownOnClick = nil
			info.notCheckable = true
			info.disabled = function() return self.locked[name] end

			if self.contextMenuData.isParent then
				info.text = checked and L["Disable with children"] or L["Enalbe with children"]
				info.func = function()
					self:enableAddon(name, not checked)
					self:enableAddonChildren(self.contextMenuData.childList, name, not checked)
					self:updateList()
					self:updateReloadButton()
				end
				dd:ddAddButton(info, level)
			end

			if self.depsByName[name] then
				info.text = checked and L["Disable with dependencies"] or L["Enable with dependencies"]
				info.func = function()
					self:enableAddon(name, not checked)
					self:enableAddonDependencies(name, not checked)
					self:updateList()
					self:updateReloadButton()
				end
				dd:ddAddButton(info, level)
			end

			info.disabled = nil
			info.func = nil
			info.keepShownOnClick = true
			info.hasArrow = true

			if #self.profiles > 0 then
				info.text = L["Enabled in profile"]
				info.value = "profile"
				dd:ddAddButton(info, value)
			end

			info.text = L["tags"]
			info.value = "tags"
			dd:ddAddButton(info, value)

			info.keepShownOnClick = nil
			info.hasArrow = nil
			info.value = nil
			info.text = CANCEL
			dd:ddAddButton(info, level)

		elseif value == "profile" then
			local list = {}

			local func = function(btn, _,_, checked)
				local profile = btn.value
				if checked then
					profile.count = profile.count + 1
					profile.addons[name] = 1
				else
					profile.count = profile.count - 1
					profile.addons[name] = nil
				end
				self:updateList()
			end

			for i, profile in ipairs(self.profiles) do
				list[i] = {
					keepShownOnClick = true,
					isNotRadio = true,
					text = profile.name,
					value = profile,
					func = func,
					checked = profile.addons[name],
				}
			end

			info.list = list
			dd:ddAddButton(info, level)

		elseif value == "tags" then
			local list = {}

			local func = function(btn, _,_, checked)
				if checked then
					self:setAddonTag(name, btn.value)
				else
					self:removeAddonTag(name, btn.value, true)
				end
			end

			for i, tag in ipairs(self.tags) do
				list[i] = {
					keepShownOnClick = true,
					isNotRadio = true,
					text = tag,
					value = tag,
					func = func,
					checked = self:hasAddonTag(name, tag),
				}
			end

			info.list = list
			dd:ddAddButton(info, level)
			info.list = nil

			if #self.tags > 0 then
				dd:ddAddSeparator(level)
			end

			info.notCheckable = true
			info.text = L["Add tag"]
			info.func = function() self:addTag(name) end
			dd:ddAddButton(info, level)
		end
	end

	self.tagCategoryContextMenu = function(dd, level)
		local info = {}
		local name = self.contextMenuData.name

		info.notCheckable = true
		info.keepShownOnClick = true
		info.isTitle = true
		info.text = name
		dd:ddAddButton(info, level)

		info.keepShownOnClick = nil
		info.isTitle = nil
		info.text = L["Delete tag"]
		info.func = function() self:deleteTag(name) end
		dd:ddAddButton(info, level)

		info.func = nil
		info.text = CANCEL
		dd:ddAddButton(info, level)
	end

	self.scrollBox:RegisterCallback(self.scrollBox.Event.OnDataRangeChanged, function()
		if self.doNotHideMenu then return end
		self.contextMenu:ddOnHide()
	end)
end)


AddonMgrListCategoryMixin = {}


do
	local function toggleOnClick(btn)
		local parent = btn:GetParent()
		local category = parent:GetData().category
		for i = 1, #category do
			listFrame:enableAddon(category[i], parent.checked ~= 1)
		end
		listFrame:updateList()
		listFrame:updateReloadButton()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	end

	function AddonMgrListCategoryMixin:onLoad()
		self.toggleBtn:SetScript("OnClick", toggleOnClick)
	end
end


function AddonMgrListCategoryMixin:onEnter()
	self.highlight:Show()
end


function AddonMgrListCategoryMixin:onLeave()
	self.highlight:Hide()
end


function AddonMgrListCategoryMixin:onClick(button)
	if button == "LeftButton" then
		local collapsed = self:GetElementData():ToggleCollapsed(TreeDataProviderConstants.RetainChildCollapse, TreeDataProviderConstants.DoInvalidation)
		listFrame:setCatCollapsed(self:GetData().name, collapsed)
		self:updateState()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	elseif listFrame.config.catGroup == "tag" then
		listFrame.contextMenuData = self:GetData()
		listFrame.contextMenu:ddSetInitFunc(listFrame.tagCategoryContextMenu)
		listFrame.contextMenu:ddToggle(1, nil, "cursor")
	end
end


function AddonMgrListCategoryMixin:updateState()
	self.icon:SetAtlas(self:GetElementData():IsCollapsed() and "glues-characterselect-icon-plus" or "glues-characterselect-icon-minus", true)
end


AddonMgrListNormalMixin = {}


do
	local function onEnter(btn)
		if not btn.tooltip then return end
		GameTooltip:SetOwner(btn, "ANCHOR_TOP")
		GameTooltip:SetText(btn.tooltip)
		GameTooltip:Show()
	end

	local function addonToggle(btn, button)
		local parent = btn:GetParent()
		if button == "LeftButton" then
			if IsAltKeyDown() then
				listFrame.locked[parent.name] = not listFrame.locked[parent.name]
				listFrame:normalInit(parent, parent:GetElementData())
			else
				if listFrame.locked[parent.name] then return end
				local checked = btn:GetChecked()
				PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
				listFrame:enableAddon(parent.name, checked)
				if IsShiftKeyDown() then
					listFrame:enableAddonChildren(parent:GetData().childList, parent.name, checked)
				end
				listFrame:updateReloadButton()
				listFrame:updateList()
			end
		else
			btn:SetChecked(not btn:GetChecked())
			parent:GetScript("OnClick")(parent, button)
		end
	end

	local function loadAddon(btn)
		C_AddOns.LoadAddOn(btn:GetParent().name)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	end

	function AddonMgrListNormalMixin:onLoad()
		self.check:SetScript("OnClick", addonToggle)
		self.check:SetScript("OnEnter", onEnter)
		self.check:SetScript("OnLeave", GameTooltip_Hide)
		self.loadButton:SetWidth(self.loadButton:GetTextWidth() + 20)
		self.loadButton:SetScript("OnClick", loadAddon)
	end
end


function AddonMgrListNormalMixin:onClick(button)
	if button == "LeftButton" then
		self.check:Click()
	elseif button == "MiddleButton" then
		self.collapseExpand:Click()
	else
		listFrame.contextMenuData = self:GetData()
		listFrame.contextMenu:ddSetInitFunc(listFrame.addonContextMenu)
		listFrame.contextMenu:ddToggle(1, nil, "cursor")
	end
end


function AddonMgrListNormalMixin:onEnter()
	local data = self:GetData()
	if listFrame.tooltipData == data then return end
	listFrame.tooltipData = data
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint("LEFT", self, "RIGHT")
	listFrame:updateTooltip()
end


function AddonMgrListNormalMixin:onLeave()
	if self:IsShown() then
		listFrame.tooltipData = nil
		GameTooltip:Hide()
	end
end


AddonMgrListParentMixin = {}


function AddonMgrListParentMixin:onClick()
	local node = self:GetParent():GetElementData()
	local collapsed = node:ToggleCollapsed(TreeDataProviderConstants.RetainChildCollapse, TreeDataProviderConstants.DoInvalidation)
	listFrame:setGroupCollapsed(node:GetData().name, collapsed)
	self:updateState()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
end


function AddonMgrListParentMixin:updateState()
	local arrowRotation = self:GetParent():GetElementData():IsCollapsed() and math.pi or math.pi * .5
	self.normal:SetRotation(arrowRotation)
	self.pushed:SetRotation(arrowRotation)
	self.highlight:SetRotation(arrowRotation)
end