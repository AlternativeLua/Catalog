--!strict
export type Value = string | number | boolean
export type Parameters = { [string]: Value }

export type Item = {
	id: string,
	parameters: Parameters,
	data: any?,
}

export type SearchParams = { [string]: Value }

export type SortDirection = "ascending" | "descending"

export type SortKey = {
	parameter: string,
	direction: SortDirection?,
}

export type SortOptions = SortKey | { SortKey }

export type Predicate = (item: Item) -> boolean

export type CatalogData = {
	byId: PrimaryIndex,
	index: InvertedIndex,
	indexed: { [string]: true }?,
}
export type PrimaryIndex = { [string]: Item }
export type InvertedIndex = { [string]: { [Value]: { [string]: true } } }

return {}
