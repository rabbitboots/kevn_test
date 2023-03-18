-- KEVN Tests.

--[[
Last tested: 2023-03-18

Fedora 37:
	Lua 5.1
	Lua 5.4
	LuaJIT 2.1.0-beta3
	LÖVE 11.4 (LuaJIT 2.1.0-beta3)
	LÖVE 12.0-Development (commit 9963d12) (LuaJIT 2.1.0-beta3)

Windows 10:
	Lua 5.1
	LÖVE 12.0-Development (commit c4aaab6) (LuaJIT 2.1.0-beta3)
--]]


-- Test libs
local inspect = require("demo_libs.inspect.inspect")
local strict = require("demo_libs.strict")


-- KEVN
local kevn = require("kevn.kevn")


local sep = "\n------------"


-- Print test results with inspect, or an error message if the test explicitly failed.
local function printOrErr(value, err)

	if type(value) == "string" then
		print(value)

	elseif type(value) == "table" then
		print(inspect(value))

	else
		print("Error! " .. err or "")
	end
end


-- Test variables
local tbl, err, str, tmp


print("\nTEST 1\n")
print("Just a barebones test. Create a group with some values, and also assign some values")
print("to the default group.\n")
tbl, err, str, tmp = nil, nil, nil, nil

str = [[
a_key_in=the_default_group
a=b

[foobar]
foo=bar
;for=bach
baz=bop

doop=1
]]

print("str2Table():")
tbl, err = kevn.str2Table(str)
printOrErr(tbl, err)
--[[
Should look like this (with varying order):
{
  [""] = {
    a = "b",
    a_key_in = "the_default_group"
  },
  foobar = {
    baz = "bop",
    doop = "1",
    foo = "bar"
  }
}
--]]

print("\ntable2Str():")

if tbl then
	local s2 = kevn.table2Str(tbl)
	
	print(s2)
	--[[
	Should look like this (with varying order):

	[foobar]
	doop=1
	baz=bop
	foo=bar
	--]]
end

print(sep)
print("\nTEST 2\n")
tbl, err, str, tmp = nil, nil, nil, nil

print("Use modifiers to convert group IDs, keys, and values during the parsing phase.")

-- Makes all group IDs upper-case.
local function fn_group2(tbl, grp_id)

	-- Note that string.upper() basically only handles single-byte UTF-8 characters (Basic Latin).
	-- Changing case in Unicode is beyond the scope of this demo.
	grp_id = string.upper(grp_id)

	return true, grp_id
end

-- Type conversions for values.
local bools = {
	["true"] = true,
	["false"] = false,
}
-- Implements some escape sequences for keys and values.
-- Format: &foo;
local escapes = {
	["eq"] = "=",
	["rsb"] = "]",
	["sc"] = ";",
	["dollar"] = "$",
	["lf"]= "\n",
}
local function numConvert(str)

	local num = string.match(str, "^(%d+)$") -- 0-9 only (no hex)
	if num then
		num = tonumber(num)
	end

	if num then
		return num
	end

	return str
end
local function fn_key2(tbl, group_id, key, value)

	local what
	key, what = string.gsub(key, "&([^;]+);", escapes)
	value = string.gsub(value, "&([^;]+);", escapes)

	if group_id == "BOOLS" then
		if bools[value] ~= nil then -- that pesky false...
			value = bools[value]
		end

	elseif group_id == "NUMBERS" then
		value = numConvert(value)
	end

	return true, key, value
end

print("\nGroup IDs should be upper-case. In [BOOLS], values should be converted to booleans.")

str = [[
[escapes]
&sc;=Semicolon
&eq;=Equal
&rsb;=Right Square Bracket
&dollar;=Dollar
&lf;=Line Feed

[bools]
true=true
false=false

[numbers]
one=1
two=2
three=3
four=4
]]

tbl, err = kevn.str2Table(str, fn_group2, fn_key2)
printOrErr(tbl, err)

