# Catalog
A fast library for searching a large group of items

## Installation

- **Wally (Luau):** `catalog = "alternativelua/catalog@0.3.0"` or through releases
- **npm (roblox-ts):** `npm install @rbxts/catalog`

## Usage

```luau
local Catalog = require(ReplicatedStorage.Catalog)

-- Create a catalog. Pass the parameters you want indexed for fast equality
-- search; omit the argument to index every parameter.
local cat = Catalog.new({ "category", "rarity", "tier" })

-- Add items. Each item needs a unique `id` and a `parameters` table.
-- The optional `data` field holds any payload you want to carry along.
Catalog.AddToCatalog(cat, {
	id = "sword_01",
	parameters = { category = "weapon", rarity = "legendary", tier = 42 },
	data = { damage = 120 },
})

-- Or add many at once.
Catalog.BulkAddToCatalog(cat, {
	{ id = "shield_01", parameters = { category = "armor", rarity = "rare", tier = 12 } },
	{ id = "potion_01", parameters = { category = "consumable", rarity = "common", tier = 3 } },
})

-- Equality search over indexed parameters (fast, inverted index).
-- Multiple parameters are AND-ed together.
local legendaryWeapons = Catalog.Search(cat, { category = "weapon", rarity = "legendary" })

-- Substring search over a string parameter (Boyer-Moore, full scan).
local swords = Catalog.SearchText(cat, "name", "sword")

-- Sort results by passing sort options as the last argument to either
-- search function. Direction defaults to "ascending".
local byTier = Catalog.Search(cat, { category = "weapon" }, { parameter = "tier", direction = "descending" })

-- Multi-key sort: pass an array of keys; earlier keys take priority.
local ranked = Catalog.Search(cat, { category = "weapon" }, {
	{ parameter = "rarity" },
	{ parameter = "tier", direction = "descending" },
})

-- Or sort any item array in place directly.
Catalog.Sort(swords, { parameter = "name" })

-- Custom search: supply your own predicate for conditions the index can't
-- express (ranges, checks against `data`, etc.). O(n) scan, sort optional.
local hardHitters = Catalog.SearchCustom(cat, function(item)
	return item.parameters.category == "weapon" and item.data ~= nil and item.data.damage > 100
end, { parameter = "tier", direction = "descending" })

-- Direct lookup by id.
local item = Catalog.Get(cat, "sword_01")
local exists = Catalog.Has(cat, "sword_01")

-- Removal.
Catalog.RemoveFromCatalog(cat, "potion_01")
Catalog.BulkRemoveFromCatalog(cat, { "shield_01" })

-- Clear everything.
Catalog.Destroy(cat)
```

## roblox-ts

The npm package ships the same Luau source with TypeScript typings. Type the
parameters (and optionally the `data` payload) when creating a catalog and
every search, sort key, and result is checked against them:

```ts
import Catalog from "@rbxts/catalog";

type ItemParams = { category: string; rarity: string; tier: number; name: string };
type ItemData = { damage: number };

// `new Catalog(...)` compiles to `Catalog.new(...)`.
const cat = new Catalog<ItemParams, ItemData>(["category", "rarity", "tier"]);

Catalog.AddToCatalog(cat, {
	id: "sword_01",
	parameters: { category: "weapon", rarity: "legendary", tier: 42, name: "Sword" },
	data: { damage: 120 },
});

// Typed: `{ categry: "weapon" }` or `{ tier: "42" }` are compile errors.
const legendaryWeapons = Catalog.Search(cat, { category: "weapon", rarity: "legendary" });

// Sort keys are constrained to keyof ItemParams.
const ranked = Catalog.Search(cat, { category: "weapon" }, [
	{ parameter: "rarity" },
	{ parameter: "tier", direction: "descending" },
]);

// `item.data` is typed as ItemData | undefined.
const hardHitters = Catalog.SearchCustom(cat, (item) => item.data !== undefined && item.data.damage > 100);
```

