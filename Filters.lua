local addon, ns = ...
local L = ns.L
local listFrame = AddonMgrAddonList


listFrame:HookScript("OnShow", function(self)
	local OnAccept = function(popup, cb)
		local editBox = popup.editBox or popup.EditBox
		local text = editBox:GetText()
		if text and text ~= "" then cb(popup, text) end
	end
	local EditBoxOnEnterPressed = function(self)
		StaticPopup_OnClick(self:GetParent(), 1)
	end
	local EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide()
	end

	StaticPopupDialogs[self.addonName.."ADD_TAG"] = {
		text = addon..": "..L["Add tag"],
		button1 = ACCEPT,
		button2 = CANCEL,
		hasEditBox = 1,
		maxLetters = 48,
		editBoxWidth = 200,
		hideOnEscape = 1,
		whileDead = 1,
		OnAccept = OnAccept,
		EditBoxOnEnterPressed = EditBoxOnEnterPressed,
		EditBoxOnEscapePressed = EditBoxOnEscapePressed,
		OnShow = function(self)
			local editBox = self.editBox or self.EditBox
			editBox:SetFocus()
		end,
	}
	StaticPopupDialogs[self.addonName.."EDIT_TAG"] = {
		text = addon..": "..EDIT,
		button1 = ACCEPT,
		button2 = CANCEL,
		hasEditBox = 1,
		maxLetters = 48,
		editBoxWidth = 350,
		hideOnEscape = 1,
		whileDead = 1,
		OnAccept = OnAccept,
		EditBoxOnEnterPressed = EditBoxOnEnterPressed,
		EditBoxOnEscapePressed = EditBoxOnEscapePressed,
	}
	StaticPopupDialogs[self.addonName.."TAG_EXISTS"] = {
		text = addon..": "..L["Tag already exists."],
		button1 = OKAY,
		whileDead = 1,
	}
	StaticPopupDialogs[self.addonName.."DELETE_TAG"] = {
		text = addon..": "..L["Are you sure you want to delete tag %s?"],
		button1 = DELETE,
		button2 = CANCEL,
		hideOnEscape = 1,
		whileDead = 1,
		OnAccept = function(_, cb) cb() end,
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

			info.text = L["tags"]
			info.value = "tags"
			dd:ddAddButton(info, level)

		elseif value == "tags" then
			info.text = L["No tag"]
			info.func = function(_,_,_, checked)
				self.noTagFilter = checked
				self:updateFilters()
			end
			info.checked = function() return self.noTagFilter end
			dd:ddAddButton(info, level)

			info.text = L["With all tags"]
			info.func = function(_,_,_, checked)
			self.withAllTagsFilter = checked
				self:updateFilters()
			end
			info.checked = function() return self.withAllTagsFilter end
			dd:ddAddButton(info, level)

			dd:ddAddSeparator(level)

			info.checked = nil
			info.notCheckable = true
			info.text = CHECK_ALL
			info.func = function()
				self:setAllTagFilter(true)
				self:updateFilters()
				dd:ddRefresh(level)
			end
			dd:ddAddButton(info, level)

			info.text = UNCHECK_ALL
			info.func = function()
				self:setAllTagFilter(false)
				self:updateFilters()
				dd:ddRefresh(level)
			end
			dd:ddAddButton(info, level)

			info.func = nil
			if #self.tags == 0 then
				info.disabled = true
				info.text = EMPTY
				dd:ddAddButton(info, level)
				info.disabled = nil
			else
				local list = {}
				local func = function(btn, _,_, checked)
					self.tagsFilter[btn.value] = checked
					self:updateFilters()
				end
				local checked = function(btn) return self.tagsFilter[btn.value] end
				local remove = function(btn) self:deleteTag(btn.value) end
				local widgets = {
					{
						icon = [[Interface\WorldMap\GEAR_64GREY]],
						OnClick = function(btn)
							self:editTag(btn.value)
							dd:ddCloseMenus()
						end,
						OnTooltipShow = function(_, tooltip)
							tooltip:SetText(EDIT)
						end,
					}
				}

				for i = 1, #self.tags do
					local tag = self.tags[i]
					list[i] = {
						keepShownOnClick = true,
						isNotRadio = true,
						text = tag,
						value = tag,
						func = func,
						checked = checked,
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
			info.notCheckable = true

			info.text = L["Add tag"]
			info.func = function() self:addTag() end
			dd:ddAddButton(info, level)

		elseif value == "categories" then
			info.notCheckable = true

			info.text = CHECK_ALL
			info.func = function()
				self:setAllCategoryfilters(true)
				self:updateFilters()
				dd:ddRefresh(level)
			end
			dd:ddAddButton(info, level)

			info.text = UNCHECK_ALL
			info.func = function()
				self:setAllCategoryfilters(false)
				self:updateFilters()
				dd:ddRefresh(level)
			end
			dd:ddAddButton(info, level)

			info.notCheckable = nil

			info.func = function(btn, _,_, checked)
				self.categoriesFilter[btn.value] = checked
				self:updateFilters()
			end
			info.checked = function(btn) return self.categoriesFilter[btn.value] end

			for i = 1, #self.categoriesFilter do
				local text = self.categoriesFilter[i]
				info.text =	text == "rest" and L["Rest"] or text
				info.value = text
				dd:ddAddButton(info, level)
			end
		end
	end)
end)


function listFrame:isDefaultFilters()
	for k in next, self.filters do
		if not self.filters[k] then return false end
	end
	if not self.noTagFilter or self.withAllTagsFilter then return false end
	for tag, v in next, self.tagsFilter do
		if not v then return false end
	end
	for i = 1, #self.categoriesFilter do
		if not self.categoriesFilter[self.categoriesFilter[i]] then return false end
	end
	return true
end


function listFrame:showResetBtn()
	self.resetBtn:SetShown(not self:isDefaultFilters())
end


function listFrame:setAllTagFilter(enabled)
	for k in next, self.tagsFilter do
		self.tagsFilter[k] = enabled
	end
end


function listFrame:setAllCategoryfilters(enabled)
	for _, k in ipairs(self.categoriesFilter) do
		self.categoriesFilter[k] = enabled
	end
end


function listFrame:resetFilters()
	for k in next, self.filters do
		self.filters[k] = true
	end
	self.noTagFilter = true
	self.withAllTagsFilter = false
	self:setAllTagFilter(true)
	self:setAllCategoryfilters(true)
	self:updateFilters()
end


function listFrame:addTag(name)
	StaticPopup_Show(self.addonName.."ADD_TAG", nil, nil, function(popup, text)
		for i, tag in ipairs(self.tags) do
			if tag == text then
				popup:Hide()
				StaticPopup_Show(self.addonName.."TAG_EXISTS")
				return
			end
		end
		tinsert(self.tags, text)
		sort(self.tags)
		self.tagsFilter[text] = true
		if name then self:setAddonTag(name, text) end
	end)
end


function listFrame:editTag(tag)
	local dialog = StaticPopup_Show(self.addonName.."EDIT_TAG", nil, nil, function(popup, text)
		if text == tag then return end
		for i, tag in ipairs(self.tags) do
			if tag == text then
				popup:Hide()
				StaticPopup_Show(self.addonName.."TAG_EXISTS")
				return
			end
		end
		tDeleteItem(self.tags, tag)
		tinsert(self.tags, text)
		sort(self.tags)
		self.tagsFilter[text] = self.tagsFilter[tag]
		self.tagsFilter[tag] = nil
		self.catCollapsed[text] = self.catCollapsed[tag]
		self.catCollapsed[tag] = nil
		for _, tags in next, self.addonTags do
			tags[text] = tags[tag]
			tags[tag] = nil
		end
		self:setCategories()
	end)
	if dialog then
		local editBox = dialog.editBox or dialog.EditBox
		editBox:SetText(tag)
		editBox:HighlightText()
	end
end


function listFrame:deleteTag(tag)
	StaticPopup_Show(self.addonName.."DELETE_TAG", NORMAL_FONT_COLOR_CODE..tag..FONT_COLOR_CODE_CLOSE, nil, function()
		if self.categoriesFilter[tag] == nil then
			self.catCollapsed[tag] = nil
		end
		for name in next, self.addonTags do
			self:removeAddonTag(name, tag)
		end
		self.tagsFilter[tag] = nil
		for i = 1, #self.tags do
			if self.tags[i] == tag then
				tremove(self.tags, i)
				break
			end
		end
		self:setCategories()
	end)
end


function listFrame:getAddonTagsStr(name)
	local addonTags = self.addonTags[name]
	if addonTags then
		local list = {}
		for i = 1, #self.tags do
			local tag = self.tags[i]
			if addonTags[tag] then
				list[#list + 1] = tag
			end
		end
		return table.concat(list, ", ")
	end
end


function listFrame:hasAddonTag(name, tag)
	local addonTags = self.addonTags[name]
	return addonTags and addonTags[tag]
end


function listFrame:setAddonTag(name, tag)
	if not self.addonTags[name] then
		self.addonTags[name] = {}
	end
	self.addonTags[name][tag] = true
	self:setCategories()
end


function listFrame:removeAddonTag(name, tag, needUpdate)
	local addonTags = self.addonTags[name]
	if addonTags then
		addonTags[tag] = nil
		if next(addonTags) == nil then self.addonTags[name] = nil end
	end
	if needUpdate then self:setCategories() end
end


function listFrame:findTags(name, text)
	local addonTags = self.addonTags[name]
	if addonTags then
		local str = ""
		for tag in next, addonTags do
			str = str..tag:lower().."\0"
		end

		for word in text:gmatch("%S+") do
			if not str:find(word, 1, true) then return end
		end
		return true
	end
end


function listFrame:getTagFilter(name)
	local addonTags = self.addonTags[name]
	if not addonTags then return self.noTagFilter end
	local tagsFilter = self.tagsFilter

	if self.withAllTagsFilter then
		local i = 0
		for  tag, value in next, tagsFilter do
			if value then
				if not addonTags[tag] then return false end
				i = i + 1
			end
		end
		return i > 0
	else
		for tag in next, addonTags do
			if tagsFilter[tag] then return true end
		end
		return false
	end
end