print("\nOutput a KEVN string using Writer Functions.")

local lua_magic_chars = "^$()%.[]*+-?"
local lua_magic_lut = {}
for i = 1, #lua_magic_chars do
	local char = string.sub(lua_magic_chars, i, i)
	lua_magic_lut[char] = true
end

local escapes_rev = {}
for k, v in pairs(escapes) do
	if lua_magic_lut[v] then
		v = "%" .. v
	end
	escapes_rev[v] = "&" .. k .. ";"
end
-- Handle semicolon first
local rev_sc = escapes_rev[";"]
escapes_rev[";"] = nil

local function reverseEscape(str)

	str = string.gsub(str, ";", rev_sc)

	for k, v in pairs(escapes_rev) do
		str = string.gsub(str, k, v)
	end

	return str
end
local bools_rev = {[false] = "false", [true] = "true"}

tmp = {}
for grp_id, grp_t in pairs(tbl) do

	-- (Leave the group IDs upper-case.)

	kevn.appendGroupID(tmp, grp_id)

	for key, val in pairs(grp_t) do
		-- Undo type conversions and escapes in reverse order
		if grp_id == "NUMBERS" then
			if type(val) == "number" then
				val = tostring(val)
			end

		elseif grp_id == "BOOLS" then
			if bools_rev[val] ~= nil then
				val = bools_rev[val]
			end
		end

		key = reverseEscape(key)
		val = reverseEscape(val)

		kevn.appendKey(tmp, key, val)
	end
	kevn.appendEmpty(tmp, 1)
end

str = table.concat(tmp, "\n")
print(str)

-- Results should look like this, with varying order:
--[[
[ESCAPES]
&sc;=Semicolon
&lf;=Line Feed
&rsb;=Right Square Bracket
&dollar;=Dollar
&eq;=Equal

[BOOLS]
true=true
false=false

[NUMBERS]
one=1
four=4
three=3
two=2
--]]


print(sep)
print("\nTEST 3")
tbl, err, str, tmp = nil, nil, nil, nil

print("\nTest 'appendComment()' Writer Function. Each line should begin with")
print("a semicolon and space.\n")

tmp = {}
local comment_str = [[
https://www.gutenberg.org/ebooks/20034

"The news that, for several years at any rate, George Street, Edinburgh, was
haunted," wrote a correspondent of mine some short time ago, "might cause no
little surprise to many of its inhabitants." And my friend proceeded to relate
his experience of the haunting, which I will reproduce as nearly as possible in
his own words. I quote from memory, having foolishly destroyed the letter.

I was walking in a leisurely way along George Street the other day, towards
Strunalls, where I get my cigars, and had arrived opposite No. —, when I
suddenly noticed, just ahead of me, a tall lady of remarkably graceful figure,
clad in a costume which, even to an ignoramus in fashions like myself, seemed
extraordinarily out of date. In my untechnical language it consisted of a
dark blue coat and skirt, trimmed with black braid. The coat had a very high
collar, turned over to show a facing of blue velvet, its sleeves were very full
at the shoulders, and a band of blue velvet drew it tightly in at the waist.
Moreover, unlike every other lady I saw, she wore a small hat, which I
subsequently learned was a toque, with one white and one blue plume placed
moderately high at the side. The only other conspicuous items of her dress, the
effect of which was, on the whole, quiet, were white glacé gloves,—over which
dangled gold curb bracelets with innumerable pendants,—shoes, which were of
patent leather with silver buckles and rather high Louis heels, and fine, blue
silk openwork stockings. So much for her dress. Now for her herself. She was a
strikingly fair woman with very pale yellow hair and a startlingly white
complexion; and this latter peculiarity so impressed me that I hastened my
steps, determining to get a full view of her. Passing her with rapid strides, I
looked back, and as I did so a cold chill ran through me,—what I looked at was—
the face of the dead. I slowed down and allowed her to take the lead.]]
kevn.appendComment(tmp, comment_str)
str = table.concat(tmp, "\n")

