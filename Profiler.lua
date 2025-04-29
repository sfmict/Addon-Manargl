local listFrame, accuracyColorStr = AddonMgrAddonList
local ProfilerIsEnabled = C_AddOnProfiler.IsEnabled
local ProfilerGetApplicationMetric = C_AddOnProfiler.GetApplicationMetric
local ProfilerGetAddOnMetric = C_AddOnProfiler.GetAddOnMetric
local ProfilerGetOverallMetric = C_AddOnProfiler.GetOverallMetric


listFrame.profilerEnumRecentAverageTime = Enum.AddOnProfilerMetric.RecentAverageTime
listFrame.profilerEnumSessionAverageTime = Enum.AddOnProfilerMetric.SessionAverageTime
listFrame.profilerEnumPeakTime = Enum.AddOnProfilerMetric.PeakTime
listFrame.profilerEnumEncounterAverageTime = Enum.AddOnProfilerMetric.EncounterAverageTime
listFrame.profilerEnumCountTimeOver5Ms = Enum.AddOnProfilerMetric.CountTimeOver5Ms
listFrame.profilerEnumCountTimeOver10Ms = Enum.AddOnProfilerMetric.CountTimeOver10Ms
listFrame.profilerEnumCountTimeOver50Ms = Enum.AddOnProfilerMetric.CountTimeOver50Ms
listFrame.profilerEnumCountTimeOver100Ms = Enum.AddOnProfilerMetric.CountTimeOver100Ms
listFrame.profilerEnumCountTimeOver500Ms = Enum.AddOnProfilerMetric.CountTimeOver500Ms


local function getColorPercent(percent)
	local color = (100 - math.min(percent, 100)) * 2.55
	return accuracyColorStr:format(color, color, percent)
end


function listFrame:setCpuAccuracyStr()
	accuracyColorStr = "|cffff%.2x%.2x%."..self.config.cpuAccuracy.."f%%|r"
	self.accuracyZeroStr = ("%."..self.config.cpuAccuracy.."f%%"):format(0)
	self.accuracyDelta = .5 / 10^self.config.cpuAccuracy
end


function listFrame:getAddonMetric(name, metric)
	local addonVal = ProfilerGetAddOnMetric(name, metric)
	local appVal = ProfilerGetApplicationMetric(metric)

	if appVal <= 0 then return end
	return addonVal / appVal * 100
end


function listFrame:getAddonMetricPercent(name, metric)
	local val = self:getAddonMetric(name, metric) or 0
	if val < self.accuracyDelta then
		return self.accuracyZeroStr
	else
		return getColorPercent(val)
	end
end


function listFrame:getAddonMetricCount(name, metric)
	return ProfilerGetAddOnMetric(name, metric)
end


function listFrame:updateOverallMetric(fontString, metric)
	local appVal = ProfilerGetApplicationMetric(metric)
	if appVal <= 0 then
		fontString:SetText("--")
		return
	end
	local overallVal = ProfilerGetOverallMetric(metric)
	fontString:SetText(getColorPercent(overallVal / appVal * 100))
end


function listFrame:isProfilerEnabled()
	return self.config.cpuUpdate and ProfilerGetApplicationMetric and ProfilerIsEnabled()
end


function listFrame:updatePerformance()
	local enabled = self:isProfilerEnabled()
	self.performance:SetShown(enabled)
	if not enabled then return end

	self:updateOverallMetric(self.currentCPU.bottomStr, self.profilerEnumRecentAverageTime)
	self:updateOverallMetric(self.averageCPU.bottomStr, self.profilerEnumSessionAverageTime)
	self:updateOverallMetric(self.peakCPU.bottomStr, self.profilerEnumPeakTime)
	self:updateOverallMetric(self.encounterCPU.bottomStr, self.profilerEnumEncounterAverageTime)
end


function listFrame:updateAddonMetrics(f)
	local name = f.name
	local str = ""
	if self:isProfilerEnabled() then
		str = self.currentStr:format(self:getAddonMetricPercent(name, self.profilerEnumRecentAverageTime))
		if self.config.cpuSortBy == "average" then
			str = self.averageStr:format(str, self:getAddonMetricPercent(name, self.profilerEnumSessionAverageTime))
		elseif self.config.cpuSortBy == "peak" then
			str = self.peakStr:format(str, self:getAddonMetricPercent(name, self.profilerEnumPeakTime))
		elseif self.config.cpuSortBy == "encounter" then
			str = self.encounterStr:format(str, self:getAddonMetricPercent(name, self.profilerEnumEncounterAverageTime))
		end
	end
	f.status:SetText(str)
end


function listFrame:onUpdate(elapsed)
	self.uTimer = self.uTimer - elapsed
	if self.uTimer > 0 then return end
	self.uTimer = .1
	self.syncCounter = self.syncCounter + 1
	local timer = self.syncCounter * self.uTimer
	local needUpdate = false

	if self.config.memUpdate and timer % self.config.memUpdate == 0 then
		UpdateAddOnMemoryUsage()
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