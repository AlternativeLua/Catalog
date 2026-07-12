/// <reference types="@rbxts/types" />

declare namespace Catalog {
	/** Values a parameter can hold. */
	export type Value = string | number | boolean;

	/** The shape of an item's `parameters` table. */
	export type Parameters = Record<string, Value>;

	export interface Item<P extends Parameters = Parameters, D = unknown> {
		/** Unique id of this item within the catalog. */
		id: string;
		/** Searchable key/value pairs. */
		parameters: P;
		/** Optional payload carried along with the item; never searched or indexed. */
		data?: D;
	}

	export type SortDirection = "ascending" | "descending";

	export interface SortKey<P extends Parameters = Parameters> {
		parameter: keyof P & string;
		/** Defaults to "ascending". */
		direction?: SortDirection;
	}

	/** A single sort key, or an array of keys where earlier keys take priority. */
	export type SortOptions<P extends Parameters = Parameters> = SortKey<P> | ReadonlyArray<SortKey<P>>;

	/** Options for `SearchText`. */
	export interface TextSearchOptions<P extends Parameters = Parameters> {
		/** Match regardless of case (pattern and values are lowercased). Defaults to false. */
		caseInsensitive?: boolean;
		sort?: SortOptions<P>;
	}

	export type Predicate<P extends Parameters = Parameters, D = unknown> = (item: Item<P, D>) => boolean;

	/**
	 * A catalog instance created by `Catalog.new`. Treat this as opaque and
	 * pass it back into the `Catalog` functions; `byId` is exposed read-only
	 * for direct iteration over every item.
	 */
	export interface CatalogData<P extends Parameters = Parameters, D = unknown> {
		readonly byId: ReadonlyMap<string, Item<P, D>>;
	}

	/** Compiled Boyer-Moore matcher returned by `Catalog.BoyerMoore.compile`. */
	export interface Searcher {
		readonly pattern: string;
	}
}

declare const Catalog: {
	readonly Version: string;

	/** The Boyer-Moore substring matcher used by `SearchText`, usable standalone. */
	readonly BoyerMoore: {
		/** Compiles `pattern` into a reusable matcher. */
		compile(this: void, pattern: string): Catalog.Searcher;
		/** Returns the 1-based position of the first match at or after `init`, or undefined. */
		indexOf(this: void, searcher: Catalog.Searcher, text: string, init?: number): number | undefined;
		/** Returns the 1-based positions of every (non-overlapping-scan) match in `text`. */
		find(this: void, searcher: Catalog.Searcher, text: string): Array<number>;
		contains(this: void, searcher: Catalog.Searcher, text: string): boolean;
		/** One-shot compile + indexOf. Prefer compile/indexOf when reusing a pattern. */
		search(this: void, text: string, pattern: string): number | undefined;
	};

	/**
	 * Creates a catalog (compiles to `Catalog.new(...)`). Pass the parameter
	 * names you want indexed for fast equality search; omit the argument to
	 * index every parameter.
	 *
	 * Specify `P` (and optionally `D`) to get typed parameters and payloads:
	 * ```ts
	 * type ItemParams = { category: string; rarity: string; tier: number };
	 * const cat = new Catalog<ItemParams, { damage: number }>(["category", "rarity", "tier"]);
	 * ```
	 */
	new <P extends Catalog.Parameters = Catalog.Parameters, D = unknown>(
		indexedParameters?: ReadonlyArray<keyof P & string>,
	): Catalog.CatalogData<P, D>;

	/** Adds an item, replacing any existing item with the same id. */
	AddToCatalog<P extends Catalog.Parameters, D>(
		this: void,
		catalog: Catalog.CatalogData<P, D>,
		item: Catalog.Item<P, D>,
	): void;

	BulkAddToCatalog<P extends Catalog.Parameters, D>(
		this: void,
		catalog: Catalog.CatalogData<P, D>,
		items: ReadonlyArray<Catalog.Item<P, D>>,
	): void;

	/** Returns true if an item with `id` existed and was removed. */
	RemoveFromCatalog(this: void, catalog: Catalog.CatalogData<any, any>, id: string): boolean;

	BulkRemoveFromCatalog(this: void, catalog: Catalog.CatalogData<any, any>, ids: ReadonlyArray<string>): void;

	/**
	 * Sets a single parameter on an existing item, keeping the index in sync.
	 * Pass `undefined` to remove the parameter. Returns false if no item with
	 * `id` exists. Always use this (or `UpdateParameters`) instead of mutating
	 * `item.parameters` directly, which silently corrupts the index.
	 */
	SetParameter<P extends Catalog.Parameters, D, K extends keyof P & string>(
		this: void,
		catalog: Catalog.CatalogData<P, D>,
		id: string,
		parameter: K,
		value: P[K] | undefined,
	): boolean;

	/**
	 * Merge-updates several parameters on an existing item at once, keeping
	 * the index in sync. Returns false if no item with `id` exists.
	 */
	UpdateParameters<P extends Catalog.Parameters, D>(
		this: void,
		catalog: Catalog.CatalogData<P, D>,
		id: string,
		parameters: Partial<P>,
	): boolean;

	Get<P extends Catalog.Parameters, D>(
		this: void,
		catalog: Catalog.CatalogData<P, D>,
		id: string,
	): Catalog.Item<P, D> | undefined;

	Has(this: void, catalog: Catalog.CatalogData<any, any>, id: string): boolean;

	/**
	 * Equality search. Multiple parameters are AND-ed together. Indexed
	 * parameters resolve through the inverted index; non-indexed parameters
	 * are filtered linearly against those candidates (a full scan when no
	 * indexed parameter is present), so results are correct either way —
	 * indexing is purely a performance optimization.
	 */
	Search<P extends Catalog.Parameters, D>(
		this: void,
		catalog: Catalog.CatalogData<P, D>,
		params: Partial<P>,
		sort?: Catalog.SortOptions<P>,
	): Array<Catalog.Item<P, D>>;

	/**
	 * Substring search over a string parameter (Boyer-Moore, O(n) full scan).
	 * The last argument accepts either plain sort options or a
	 * `TextSearchOptions` table (`{ caseInsensitive?, sort? }`).
	 */
	SearchText<P extends Catalog.Parameters, D>(
		this: void,
		catalog: Catalog.CatalogData<P, D>,
		parameter: keyof P & string,
		pattern: string,
		options?: Catalog.SortOptions<P> | Catalog.TextSearchOptions<P>,
	): Array<Catalog.Item<P, D>>;

	/**
	 * Runs `predicate` against every item and returns the matches (O(n) scan).
	 * Use for conditions the index can't express: ranges, checks against
	 * `data`, OR logic.
	 */
	SearchCustom<P extends Catalog.Parameters, D>(
		this: void,
		catalog: Catalog.CatalogData<P, D>,
		predicate: Catalog.Predicate<P, D>,
		sort?: Catalog.SortOptions<P>,
	): Array<Catalog.Item<P, D>>;

	/** Sorts an item array in place and returns the same array. */
	Sort<P extends Catalog.Parameters, D>(
		this: void,
		items: Array<Catalog.Item<P, D>>,
		options: Catalog.SortOptions<P>,
	): Array<Catalog.Item<P, D>>;

	/** Clears every item and index from the catalog. */
	Destroy(this: void, catalog: Catalog.CatalogData<any, any>): void;
};

export = Catalog;
