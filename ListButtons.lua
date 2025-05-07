local addon, ns = ...
local L = ns.L
local listFrame = AddonMgrAddonList


listFrame:HookScript("OnShow", function(self)
	self.contextMenu = LibStub("LibSFDropDown-1.5"):SetMixin({})
	self.contextMenu:ddHideWhenButtonHidden(self.scrollBox)
	self.contextMenu:ddSetDisplayMode("menu")

	self.contextMenu:ddSetInitFunc(function(dd, level, index)
		local info = {}
		local name, title = C_AddOns.GetAddOnInfo(index)

		if level == 1 then
			local checked = C_AddOns.GetAddOnEnableState(index, self.charName) > Enum.AddOnEnableState.None

			info.keepShownOnClick = true
			info.notCheckable = true
			info.isTitle = true
			info.text = self.config.showNameInsteadOfTitle and name or title
			dd:ddAddButton(info, level)

			info.isTitle = nil
			info.notCheckable = nil
			info.isNotRadio = true
			info.text = L["Lock addon"]
			info.func = function(_,_,_, checked)
				self.locked[name] = checked
				local button = self.scrollBox:FindFrameByPredicate(function(btn, node)
					return node:GetData().index == index
				end)
				if button then self:normalInit(button, button:GetElementData()) end
				dd:ddRefresh(level)
			end
			info.checked = self.locked[name]
			dd:ddAddButton(info, level)

			info.keepShownOnClick = nil
			info.notCheckable = true
			info.disabled = function() return self.locked[name] end

			if self.childByPIndex[index] then
				info.text = checked and L["Disable with children"] or L["Enalbe with children"]
				info.func = function()
					self:enableAddon(name, not checked)
					self:enableAddonChildren(name, not checked)
					self:updateList()
					self:updateReloadButton()
				end
				dd:ddAddButton(info, level)
			end

			if C_AddOns.GetAddOnDependencies(index) then
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

			if #self.profiles > 0 then
				info.keepShownOnClick = true
				info.hasArrow = true
				info.text = L["Enabled in profile"]
				info.value = index
				dd:ddAddButton(info, value)
			end

			info.keepShownOnClick = nil
			info.hasArrow = nil
			info.value = nil
			info.text = CANCEL
			dd:ddAddButton(info, level)

		else
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
		end
	end)

	self.scrollBox:RegisterCallback(self.scrollBox.Event.OnDataRangeChanged, function()
		if self.doNotHideMenu then return end
		self.contextMenu:ddOnHide()
	end)
end)


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
					listFrame:enableAddonChildren(parent.name, checked)
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
		listFrame.contextMenu:ddToggle(1, self:GetData().index, "cursor")
	end
end


function AddonMgrListNormalMixin:onEnter()
	local index = self:GetData().index
	if listFrame.tooltipIndex == index then return end
	listFrame.tooltipIndex = index
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint("LEFT", self, "RIGHT")
	listFrame:updateTooltip()
end


function AddonMgrListNormalMixin:onLeave()
	if self:IsShown() then
		listFrame.tooltipIndex = nil
		GameTooltip:Hide()
	end
end


AddonMgrListParentCategoryMixin = {}


function AddonMgrListParentCategoryMixin:onClick()
	local collapsed = self.node:ToggleCollapsed(TreeDataProviderConstants.RetainChildCollapse, TreeDataProviderConstants.DoInvalidation)
	listFrame:setCollapsed(self.node:GetData().index, collapsed)
	self:updateState()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
end


function AddonMgrListParentCategoryMixin:updateState()
	local arrowRotation = self.node:IsCollapsed() and math.pi or math.pi * .5
	self.mormal:SetRotation(arrowRotation)
	self.pushed:SetRotation(arrowRotation)
	self.highlight:SetRotation(arrowRotation)
end