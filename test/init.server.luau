-- Runs in the dev place (dev.project.json) to smoke-test the library.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Catalog)

print("Catalog version:", Catalog.Version)
Catalog.greet("world")
