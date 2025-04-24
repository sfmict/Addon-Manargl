local _, ns = ...
local L = {}
ns.L = L


-- TOOLTIP
L["Author"] = "Author"
L["Ticks over %sms"] = "Ticks over %sms"
L["Memory Usage"] = "Memory Usage"
L["Profiles with addon"] = "Profiles with addon"
L["Left+Shift with children"] = "Left+Shift with children"
L["Left+Alt to lock/unclock"] = "Left+Alt to lock/unclock"
L["Right For more options"] = "Right For more options"
-- CONTEXTMENU
L["Lock addon"] = "Lock addon"
L["Enalbe with children"] = "Enalbe with children"
L["Disable with children"] = "Disable with children"
L["Enable with dependencies"] = "Enable with dependencies"
L["Disable with dependencies"] = "Disable with dependencies"
L["Enabled in profile"] = "Enabled in profile"
-- FILTERS
L["Enabled"] = "Enabled"
L["Disabled"] = "Disabled"
L["Rest"] = "Rest"
-- PROFILES
L["Profiles"] = "Profiles"
L["Characters"] = "Characters"
L["Load"] = "Load"
L["Save"] = "Save"
L["Enable Addons"] = "Enable Addons"
L["Disable Addons"] = "Disable Addons"
L["Also load profiles"] = "Also load profiles"
L["Create profile"] = "Create profile"
L["A profile with the same name exists."] = "A profile with the same name exists."
L["Are you sure you want to delete %s profile?"] = "Are you sure you want to delete %s profile?"
L["Are you sure you want to %s?"] = "Are you sure you want to %s?"
L["Rewrite addons to %s profile?"] = "Rewrite addons to %s profile?"
L["Load %s profile?"] = "Load %s profile?"
L["Enable addons from %s profile?"] = "Enable addons from %s profile?"
L["Disable addons from %s profile?"] = "Disable addons from %s profile?"
L["Remove all character profiles"] = "Remove all character profiles"
-- SETTINGS
L["Options"] = "Options"
L["Show minimap button"] = "Show minimap button"
L["Replace Addon wow menu button"] = "Replace Addon wow menu button"
L["Memory Update"] = "Memory Update"
L["CPU Update"] = "CPU Update"
L["Disable"] = "Disable"
L["%s seconds"] = "%s seconds"
L["List Options"] = "List Options"
L["Collapse All"] = "Collapse All"
L["Expand All"] = "Expand All"
L["Show Name instead of Title"] = "Show Name instead of Title"
L["Show Icon"] = "Show Icon"
L["Show no Icon Texture"] = "Show no Icon Texture"
L["Show Version"] = "Show Version"
L["Group by"] = "Group by"
L["Dependencies"] = "Dependencies"
L["Dependency tree"] = "Dependency tree"
L["Group"] = "Group"
L["Sort by"] = "Sort by"
L["Current CPU"] = "Current CPU"
L["Average CPU"] = "Average CPU"
L["Peak CPU"] = "Peak CPU"
L["Encounter CPU"] = "Encounter CPU"
L["Search Options"] = "Search Options"
L["Autofocus search when opening addon"] = "Autofocus search when opening addon"
L["Search by"] = "Search by"
L["Title"] = "Title"


setmetatable(L, {__index = function(self, key)
	self[key] = key or ""
	return key
end})