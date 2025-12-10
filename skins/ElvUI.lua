if not C_AddOns.IsAddOnLoaded("ElvUI") then return end
local E = ElvUI[1]
if not (E.private.skins.blizzard.enable and E.private.skins.blizzard.addonManager) then return end
local S = E:GetModule("Skins")
local listFrame = AddonMgrAddonList
listFrame.minimapBtnMenu:ddSetDisplayMode("ElvUI")


listFrame:HookScript("OnShow", function(self)
	self:StripTextures()
	self:SetTemplate("Transparent")
	if self.TitleContainer.TitleBg then -- classic
		self.TitleContainer.TitleBg:Hide()
	end
	S:HandleSliderFrame(self.scaleSlider)
	self.scaleSlider:SetPoint("TOPRIGHT", -47, -6)
	self.settingsBtn:ddSetDisplayMode("ElvUI")
	S:HandleCloseButton(self.closeButton)
	S:HandleEditBox(self.searchBox)
	self.filterBtn:SetHeight(20)
	self.filterBtn:ddSetDisplayMode("ElvUI")
	self.profileBtn:SetHeight(20)
	self.profileBtn:Point("TOPRIGHT", -6, -33)
	self.profileBtn:ddSetDisplayMode("ElvUI")
	S:HandleTrimScrollBar(self.inset.scrollBar)
	S:HandleButton(self.enableAll)
	S:HandleButton(self.disableAll)
	self.disableAll:Point("LEFT", self.enableAll, "RIGHT", 4, 0)
	S:HandleButton(self.cancel)
	self.cancel:Point("BOTTOMRIGHT", -20, self.isMainline and 4 or 6)
	S:HandleButton(self.okay)
	self.okay:Point("RIGHT", self.cancel, "LEFT", -4, 0)
end)


local function setCheckColor(t, r)
	if r == 1 and not t:IsDesaturated() then
		t:dSetVertexColor(1, .8, .1)
	end
end


hooksecurefunc(listFrame, "normalInit", function(self, f)
	if f.isSkinned then return end
	local r, g, b = f.check.CheckedTexture:GetVertexColor()
	S:HandleCheckBox(f.check)
	f.check.CheckedTexture:SetVertexColor(r, g, b)
	f.check.CheckedTexture.dSetVertexColor = f.check.CheckedTexture.SetVertexColor
	setCheckColor(f.check.CheckedTexture, r)
	hooksecurefunc(f.check.CheckedTexture, "SetVertexColor", setCheckColor)
	f.icon:Point("LEFT", 36, 0)
	f.title:SetFontObject("ElvUIFontNormal")
	S:HandleButton(f.loadButton)
	f.isSkinned = true
end)


local function toggleSetTexture(t, v)
	if v == 1 then
		t:Size(12, 6)
	else
		t:dSetColorTexture(1, .8, 0)
		t:Size(12, 12)
		t:ClearAllPoints()
		t:Point("CENTER", t:GetParent().bg)
	end
end


hooksecurefunc(listFrame, "categoryInit", function(self, f)
	if f.isSkinned then return end
	f.normalTexture:SetTexture()
	f.pushedTexture:SetTexture()
	f:SetTemplate("Transparent")
	f.highlight:SetTexture("Interface/QuestFrame/UI-QuestTitleHighlight")
	f.highlight:SetDesaturated()
	f.highlight:Point("TOPLEFT", 2, -2)
	f.highlight:Point("BOTTOMRIGHT", -2, 2)
	f.icon:Point("RIGHT", -6, -1)
	f.title:Point("LEFT", 50, 1)
	f.title:Point("RIGHT", -50, 1)
	f.toggleBtn:StripTextures()
	f.toggleBtn:CreateBackdrop(nil, nil, nil, nil, nil, nil, nil, nil, f.toggleBtn:GetFrameLevel())
	f.toggleBtn.backdrop:SetInside(nil, 1, 1)
	f.toggleBtn:Point("LEFT", 13, 0)
	f.toggleBtn.check.dSetColorTexture = f.toggleBtn.check.SetColorTexture
	hooksecurefunc(f.toggleBtn.check, "SetAtlas", toggleSetTexture)
	hooksecurefunc(f.toggleBtn.check, "SetColorTexture", toggleSetTexture)
	if f.checked then
		f.toggleBtn.check:dSetColorTexture(1, .8, 0)
		toggleSetTexture(f.toggleBtn.check, f.checked == 2 and 1)
	end
	f.isSkinned = true
end)