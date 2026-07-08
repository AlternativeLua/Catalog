--!strict
-- Example submodule. Add more files next to this one and require them from init.luau.

local Greeter = {}

function Greeter.greet(name: string): string
	local message = `Hello, {name}!`
	print(message)
	return message
end

return Greeter