## Performance

Benchmarked on **100,000 items** (Catalog v0.1.0). Each item has `category`,
`rarity`, `tier`, and `name` parameters; `category`, `rarity`, and `tier` are
indexed. See [`test/init.server.luau`](test/init.server.luau) for the harness.

| Operation | Method | Time | Results |
| --- | --- | --- | --- |
| Build the catalog | `BulkAddToCatalog` (100k items) | **29.42 ms** total | — |
| Equality search, high-selectivity | `Search { tier = 42 }` | **0.0372 ms/op** | 1,000 |
| Equality search, low-selectivity | `Search { category = "weapon" }` | **0.7400 ms/op** | 20,000 |
| Equality search, intersection | `Search { category = "weapon", rarity = "legendary" }` | **0.7422 ms/op** | 4,000 |
| Substring search, matching | `SearchText(name, "sword")` | **22.6112 ms/op** | 20,000 |
| Substring search, no match | `SearchText(name, "<no match>")` | **15.0984 ms/op** | 0 |
| Custom search, predicate | `SearchCustom(tier >= 90)` | **12.4424 ms/op** | 10,000 |
| Sorted search, single key | `Search { category = "weapon" }` + sort `tier` desc | **10.2109 ms/op** | 20,000 |
| Sorted search, multi-key | `Search { category = "weapon" }` + sort `rarity`, `tier` desc | **12.5169 ms/op** | 20,000 |
| Direct lookup by id | `Get("item_50000")` | **~0.0000 ms/op** | — |

### Notes

- **Equality search** uses an inverted index, so cost scales with the number of
  *matching* items, not the catalog size. Multi-parameter queries intersect on
  the smallest result set first, which is why `weapon + legendary` (4,000 hits)
  runs about as fast as `weapon` alone despite the extra filter.
- **Substring search** (`SearchText`) is a Boyer-Moore, O(n) scan over every
  item, since arbitrary substrings can't be indexed. The no-match case is
  slightly faster because it never allocates result entries; both cases visit
  all 100k items.
- **Custom search** (`SearchCustom`) calls the predicate once per item, so it
  is also an O(n) scan; cost is the scan plus whatever the predicate does.
- **Sorted search** adds the sort cost on top of the search: sorting the
  20,000 `weapon` hits by `tier` costs about 9.5 ms over the 0.74 ms unsorted
  search, and the two-key sort about 11.8 ms. Cost scales with the *result*
  count, not the catalog size.
- **Direct lookup** (`Get`) is a single hash-map read and effectively free
  (below timer resolution across 100k iterations).

## Sorting

Both `Search` and `SearchText` accept optional sort options as their last
argument, and `Catalog.Sort(items, options)` sorts any `{ Item }` array in
place (returning the same array). Options are a single key or an array of
keys, each `{ parameter: string, direction: "ascending" | "descending"? }`.

Ordering rules:

- Values of the same type compare naturally (`<` for numbers and strings,
  `false` before `true` for booleans).
- Mixed types order `boolean < number < string`.
- Items missing the parameter always sort last, regardless of direction.
- Ties fall back to comparing `id`, so output order is deterministic.

Sorting extracts each item's key values once up front, so the comparator runs
on flat arrays instead of hashing into `item.parameters` on every comparison.
When a key's values are uniformly numbers or strings with none missing, a raw
`<` fast path is used. Compared to a naive `table.sort` comparator this is
roughly 2–3.5x faster for single-key sorts and 1.4–2x for multi-key.

## Custom search

`Catalog.SearchCustom(cat, predicate, sort?)` runs your own
`(item) -> boolean` function against every item and returns the matches. Use
it for anything the inverted index can't answer: range checks, conditions on
the `data` payload, or combinations with OR logic. Like `SearchText` it is an
O(n) scan over the whole catalog, so prefer `Search` when plain equality on
indexed parameters is enough.
