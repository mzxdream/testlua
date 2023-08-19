local function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then
                k = '"' .. k .. '"'
            end
            s = s .. '[' .. k .. '] = ' .. dump(v) .. ', '
        end
        return s .. '}'
    else
        return tostring(o)
    end
end

local function contains(table, val)
    for _, v in pairs(table) do
        if v == val then
            return true
        end
    end
    return false
end

local function error(fmt, ...)
    print(fmt, ...)
end

local tcontains = contains
local tconcat = table.concat
local strfmt = string.format

local lpeg = require("lpeg")
local P, S, R, V, C, Ct = lpeg.P, lpeg.S, lpeg.R, lpeg.V, lpeg.C, lpeg.Ct
---pattern
local signPatt = S("+-") ^ -1
local hexPatt = signPatt * P("0") * S("xX") * R("09", "af", "AF") ^ 1
local decPatt = signPatt * (R("19") ^ 1 * R("09") ^ 0 + P("0"))
local floatPatt = decPatt * (P(".") * R("09") ^ 1) ^ -1
local exponentPatt = floatPatt * (S("eE") * decPatt) ^ -1
local numPatt = hexPatt + exponentPatt
local spacePatt = S(" \n\t") ^ 0
local varPatt = R("az", "AZ", "__") * R("az", "AZ", "__", "09") ^ 0
local funcPatt = varPatt
local optTermPatt = S("+-")
local optFactorPatt = S("*/")

local function wrapSpacePatt(patt)
    return spacePatt * patt * spacePatt
end

local function wrapTuplePatt(patt)
    patt = wrapSpacePatt(patt)
    return patt * (',' * patt) ^ 0
end

local function parseNumPatt(patt)
    return { t = "num", val = patt, }
end

local function parseVarPatt(patt)
    return { t = "var", val = patt, }
end

local function parseFuncPatt(patt)
    return { t = "func", val = patt, }
end

local function parseBinaryOptPatt(patt)
    return { t = "opt_binary", val = patt, }
end

--local function parseNumPatt(patt)
--    return "n_" .. patt
--end
--
--local function parseVarPatt(patt)
--    return "v_" .. patt
--end
--
--local function parseFuncPatt(patt)
--    return "f_" .. patt
--end
--
--local function parseBinaryOptPatt(patt)
--    return "o_" .. patt
--end

---capture
local numCapture = wrapSpacePatt(numPatt / parseNumPatt)
local varCapture = wrapSpacePatt(varPatt / parseVarPatt)
local funcCapture = wrapSpacePatt(funcPatt / parseFuncPatt)
local optTermCapture = wrapSpacePatt(optTermPatt / parseBinaryOptPatt)
local optFactorCapture = wrapSpacePatt(optFactorPatt / parseBinaryOptPatt)

local expGrammar = P({
    "exp",
    exp = wrapSpacePatt(V("term")),
    term = Ct(V("factor") * (optTermCapture * V("factor")) ^ 1) + V("factor"),
    factor = Ct(V("basic") * (optFactorCapture * V("basic")) ^ 1) + V("basic"),
    func = Ct(funcCapture * "(" * (wrapTuplePatt(V("exp")) + spacePatt) * ")"),
    basic = V("func") + "(" * V("exp") * ")" + varCapture + numCapture,
}) * -1

local generateExpCode

local function generateFuncCode(expParser)
    local funcName = expParser[1].val
    local funcArgs = {}
    for i = 2, #expParser do
        local v = generateExpCode(expParser[i])
        if v == nil then
            return nil
        end
        table.insert(funcArgs, v)
    end
    return strfmt("%s(%s)", funcName, tconcat(funcArgs, ","))
end

local function generateTupleCode(expParser)
    if #expParser == 0 then
        error("exp parser is empty")
        return nil
    end
    local tmp = {}
    for _, v in ipairs(expParser) do
        local t, isTuple = generateExpCode(v)
        if t == nil then
            return nil
        end
        if isTuple then
            t = strfmt("(%s)", t)
        end
        table.insert(tmp, t)
    end
    return tconcat(tmp)
