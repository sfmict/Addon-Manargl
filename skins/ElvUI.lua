if not C_AddOns.IsAddOnLoaded("ElvUI") then return end
local E = ElvUI[1]
if E.private.skins.blizzard.misc ~= true then return end
local S = E:GetModule("Skins")


local function setCheckColor(t, r)
	if r == 1 and not t:IsDesaturated() then
		t:dSetVertexColor(unpack(E.media.rgbvaluecolor))
	end
end


local function btnInit(self, f)
	if not f.isSkinned then
		local r, g, b = f.check.CheckedTexture:GetVertexColor()
		S:HandleCheckBox(f.check)
		f.check.CheckedTexture:SetVertexColor(r, g, b)
		f.check.CheckedTexture.dSetVertexColor = f.check.CheckedTexture.SetVertexColor
		setCheckColor(f.check.CheckedTexture, r)
		hooksecurefunc(f.check.CheckedTexture, "SetVertexColor", setCheckColor)
		f.icon:SetPoint("LEFT", 36, 0)
		f.title:SetFontObject("ElvUIFontNormal")
		S:HandleButton(f.loadButton)
		f.isSkinned = true
	end
end


AddonMgrAddonList:HookScript("OnShow", function(self)
	self:StripTextures()
	self:SetTemplate("Transparent")
	if self.TitleContainer.TitleBg then -- classic
		self.TitleContainer.TitleBg:Hide()
	end
	self.settingsBtn:ddSetDisplayMode("ElvUI")
	S:HandleCloseButton(self.closeButton)
	S:HandleEditBox(self.searchBox)
	self.filterBtn:SetHeight(20)
	self.filterBtn:ddSetDisplayMode("ElvUI")
	self.profileBtn:SetHeight(20)
	self.profileBtn:SetPoint("TOPRIGHT", -6, -33)
	self.profileBtn:ddSetDisplayMode("ElvUI")
	S:HandleTrimScrollBar(self.inset.scrollBar)
	S:HandleButton(self.enableAll)
	S:HandleButton(self.disableAll)
	self.disableAll:SetPoint("LEFT", self.enableAll, "RIGHT", 4, 0)
	S:HandleButton(self.cancel)
	self.cancel:SetPoint("BOTTOMRIGHT", -20, 6)
	S:HandleButton(self.okay)
	self.okay:SetPoint("RIGHT", self.cancel, "LEFT", -4, 0)
	hooksecurefunc(self, "normalInit", btnInit)
end)