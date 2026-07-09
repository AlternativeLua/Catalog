--!strict
--!optimize 2
--!native

local Types = require(script.Types)
local Version = require(script.Version)
local SearchImpl = require(script.Search)
local SortImpl = require(script.Sort)
local BoyerMoore = require(script.BoyerMoore)

export type Item = Types.Item
export type SearchParams = Types.SearchParams
export type CatalogData = Types.CatalogData
export type Predicate = Types.Predicate
export type SortDirection = Types.SortDirection
export type SortKey = Types.SortKey
export type SortOptions = Types.SortOptions

local Catalog = {}

Catalog.Version = Version
Catalog.BoyerMoore = BoyerMoore

function Catalog.new(indexedParameters: { string }?): CatalogData
	local indexed: { [string]: true }? = nil
	if indexedParameters then
		indexed = {}
		for _, parameter in indexedParameters do
			indexed[parameter] = true
		end
	end

	return {
		byId = {},
		index = {},
		indexed = indexed,
	}
end

local function indexItem(self: CatalogData, item: Item)
	local indexed = self.indexed
	for parameter, value in item.parameters do
		if indexed and not indexed[parameter] then
			continue
		end

		local byValue = self.index[parameter]
		if not byValue then
			byValue = {}
			self.index[parameter] = byValue
		end

		local ids = byValue[value]
		if not ids then
			ids = {}
			byValue[value] = ids
		end

		ids[item.id] = true
	end
end

local function deindexItem(self: CatalogData, item: Item)
	for parameter, value in item.parameters do
		local byValue = self.index[parameter]
		if not byValue then
			continue
		end

		local ids = byValue[value]
		if ids then
			ids[item.id] = nil
			if next(ids) == nil then
				byValue[value] = nil
			end
		end

		if next(byValue) == nil then
			self.index[parameter] = nil
		end
	end
end

function Catalog.AddToCatalog(self: CatalogData, item: Item)
	local existing = self.byId[item.id]
	if existing then
		deindexItem(self, existing)
	end

	self.byId[item.id] = item
	indexItem(self, item)
end

function Catalog.BulkAddToCatalog(self: CatalogData, items: { Item })
	for _, item in items do
		Catalog.AddToCatalog(self, item)
	end
end

function Catalog.RemoveFromCatalog(self: CatalogData, id: string): boolean
	local item = self.byId[id]
	if not item then
		return false
	end

	deindexItem(self, item)
	self.byId[id] = nil
	return true
end

function Catalog.BulkRemoveFromCatalog(self: CatalogData, ids: { string })
	for _, id in ids do
		Catalog.RemoveFromCatalog(self, id)
	end
end

function Catalog.Get(self: CatalogData, id: string): Item?
	return self.byId[id]
end

function Catalog.Has(self: CatalogData, id: string): boolean
	return self.byId[id] ~= nil
end

function Catalog.Search(self: CatalogData, params: SearchParams, sort: SortOptions?): { Item }
	local results = SearchImpl(self, params)
	if sort then
		SortImpl(results, sort)
	end
	return results
end

function Catalog.SearchText(self: CatalogData, parameter: string, pattern: string, sort: SortOptions?): { Item }
	local matcher = BoyerMoore.compile(pattern)
	local results: { Item } = {}

	for _, item in self.byId do
		local value = item.parameters[parameter]
		if type(value) == "string" and BoyerMoore.contains(matcher, value) then
			table.insert(results, item)
		end
	end

	if sort then
		SortImpl(results, sort)
	end
	return results
end

function Catalog.SearchCustom(self: CatalogData, predicate: Types.Predicate, sort: SortOptions?): { Item }
	local results: { Item } = {}
	for _, item in self.byId do
		if predicate(item) then
			table.insert(results, item)
		end
	end

	if sort then
		SortImpl(results, sort)
	end
	return results
end

function Catalog.Sort(items: { Item }, options: SortOptions): { Item }
	return SortImpl(items, options)
end

function Catalog.Destroy(self: CatalogData)
	table.clear(self.byId)
	table.clear(self.index)
end

return Catalog
