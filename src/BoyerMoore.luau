--!strict
--!optimize 2
--!native

local byte = string.byte

export type Searcher = {
	pattern: string,
	m: number,
	pat: { number }, 
	last: { [number]: number },
	shift: { number }, 
}

local BoyerMoore = {}

local function compile(pattern: string): Searcher
	local m = #pattern

	local pat = {}
	for i = 1, m do
		pat[i - 1] = byte(pattern, i)
	end

	local last: { [number]: number } = {}
	for i = 0, m - 1 do
		last[pat[i]] = i
	end

	local bpos = {}
	local shift = {}
	for i = 0, m do
		shift[i] = 0
	end

	do
		local i = m
		local j = m + 1
		bpos[m] = j
		while i > 0 do
			while j <= m and pat[i - 1] ~= pat[j - 1] do
				if shift[j] == 0 then
					shift[j] = j - i
				end
				j = bpos[j]
			end
			i -= 1
			j -= 1
			bpos[i] = j
		end
	end

	do
		local j = bpos[0]
		for i = 0, m do
			if shift[i] == 0 then
				shift[i] = j
			end
			if i == j then
				j = bpos[j]
			end
		end
	end

	return {
		pattern = pattern,
		m = m,
		pat = pat,
		last = last,
		shift = shift,
	}
end

local function indexOf(searcher: Searcher, text: string, init: number?): number?
	local m = searcher.m
	local n = #text

	if m == 0 then
		return init or 1 
	end
	if m > n then
		return nil
	end

	local pat = searcher.pat
	local last = searcher.last
	local shift = searcher.shift

	local s = if init then math.max(init - 1, 0) else 0

	while s <= n - m do
		local j = m - 1
		while j >= 0 and pat[j] == byte(text, s + j + 1) do
			j -= 1
		end

		if j < 0 then
			return s + 1
		end

		local textByte = byte(text, s + j + 1)
		local badChar = j - (last[textByte] or -1)
		local goodSuffix = shift[j + 1]
		s += math.max(badChar, 1, goodSuffix)
	end

	return nil
end

local function find(searcher: Searcher, text: string): { number }
	local matches = {}
	local m = searcher.m
	local n = #text

	if m == 0 or m > n then
		return matches
	end

	local pat = searcher.pat
	local last = searcher.last
	local shift = searcher.shift
	local s = 0

	while s <= n - m do
		local j = m - 1
		while j >= 0 and pat[j] == byte(text, s + j + 1) do
			j -= 1
		end

		if j < 0 then
			table.insert(matches, s + 1)
			s += shift[0] 
		else
			local textByte = byte(text, s + j + 1)
			local badChar = j - (last[textByte] or -1)
			local goodSuffix = shift[j + 1]
			s += math.max(badChar, 1, goodSuffix)
		end
	end

	return matches
end

local function contains(searcher: Searcher, text: string): boolean
	return indexOf(searcher, text) ~= nil
end

BoyerMoore.compile = compile
BoyerMoore.indexOf = indexOf
BoyerMoore.find = find
BoyerMoore.contains = contains

function BoyerMoore.search(text: string, pattern: string): number?
	return indexOf(compile(pattern), text)
end

return BoyerMoore
