local _, ns = ...
local L = ns.L
local listFrame = AddonMgrAddonList
local ProfilerIsEnabled = C_AddOnProfiler.IsEnabled
local ProfilerGetApplicationMetric = C_AddOnProfiler.GetApplicationMetric
local ProfilerGetAddOnMetric = C_AddOnProfiler.GetAddOnMetric
local ProfilerGetOverallMetric = C_AddOnProfiler.GetOverallMetric
local min, accuracyColorStr = math.min


listFrame.enumRecentAverageTime = Enum.AddOnProfilerMetric.RecentAverageTime
listFrame.enumSessionAverageTime = Enum.AddOnProfilerMetric.SessionAverageTime
listFrame.enumPeakTime = Enum.AddOnProfilerMetric.PeakTime
listFrame.enumEncounterAverageTime = Enum.AddOnProfilerMetric.EncounterAverageTime

listFrame.metrics = {
	Enum.AddOnProfilerMetric.RecentAverageTime,
	Enum.AddOnProfilerMetric.SessionAverageTime,
	Enum.AddOnProfilerMetric.PeakTime,
	Enum.AddOnProfilerMetric.EncounterAverageTime,
	Enum.AddOnProfilerMetric.LastTime,
	Enum.AddOnProfilerMetric.CountTimeOver1Ms,
	Enum.AddOnProfilerMetric.CountTimeOver5Ms,
	Enum.AddOnProfilerMetric.CountTimeOver10Ms,
	Enum.AddOnProfilerMetric.CountTimeOver50Ms,
	Enum.AddOnProfilerMetric.CountTimeOver100Ms,
	Enum.AddOnProfilerMetric.CountTimeOver500Ms,
	Enum.AddOnProfilerMetric.CountTimeOver1000Ms,
}

listFrame.metricNames = {
	L["Current CPU"],
	L["Average CPU"],
	L["Peak CPU"],
	L["Encounter CPU"],
	L["Last Tick CPU"],
	L["Ticks over %sms"]:format(1),
	L["Ticks over %sms"]:format(5),
	L["Ticks over %sms"]:format(10),
	L["Ticks over %sms"]:format(50),
	L["Ticks over %sms"]:format(100),
	L["Ticks over %sms"]:format(500),
	L["Ticks over %sms"]:format(1000),
}


local function getColorPercent(percent)
	local color = (100 - min(percent, 100)) * 2.55
	return accuracyColorStr:format(color, percent)
end


function listFrame:setCpuAccuracyStr()
	accuracyColorStr = "|cffff%.2x%1$.2x%."..self.config.cpuAccuracy.."f%%|r"
	self.accuracyZeroStr = ("%."..self.config.cpuAccuracy.."f%%"):format(0)
	self.accuracyDelta = .5 / 10^self.config.cpuAccuracy
end


function listFrame:getAddonMetric(name, metric)
	local addonVal = ProfilerGetAddOnMetric(name, metric)
	local appVal = ProfilerGetApplicationMetric(metric)

	if appVal <= 0 then return 0 end
	return addonVal / appVal * 100, addonVal
end


function listFrame:getAddonMetricPercent(name, metric)
	local val, ms = self:getAddonMetric(name, metric)
	if val < self.accuracyDelta then
		return self.accuracyZeroStr, ms, 100
	else
		return getColorPercent(val), ms, 255
	end
end


function listFrame:getAddonMetricCount(name, metric)
	return ProfilerGetAddOnMetric(name, metric)
end


function listFrame:getAddonMetricForDisplay(name, metric)
	if metric < 5 then
		return self:getAddonMetricPercent(name, metric)
	else
		return self:getAddonMetricCount(name, metric)
	end
end


function listFrame:updateOverallMetric(btn, metric)
	local appVal = ProfilerGetApplicationMetric(metric)
	if appVal <= 0 then
		btn.bottomStr:SetText("--")
		return
	end
	local overallVal = ProfilerGetOverallMetric(metric)
	btn.bottomStr:SetText(getColorPercent(overallVal / appVal * 100))
	btn.ms = overallVal
	if btn.isHover then btn:GetScript("OnEnter")(btn) end
end


function listFrame:isProfilerEnabled()
	return self.config.cpuUpdate and ProfilerGetApplicationMetric and ProfilerIsEnabled()
end


function listFrame:updatePerformance()
	local enabled = self:isProfilerEnabled()
	self.performance:SetShown(enabled)
	if not enabled then return end

	self:updateOverallMetric(self.currentCPU, self.enumRecentAverageTime)
	self:updateOverallMetric(self.averageCPU, self.enumSessionAverageTime)
	self:updateOverallMetric(self.peakCPU, self.enumPeakTime)
	self:updateOverallMetric(self.encounterCPU, self.enumEncounterAverageTime)
end


function listFrame:updateAddonMetrics(f)
	local name, str = f.name
	if self:isProfilerEnabled() then
		str = self.currentStr:format(self:getAddonMetricPercent(name, self.enumRecentAverageTime))
		if self.config.cpuSortBy == "average" then
			str = self.averageStr:format(str, self:getAddonMetricPercent(name, self.enumSessionAverageTime))
		elseif self.config.cpuSortBy == "peak" then
			str = self.peakStr:format(str, self:getAddonMetricPercent(name, self.enumPeakTime))
		elseif self.config.cpuSortBy == "encounter" then
			str = self.encounterStr:format(str, self:getAddonMetricPercent(name, self.enumEncounterAverageTime))
		end
	end
	f.status:SetText(str)
end


function listFrame:updateAddonMemoryUsage(force)
	local now = GetTime()
	local lastMemoryUpdate = self.lastMemoryUpdate or 0
	local interval = self.config.memUpdate or 30
	if now >= lastMemoryUpdate + interval or force then
		self.lastMemoryUpdate = now
		UpdateAddOnMemoryUsage()
	end
end


function listFrame:onUpdate(elapsed)
	self.uTimer = self.uTimer - elapsed
	if self.uTimer > 0 then return end
	self.uTimer = .05
	self.syncCounter = self.syncCounter + 1
	local timer = self.syncCounter * self.uTimer
	local needUpdate = false

	if self.config.memUpdate and timer % self.config.memUpdate == 0 then
		self:updateAddonMemoryUsage()
		needUpdate = true
	end

	if self.config.cpuUpdate and timer % self.config.cpuUpdate == 0 then
		self:updatePerformance()
		needUpdate = true

		if self.config.cpuSortBy then
			self:sort()
		else
			for i, f in ipairs(self.view:GetFrames()) do
				if f.loaded then self:updateAddonMetrics(f) end
			end
		end
	end

	if needUpdate then self:updateTooltip() end
end