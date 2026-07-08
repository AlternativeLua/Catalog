--!strict
--!optimize 2
--!native

local Types = require(script.Parent.Types)

type CatalogData = Types.CatalogData
type Item = Types.Item
type SearchParams = Types.SearchParams

local function countKeys(set: { [string]: true }): number
	local n = 0
	for _ in set do
		n += 1
	end
	return n
end

local function Search(self: CatalogData, params: SearchParams): { Item }
	local sets: { { [string]: true } } = {}
	for parameter, value in params do
		local byValue = self.index[parameter]
		local ids = byValue and byValue[value]
		if not ids then
			return {}
		end
		table.insert(sets, ids)
	end

	local results: { Item } = {}

	if #sets == 0 then
		for _, item in self.byId do
			table.insert(results, item)
		end
		return results
	end

	local smallest = sets[1]
	local smallestCount = countKeys(smallest)
	for i = 2, #sets do
		local count = countKeys(sets[i])
		if count < smallestCount then
			smallest = sets[i]
			smallestCount = count
		end
	end

	for id in smallest do
		local inAll = true
		for _, set in sets do
			if set[id] == nil then
				inAll = false
				break
			end
		end

		if inAll then
			local item = self.byId[id]
			if item then
				table.insert(results, item)
			end
		end
	end

	return results
end

return Search
