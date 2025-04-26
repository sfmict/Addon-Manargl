local listFrame = AddonMgrAddonList
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
	return ("|cffff%.2x%.2x%.2f%%|r"):format(color, color, percent)
end


function listFrame:getAddonMetric(name, metric)
	if not ProfilerIsEnabled() then return end

	local addonVal = ProfilerGetAddOnMetric(name, metric)
	local overallVal = self.metrics[metric] or 0
	local relativeTotal = overallVal + addonVal or 0

	if relativeTotal <= 0 then return end

	return addonVal / relativeTotal * 100
end


function listFrame:getAddonMetricPercent(name, metric)
	local val = self:getAddonMetric(name, metric) or 0
	if val > .005 then
		return getColorPercent(val)
	else
		return ("%.2f%%"):format(val)
	end
end


function listFrame:getAddonMetricCount(name, metric)
	return ProfilerGetAddOnMetric(name, metric)
end


function listFrame:updateOverallMetric(fontString, metric)
	local appVal = ProfilerGetApplicationMetric(metric) or 0
	if appVal <= 0 then
		fontString:SetText("--")
		return
	end

	local overallVal = ProfilerGetOverallMetric(metric)
	self.metrics[metric] = appVal - overallVal
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