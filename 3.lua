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

local lpeg = require("lpeg")
local P, S, R = lpeg.P, lpeg.S, lpeg.R
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

local function parseNumPatt(patt)
    return "n_" .. patt
end

local function parseVarPatt(patt)
    return "v_" .. patt
end

local function parseFuncPatt(patt)
    return "f_" .. patt
end

local function parseBinaryOptPatt(patt)
    return "o_" .. patt
end

---capture
local numCapture = wrapSpacePatt(numPatt / parseNumPatt)
local varCapture = wrapSpacePatt(varPatt / parseVarPatt)
local funcCapture = wrapSpacePatt(funcPatt / parseFuncPatt)
local optTermCapture = wrapSpacePatt(optTermPatt / parseBinaryOptPatt)
local optFactorCapture = wrapSpacePatt(optFactorPatt / parseBinaryOptPatt)

local expGrammar = lpeg.P({
    "exp",
    exp = wrapSpacePatt(lpeg.V("term")),
    term = lpeg.Ct(lpeg.V("factor") * (optTermCapture * lpeg.V("factor")) ^ 1) + lpeg.V("factor"),
    factor = lpeg.Ct(lpeg.V("basic") * (optFactorCapture * lpeg.V("basic")) ^ 1) + lpeg.V("basic"),
    func = lpeg.Ct(funcCapture * "(" * (wrapTuplePatt(lpeg.V("exp")) + spacePatt) * ")"),
    basic = lpeg.V("func") + "(" * lpeg.V("exp") * ")" + varCapture + numCapture,
}) * -1

local tt = {"1 * 2 + 1", "1 + 2 * 1", "3 * (1 + 2)", "1234", "1234.6",
    " 12345 + 12345", "1 + 2 + 3", " 1 * 2 * 3 ", "1 * 2 * 3 / 4 * 5 / 6 * 7",
    "1 + 2 * max(3, 4, 5)",
    "1 + atk - def",
    "1 + 2 * max()",
    "atk",
}

for _, v in ipairs(tt) do
    local tmp = expGrammar:match(v)
    print(v .. " -> " ..dump(tmp))
end
--
--local PegExpFuncGenerate
--
--local function PegExpBaseGenerate(exp_parse)
--    if exp_parse.t ~= nil then
--        if exp_parse.t == "num" or exp_parse.t == "var" then
--            return tostring(exp_parse.val)
--        else
--            print("error3")
--            return ""
--        end
--    else
--        if #exp_parse < 1 then
--            print("error4")
--            return ""
--        end
--        if exp_parse[1].t == "func" then
--            return PegExpFuncGenerate(exp_parse)
--        end
--        local tmp = {}
--        for _, v in ipairs(exp_parse) do
--            if v.t ~= nil then
--                if v.t == "num" or v.t == "var" then
--                    table.insert(tmp, tostring(v.val))
--                elseif v.t == "opt_bin" then
--                    if #tmp < 2 then
--                        print("error6")
--                        return ""
--                    end
--                    local v1 = tmp[#tmp - 1]
--                    local v2 = tmp[#tmp]
--                    tmp[#tmp - 1] = "(" .. v1 .. " " .. v.val .. " " .. v2 .. ")"
--                    table.remove(tmp, #tmp)
--                else
--                    print("error5")
--                    return ""
--                end
--            else
--                table.insert(tmp, PegExpBaseGenerate(v))
--            end
--        end
--        if #tmp ~= 1 then
--            print("error7")
--            return ""
--        end
--        return tmp[1]
--    end
--end
--
--function PegExpFuncGenerate(exp_parse)
--    local func_name = exp_parse[1].val
--    local func_args = {}
--    for i = 2, #exp_parse do
--        table.insert(func_args, PegExpBaseGenerate(exp_parse[i]))
--    end
--    return func_name .. "(" .. table.concat(func_args, ", ") .. ")"
--end
--
--local function PegExpCodeGenerate(exp_parse)
--    return PegExpBaseGenerate(exp_parse)
--end
--
--local function PegExpVarExtract(exp_parse, t)
--    t = t or {}
--    if exp_parse.t ~= nil then
--        if exp_parse.t == "var" and not table.contains(t, exp_parse.val) then
--            table.insert(t, exp_parse.val)
--        end
--    else
--        for _, v in ipairs(exp_parse) do
--            PegExpVarExtract(v, t)
--        end
--    end
--    return t
--end
--
--local function PegExpAnalyze(formula)
--    local formula_capture = lpeg.Ct((PegSpaceWrap(peg_var_match / tostring)) * "=" * lpeg.C(lpeg.P(1)^1)):match(formula)
--    if formula_capture == nil or formula_capture[1] == nil or formula_capture[2] == nil then
--        print("error1")
--        return nil
--    end
--    local exp_parse = peg_expression_parser:match(formula_capture[2])
--    if exp_parse == nil then
--        print("error2")
--        return nil
--    end
--    local name = formula_capture[1]
--    local func_fmt = [[
--local Calc_%s = function()
--    return %s
--end
--    ]]
--    local vars = PegExpVarExtract(exp_parse)
--    local exp_code = PegExpCodeGenerate(exp_parse)
--    return name, vars, string.format(func_fmt, name, exp_code)
--end
--
--local bb = {
--    "atk = 1 + 2 * 3 / (5 + 6) / (def + max(def2, 2) / maxhp)",
--    "atk = def + 2 * 3 / (5 + 6) / (def + max(def,max(min(2,3),4) / maxhp))",
--    "test = min(max(floor(1.111100), 2.30), 3.1)",
--    "actuale_vasion_chance = (1 - evasion_chance) ",
--    --[[
--    --    actual_damage = magical_damage * (1 + magic_amplification) * (1 - innate_resistance) * (1 - magic_resistance_of_item) * (1 - magic_resistance_of_first_ability) * (1 - magic_resistance_of_second_ability)
--    --]]
--}
--
--for _, v in ipairs(bb) do
--    print("11111111111111111111111111111111111111111111111111111111111begin")
--    print("formula: " .. v)
--    local name, vars, code = PegExpAnalyze(v)
--    if name ~= nil then
--        print("name = " .. name .. ", vars = " .. dump(vars))
--        print("code = ")
--        print(code)
--    end
--    print("11111111111111111111111111111111111111111111111111111111111end")
--end
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