end

function generateExpCode(expParser)
    local t = expParser.t
    if t ~= nil then
        if t == "num" or t == "var" or t == "opt_binary" then
            return expParser.val
        end
        error("generate t is %s->%s not basic value", t, expParser.val)
        return nil
    end
    if #expParser == 0 then
        error("generate exp parser is empty")
        return nil
    end
    if expParser[1].t == "func" then
        return generateFuncCode(expParser)
    end
    return generateTupleCode(expParser), true
end

local function extractExpVars(expParser, vars)
    vars = vars or {}
    if expParser.t == "var" and not tcontains(vars, expParser.val) then
        table.insert(vars, expParser.val)
        return vars
    end
    for _, v in ipairs(expParser) do
        extractExpVars(v, vars)
    end
    return vars
end

local function analyzeExp(exp)
    local expArr = Ct(wrapSpacePatt(varPatt / tostring) * "=" * C(P(1) ^ 1)):match(exp)
    if expArr == nil or #expArr ~= 2 then
        error("analyze exp failed:%s", exp)
        return nil
    end
    local expParser = expGrammar:match(expArr[2])
    if expParser == nil then
        error("parse exp failed:%s", expArr[2])
        return nil
    end
    local expVars = extractExpVars(expParser)
    if expVars == nil then
        error("extract exp vars failed:%s", expArr[2])
        return nil
    end
    local expCode = generateExpCode(expParser)
    if expCode == nil then
        error("generate exp code failed:%s", expArr[2])
        return nil
    end
    return expArr[1], expVars, strfmt("return function() return %s end", expCode)
end

local bb = {
    "atk = 1 + 2 * 3 / (5 + 6) / (def + max(def2, 2) / maxhp)",
    "atk = def + 2 * 3 / (5 + 6) / (def + max(def,max(min(2,3),4) / maxhp))",
    "test = min(max(floor(1.111100), 2.30), 3.1)",
    "actuale_vasion_chance = (1 - evasion_chance) ",
    --[[
    --    actual_damage = magical_damage * (1 + magic_amplification) * (1 - innate_resistance) * (1 - magic_resistance_of_item) * (1 - magic_resistance_of_first_ability) * (1 - magic_resistance_of_second_ability)
    --]]
}

for _, v in ipairs(bb) do
    print("11111111111111111111111111111111111111111111111111111111111begin")
    print("formula: " .. v)
    local name, vars, code = analyzeExp(v)
    if name ~= nil then
        print("name = " .. name .. ", vars = " .. dump(vars))
        print("code = " .. code)
    end
    print("11111111111111111111111111111111111111111111111111111111111end")
end
--
--
--
----local def = 10
----local maxhp = 100
----local min = math.min
----local max = math.max
----
----local atk = def + 2 * 3 / (5 + 6) / (def + max(def,max(min(2,3),4) / maxhp))
----
----
----local Calc_atk = function()
----    return (def + (((2 * 3) / (5 + 6)) / (def + math.max(def, (math.max(math.min(2, 3), 4) / maxhp)))))
----end
----
----print("xxx:" .. tostring(atk))
----print("yyy:" .. tostring(Calc_atk()))
--io.write()
--
--local tt = {"1 * 2 + 1", "1 + 2 * 1", "3 * (1 + 2)", "1234", "1234.6",
--    " 12345 + 12345", "1 + 2 + 3", " 1 * 2 * 3 ", "1 * 2 * 3 / 4 * 5 / 6 * 7",
--    "1 + 2 * max(3, 4, 5)",
--    "1 + atk - def",
--    "1 + 2 * max()",
--    "atk",
--}
--
--for _, v in ipairs(tt) do
--    local tmp = expGrammar:match(v)
--    print(v .. " -> " ..dump(tmp))
--end
