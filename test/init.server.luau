local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Catalog)

local ITEM_COUNT = 100_000

local CATEGORIES = { "weapon", "armor", "consumable", "material", "quest" }
local RARITIES = { "common", "common", "common", "rare", "legendary" }
local SUFFIXES = { "sword", "shield", "potion", "gem", "cloak" }

local function buildDataset(): { any }
	local items = table.create(ITEM_COUNT)
	for i = 1, ITEM_COUNT do
		items[i] = {
			id = "item_" .. i,
			parameters = {
				category = CATEGORIES[(i % #CATEGORIES) + 1],
				rarity = RARITIES[(i // #CATEGORIES % #RARITIES) + 1],
				tier = i % 100, 
				name = string.format("Item_%d_%s", i, SUFFIXES[(i % #SUFFIXES) + 1]),
			},
		}
	end
	return items
end


local function bench(label: string, iterations: number, fn: () -> any)
	fn() -- warm up (JIT / caches)

	local start = os.clock()
	local result
	for _ = 1, iterations do
		result = fn()
	end
	local elapsed = os.clock() - start

	local msPerOp = (elapsed / iterations) * 1000
	local resultCount = if type(result) == "table" then #result else 0
	print(string.format("  %-34s %9.4f ms/op   %6d results   (%d iters)", label, msPerOp, resultCount, iterations))
end

print(string.format("Catalog v%s benchmark — %d items", Catalog.Version, ITEM_COUNT))

local items = buildDataset()
local cat = Catalog.new({ "category", "rarity", "tier" })

do
	local start = os.clock()
	Catalog.BulkAddToCatalog(cat, items)
	print(string.format("  %-34s %9.4f ms total", "build (BulkAddToCatalog)", (os.clock() - start) * 1000))
end

print("equality search (inverted index):")
bench("Search { tier = 42 }", 500, function()
	return Catalog.Search(cat, { tier = 42 })
end)
bench("Search { category = weapon }", 200, function()
	return Catalog.Search(cat, { category = "weapon" })
end)
bench("Search { weapon + legendary }", 500, function()
	return Catalog.Search(cat, { category = "weapon", rarity = "legendary" })
end)

print("substring search (Boyer-Moore, O(n) scan):")
bench("SearchText name ~ 'sword'", 20, function()
	return Catalog.SearchText(cat, "name", "sword")
end)
bench("SearchText name ~ '<no match>'", 20, function()
	return Catalog.SearchText(cat, "name", "zzzznomatch")
end)

print("direct lookup:")
bench("Get item_50000", 100000, function()
	return Catalog.Get(cat, "item_50000")
end)