printOrErr(str, err)


print("\nRun a few more tests to ensure the ad hoc 'while' loop is okay.")

print("\nEmpty string:")
tmp = {}
comment_str = ""
kevn.appendComment(tmp, comment_str)
str = table.concat(tmp, "\n")

printOrErr(str, err)


print("\nSingle line:")
tmp = {}
comment_str = "one two three four"
kevn.appendComment(tmp, comment_str)
str = table.concat(tmp, "\n")

printOrErr(str, err)


print("\nMultiple line feeds between content lines:")
tmp = {}
comment_str = "one\n\ntwo\n\nthree"
kevn.appendComment(tmp, comment_str)
str = table.concat(tmp, "\n")

printOrErr(str, err)


print("\nLeading, trailing line feeds:")
tmp = {}
comment_str = "\n\nA\n\nB\n\n"
kevn.appendComment(tmp, comment_str)
str = table.concat(tmp, "\n")

printOrErr(str, err)


print("\nOne lone line feed:")
tmp = {}
comment_str = "\n"
kevn.appendComment(tmp, comment_str)
str = table.concat(tmp, "\n")

printOrErr(str, err)


print(sep)
print("\nTEST 4\n")
tbl, err, str, tmp = nil, nil, nil, nil

print("\nTest all non-fatal errors in KEVN public functions. (See comments for fatal errors.)")


--kevn.str2Table(nil) -- #1 bad type
--kevn.str2Table("foo", 21) -- #2 bad type
--kevn.str2Table("foo", nil, "bar") -- #3 bad type


str = [=[
[trailing_group_text]!?
]=]
tbl, err = kevn.str2Table(str)
printOrErr(tbl, err)


str = [=[
[incomplete_group
]=]
tbl, err = kevn.str2Table(str)
printOrErr(tbl, err)


str = [=[
key_without_value
]=]
tbl, err = kevn.str2Table(str)
printOrErr(tbl, err)

--[[
Unable to test:
* Keys cannot begin with ';' or '[', or contain '=' or '\n'.

* Group IDs cannot contain ']'. The parser can't tell the difference between
  an embedded ']' and trailing junk at the end of the line.

* Group IDs cannot contain '\n' The parser thinks it's an incomplete group
  declaration.

Modifier callbacks are responsible for performing their own error checking.
--]]


-- 'kevn.table2Str()' is a wrapper for kevn.appendKey() and kevn.appendGroupID(), so it
-- should be covered by those tests for the most part.


--kevn.appendGroupID(false, "") -- #1 bad type
--kevn.appendGroupID({}, function() end) -- #2 bad type
--kevn.appendGroupID({}, "]") -- group IDs cannot contain ']' characters.
--kevn.appendGroupID({}, "grp\n") -- argument #2: string cannot contain line feeds (newlines).


--kevn.appendKey(false, "foo", "bar") -- #1 bad type
--kevn.appendKey({}, {}, "bar") -- #2 bad type
--kevn.appendKey({}, "f=o", "bar") -- keys cannot contain '=' characters.
--kevn.appendKey({}, ";foo", "bar") -- keys cannot contain ';' as their first character.
--kevn.appendKey({}, "f\no", "bar") -- argument #2: string cannot contain line feeds (newlines).
--kevn.appendKey({}, "foo", math.huge) -- #3 bad type
--kevn.appendKey({}, "foo", "b\nr") -- argument #3: string cannot contain line feeds (newlines).


--kevn.appendComment(false, "foo") -- #1 bad type
--kevn.appendComment({}, 987654321) -- #2 bad type

--kevn.appendEmpty(false, 1) -- #1 bad type
--kevn.appendEmpty({}, "foo") -- #2 bad type


print("\nEnd of tests.")

if rawget(_G, "love") then
	love.event.quit()
end
