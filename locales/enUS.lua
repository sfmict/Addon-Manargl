local _, ns = ...
local L = {}
ns.L = L


setmetatable(L, {__index = function(self, key)
	self[key] = key or ""
	return key
end})