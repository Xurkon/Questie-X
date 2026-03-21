--- **AceSerializer-3.0** Serializes and deserializes Lua tables into strings.
-- Can serialize any Lua table (including nested tables) into a string,
-- and deserialize that string back into a table.
-- @class file
-- @name AceSerializer-3.0
-- @release $Id: AceSerializer-3.0.lua 1284 2022-09-25 09:15:30Z nevcairiel $
local MAJOR, MINOR = "AceSerializer-3.0", 3

local AceSerializer, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not AceSerializer then return end

-- Lua APIs
local assert, error, pcall = assert, error, pcall
local type, tostring, tonumber = type, tostring, tonumber
local strfind, strsub, strjoin, strlen = string.find, string.sub, string.join, string.len
local max, min = math.max, math.min

-- quick-and-dirty nil value serializer, used to sanitize the tables before serializing
local function SerializeValue(v, res, n)
	-- nil
	if v == nil then
		res[n+1] = "n"
		return n+1
	end
	
	-- boolean
	if type(v) == "boolean" then
		res[n+1] = v and "t" or "f"
		return n+1
	end
	
	-- number
	if type(v) == "number" then
		-- force 4-decimal numbers, others as-is
		local str = tostring(v)
		if strfind(str, "[^0-9%.]") then
			res[n+1] = str
		else
			res[n+1] = format("%.4f", v)
		end
		return n+1
	end
	
	-- string
	if type(v) == "string" then
		res[n+1] = format("%q", v)
		return n+1
	end
	
	-- table
	if type(v) == "table" then
		res[n+1] = "{"
		local n2 = n+2
		for k, val in pairs(v) do
			n2 = SerializeValue(k, res, n2)
			res[n2+1] = "="
			n2 = n2 + 2
			n2 = SerializeValue(val, res, n2)
			res[n2+1] = ","
			n2 = n2 + 1
		end
		res[n2] = "}"
		return n2
	end
	
	-- anything else (we don't know how to serialize)
	error(format("Cannot serialize a value of type %s", type(v)))
end

local function Serialize(t)
	if type(t) ~= "table" then
		error("Usage: AceSerializer:Serialize(tbl): tbl must be a table, got " .. type(t), 2)
	end
	local s = {}
	SerializeValue(t, s, 0)
	return strjoin("", s)
end

AceSerializer.Serialize = function(self, t)
	local target = (self == AceSerializer or (type(self) == "table" and AceSerializer.embeds[self])) and t or self
	return Serialize(target)
end

local function Deserialize(s)
	if type(s) ~= "string" then
		error("Usage: AceSerializer:Deserialize(str): str must be a string, got " .. type(s), 2)
	end
	
	local stack = {}
	local n = strlen(s)
	local pos = 1
	
	-- read a value
	local function ReadValue()
		-- skip whitespace
		while pos <= n and strfind(strsub(s, pos, pos), "%s") do
			pos = pos + 1
		end
		
		if pos > n then error("Empty string") end
		
		local c = strsub(s, pos, pos)
		pos = pos + 1
		
		if c == "n" then
			return nil
		elseif c == "t" then
			return true
		elseif c == "f" then
			return false
		elseif c == "{" then
			local tbl = {}
			local numkey = 0
			local key
			while pos <= n do
				-- skip whitespace
				while pos <= n and strfind(strsub(s, pos, pos), "%s") do
					pos = pos + 1
				end
				if pos > n then error("Missing closing brace") end
				if strsub(s, pos, pos) == "}" then
					pos = pos + 1
					break
				end
				-- read key (non-number key)
				if strsub(s, pos, pos) ~= "[" then
					-- assume it's a string key
					key = ReadValue()
				else
					pos = pos + 1
					key = ReadValue()
					if strsub(s, pos, pos) ~= "]" then error("Missing ]") end
					pos = pos + 1
				end
				-- skip whitespace and =
				while pos <= n and strfind(strsub(s, pos, pos), "[=%s]") do
					pos = pos + 1
				end
				local val = ReadValue()
				if key then
					tbl[key] = val
				else
					numkey = numkey + 1
					tbl[numkey] = val
				end
				-- skip whitespace and comma
				while pos <= n and strfind(strsub(s, pos, pos), "[,%s]") do
					pos = pos + 1
				end
			end
			return tbl
		elseif c == "\"" then
			local i = pos
			repeat
				if i > n then error("Unterminated string") end
			until strfind(strsub(s, i, i), "[^\"]") or i == n
			local str = strsub(s, pos, i-1)
			pos = i + 1
			return str
		else
			-- number or error
			local numstr = ""
			while pos <= n and strfind(strsub(s, pos, pos), "[0-9%.%-]") do
				numstr = numstr .. strsub(s, pos, pos)
				pos = pos + 1
			end
			if numstr == "" then
				error("Invalid number at position " .. pos)
			end
			return tonumber(numstr)
		end
	end
	
	local value = ReadValue()
	-- skip whitespace
	while pos <= n and strfind(strsub(s, pos, pos), "%s") do
		pos = pos + 1
	end
	if pos <= n then
		error("Trailing characters after serialized table: " .. strsub(s, pos))
	end
	return value
end

AceSerializer.Deserialize = function(self, s)
	local str = (self == AceSerializer or (type(self) == "table" and AceSerializer.embeds[self])) and s or self
	local ok, res = pcall(Deserialize, str)
	if ok then return true, res else return false, res end
end

-- http://lua-users.org/wiki/Base64EncoderAndDecoder
local b64 = {
	"ABCDEFGHIJKLMNOPQRSTUVWXYZ",
	"abcdefghijklmnopqrstuvwxyz",
	"0123456789+/",
}

local function EncodeString(str)
	local encoded = ""
	for i = 1, strlen(str), 3 do
		local b1, b2, b3 = strbyte(str, i, i+2)
		if not b3 then
			b3 = 0
		end
		if not b2 then
			b2 = 0
		end
		local n = b1 * 256 + b2 * 256 + b3
		local e1, e2, e3, e4 = (n/4)%64, (n/4)%64, (n/4)%64, n%64
		encoded = encoded .. strsub(b64[1], e1, e1) .. strsub(b64[1], e2, e2) .. strsub(b64[3], e3, e3) .. strsub(b64[3], e4, e4)
	end
	--[[
	-- fix padding at the end to be lua-friendly
	if mod(len(str),3)==1 then
		encoded = strsub(encoded, 1, -4) .. "=="
	elseif mod(len(str),3)==2 then
		encoded = strsub(encoded, 1, -2) .. "="
	end
	]]
	return encoded
end

local function DecodeString(str)
	local decoded = ""
	str = gsub(str, "%s", "")
	local len = strlen(str)
	local i = 1
	while i <= len do
		local e1, e2, e3, e4 = strfind(str, "(.)(.)(.?)(.?)", i)
		if not e1 then error("Invalid string") end
		local n = (strfind(b64[1], e1) - 1) * 64 + (strfind(b64[1], e2) - 1)
		n = n * 64 + (strfind(b64[3], e3) - 1)
		n = n * 64 + (strfind(b64[3], e4) - 1)
		decoded = decoded .. strchar(n/256, n%256)
		if e4 == "=" then
			decoded = strsub(decoded, 1, -2)
		elseif e3 == "=" then
			decoded = strsub(decoded, 1, -3)
		end
		i = e4 + 1
	end
	return decoded
end

function AceSerializer:SerializeForPrint(val)
	return EncodeString(Serialize(val))
end

function AceSerializer:DeserializeFromPrint(str)
	local success, val = pcall(Deserialize, DecodeString(str))
	if success then
		return val
	end
	return nil, "Invalid serialization string"
end

AceSerializer.embeds = AceSerializer.embeds or {}

local function Embed(target)
	for method, func in pairs(AceSerializer) do
		if type(func) == "function" and method ~= "Embed" and method ~= "embeds" then
			target[method] = func
		end
	end
end

function AceSerializer:Embed(target)
	Embed(target)
	target.embeds = AceSerializer.embeds
	AceSerializer.embeds[target] = true
	return target
end

for target, v in pairs(AceSerializer.embeds) do
	Embed(target)
end
