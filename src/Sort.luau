--!strict
--!optimize 2
--!native

local Types = require(script.Parent.Types)

type Item = Types.Item
type Value = Types.Value
type SortKey = Types.SortKey
type SortOptions = Types.SortOptions

local TYPE_ORDER: { [string]: number } = {
	boolean = 1,
	number = 2,
	string = 3,
}

local function compareValues(a: Value, b: Value): number
	local typeA = type(a)
	local typeB = type(b)
	if typeA ~= typeB then
		return if TYPE_ORDER[typeA] < TYPE_ORDER[typeB] then -1 else 1
	end
	if typeA == "boolean" then
		return if a == false then -1 else 1
	end
	return if (a :: any) < (b :: any) then -1 else 1
end

local function buildOrder(n: number): { number }
	local order = table.create(n) :: { number }
	for i = 1, n do
		order[i] = i
	end
	return order
end

local function applyOrder(items: { Item }, order: { number })
	local n = #order
	local sorted = table.create(n) :: { Item }
	for i = 1, n do
		sorted[i] = items[order[i]]
	end
	table.move(sorted, 1, n, 1, items)
end

local function sortSingle(items: { Item }, key: SortKey)
	local parameter = key.parameter
	local descending = key.direction == "descending"
	local n = #items

	local values = table.create(n) :: { Value? }
	local ids = table.create(n) :: { string }
	local hasNil = false
	local valueType: string? = nil
	local mixed = false

	for i = 1, n do
		local item = items[i]
		local value = item.parameters[parameter]
		values[i] = value
		ids[i] = item.id
		if value == nil then
			hasNil = true
		else
			local t = type(value)
			if valueType == nil then
				valueType = t
			elseif valueType ~= t then
				mixed = true
			end
		end
	end

	local order = buildOrder(n)

	if not hasNil and not mixed and (valueType == "number" or valueType == "string") then
		local vals = values :: any
		if descending then
			table.sort(order, function(i, j)
				local a, b = vals[i], vals[j]
				if a ~= b then
					return b < a
				end
				return ids[i] < ids[j]
			end)
		else
			table.sort(order, function(i, j)
				local a, b = vals[i], vals[j]
				if a ~= b then
					return a < b
				end
				return ids[i] < ids[j]
			end)
		end
	else
		table.sort(order, function(i, j)
			local a, b = values[i], values[j]

			-- Items missing the parameter sort last regardless of direction.
			if a == nil or b == nil then
				if a == nil and b == nil then
					return ids[i] < ids[j]
				end
				return b == nil
			end

			if a ~= b then
				local cmp = compareValues(a, b)
				return if descending then cmp > 0 else cmp < 0
			end
			return ids[i] < ids[j]
		end)
	end

	applyOrder(items, order)
end

local function sortMulti(items: { Item }, keys: { SortKey })
	local n = #items
	local keyCount = #keys

	local columns = table.create(keyCount) :: { { Value? } }
	local descendings = table.create(keyCount) :: { boolean }
	for k = 1, keyCount do
		local parameter = keys[k].parameter
		local column = table.create(n) :: { Value? }
		for i = 1, n do
			column[i] = items[i].parameters[parameter]
		end
		columns[k] = column
		descendings[k] = keys[k].direction == "descending"
	end

	local ids = table.create(n) :: { string }
	for i = 1, n do
		ids[i] = items[i].id
	end

	local order = buildOrder(n)
	table.sort(order, function(i, j)
		for k = 1, keyCount do
			local column = columns[k]
			local a, b = column[i], column[j]

			if a == nil or b == nil then
				if a == nil and b == nil then
					continue
				end
				return b == nil
			end

			if a ~= b then
				local cmp = compareValues(a, b)
				return if descendings[k] then cmp > 0 else cmp < 0
			end
		end
		return ids[i] < ids[j]
	end)

	applyOrder(items, order)
end

local function Sort(items: { Item }, options: SortOptions): { Item }
	local keys: { SortKey }
	if (options :: any).parameter then
		keys = { options :: SortKey }
	else
		keys = options :: { SortKey }
	end

	if #keys == 0 or #items <= 1 then
		return items
	end

	if #keys == 1 then
		sortSingle(items, keys[1])
	else
		sortMulti(items, keys)
	end
	return items
end

return Sort
