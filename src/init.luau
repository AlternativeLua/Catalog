--!strict
local Greeter = require(script.Greeter)
local Version = require(script.Version)

local Catalog = {}

Catalog.Version = Version

-- Re-export submodule functionality on the top-level table.
function Catalog.greet(name: string): string
	return Greeter.greet(name)
end

-- Also expose submodules directly for consumers that want them.
Catalog.Greeter = Greeter

return Catalog
