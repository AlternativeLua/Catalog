# Catalog
A fast library for searching a large group of items

## Usage

Install via wally: `catalog = "alternativelua/catalog@0.1.0"` or through releases

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

-- Direct lookup by id.
local item = Catalog.Get(cat, "sword_01")
local exists = Catalog.Has(cat, "sword_01")

-- Removal.
Catalog.RemoveFromCatalog(cat, "potion_01")
Catalog.BulkRemoveFromCatalog(cat, { "shield_01" })

-- Clear everything.
Catalog.Destroy(cat)
```

## Performance

Benchmarked on **100,000 items** (Catalog v0.1.0). Each item has `category`,
`rarity`, `tier`, and `name` parameters; `category`, `rarity`, and `tier` are
indexed. See [`test/init.server.luau`](test/init.server.luau) for the harness.

| Operation | Method | Time | Results |
| --- | --- | --- | --- |
| Build the catalog | `BulkAddToCatalog` (100k items) | **31.64 ms** total | — |
| Equality search, high-selectivity | `Search { tier = 42 }` | **0.0344 ms/op** | 1,000 |
| Equality search, low-selectivity | `Search { category = "weapon" }` | **0.6662 ms/op** | 20,000 |
| Equality search, intersection | `Search { category = "weapon", rarity = "legendary" }` | **0.7234 ms/op** | 4,000 |
| Substring search, matching | `SearchText(name, "sword")` | **22.6514 ms/op** | 20,000 |
| Substring search, no match | `SearchText(name, "<no match>")` | **16.1428 ms/op** | 0 |
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
- **Direct lookup** (`Get`) is a single hash-map read and effectively free
  (below timer resolution across 100k iterations).
