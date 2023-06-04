local function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then
                k = '"'..k..'"'
            end
            s = s .. '['..k..'] = ' .. dump(v) .. ', '
        end
        return s .. '}'
    else
        return tostring(o)
    end
end

function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

local lpeg = require("lpeg")
-- match
local peg_sign_match = lpeg.S("+-") ^ -1
local peg_hex_match = lpeg.P("0") * lpeg.S("xX") * lpeg.R("09", "af", "AF") ^ 1
local peg_dec_match = lpeg.R("19") ^ 1 * lpeg.R("09") ^ 0 + lpeg.P("0")
local peg_int_match = peg_sign_match * (peg_hex_match + peg_dec_match)
local peg_float_match = peg_sign_match * peg_dec_match * (lpeg.P(".") * lpeg.R("09") ^ 1) ^ -1 * (lpeg.S("eE") * peg_sign_match * peg_dec_match) ^ -1
local peg_num_match = peg_sign_match * (peg_hex_match + peg_dec_match * (lpeg.P(".") * lpeg.R("09") ^ 1) ^ -1 * (lpeg.S("eE") * peg_sign_match * peg_dec_match) ^ -1)
local peg_space_match = lpeg.S(" \n\t") ^ 0
local peg_var_match = lpeg.R("az", "AZ", "__") * lpeg.R("az", "AZ", "__", "09") ^ 0
local peg_func_match = peg_var_match

local function PegSpaceWrap(pattern) -- " pattern "
    return peg_space_match * pattern * peg_space_match
end

local function PegTupleWrap(pattern) -- "pattern,pattern,pattern"
    pattern = PegSpaceWrap(pattern)
    return pattern * (',' * pattern)^0
end

local peg_test = false

local function PegNumParse(pattern)
    if peg_test then
        return "n_" .. pattern
    end
    return { t = "num", val = tonumber(pattern), }
end

local function PegVarParse(pattern)
    if peg_test then
        return "v_" .. pattern
    end
    return { t = "var", val = pattern, }
end

local function PegBinaryOptParse(pattern)
    if peg_test then
        return "o_" .. pattern
    end
    return { t = "opt_bin", val = pattern, }
end

local function PegFuncParse(pattern)
    if peg_test then
        return "f_" .. pattern
    end
    return { t = "func", val = pattern, }
end

local function PegBinaryOptRP(pattern)
    return pattern / function (opt, right)
        return right, opt
    end
end

-- capture
local peg_num_capture = PegSpaceWrap(peg_num_match / PegNumParse)
local peg_var_capture = PegSpaceWrap(peg_var_match / PegVarParse)
local peg_func_capture = PegSpaceWrap(peg_func_match / PegFuncParse)
local peg_opt_term_capture = PegSpaceWrap(lpeg.S("+-") / PegBinaryOptParse)
local peg_opt_factor_capture = PegSpaceWrap(lpeg.S("*/%") / PegBinaryOptParse)

local peg_expression_parser = lpeg.P({
    "exp",
    exp = lpeg.V("term"),
    term = lpeg.Ct(lpeg.V("factor") * PegBinaryOptRP(peg_opt_term_capture * lpeg.V("factor")) ^ 1) + lpeg.V("factor"),
    factor = lpeg.Ct(lpeg.V("basic") * PegBinaryOptRP(peg_opt_factor_capture * lpeg.V("basic")) ^ 1) + lpeg.V("basic"),
    func = lpeg.Ct(peg_func_capture * "(" * peg_space_match * (PegTupleWrap(lpeg.V("exp") + peg_space_match)) * peg_space_match * ")"),
    basic = lpeg.V("func") + "(" * peg_space_match * lpeg.V("exp") * peg_space_match * ")" + peg_var_capture + peg_num_capture,
}) * -1

local tt = {"1 * 2 + 1", "1 + 2 * 1", "3 * (1 + 2)", "1234", "1234.6",
    " 12345 + 12345", "1 + 2 + 3", " 1 * 2 * 3 ", "1 * 2 * 3 / 4 * 5 / 6 * 7",
    "1 + 2 * max(3, 4, 5)",
    "1 + atk - def",
    "1 + 2 * max()",
    "atk",
}

for _, v in ipairs(tt) do
    local tmp = peg_expression_parser:match(v)
    print(v .. " -> " ..dump(tmp))
end

local PegExpFuncGenerate

local function PegExpBaseGenerate(exp_parse)
    if exp_parse.t ~= nil then
        if exp_parse.t == "num" or exp_parse.t == "var" then
            return tostring(exp_parse.val)
        else
            print("error3")
            return ""
        end
    else
        if #exp_parse < 1 then
            print("error4")
            return ""
        end
        if exp_parse[1].t == "func" then
            return PegExpFuncGenerate(exp_parse)
        end
        local tmp = {}
        for _, v in ipairs(exp_parse) do
            if v.t ~= nil then
                if v.t == "num" or v.t == "var" then
                    table.insert(tmp, tostring(v.val))
                elseif v.t == "opt_bin" then
                    if #tmp < 2 then
                        print("error6")
                        return ""
                    end
                    local v1 = tmp[#tmp - 1]
                    local v2 = tmp[#tmp]
                    tmp[#tmp - 1] = "(" .. v1 .. " " .. v.val .. " " .. v2 .. ")"
                    table.remove(tmp, #tmp)
                else
                    print("error5")
                    return ""
                end
            else
                table.insert(tmp, PegExpBaseGenerate(v))
            end
        end
        if #tmp ~= 1 then
            print("error7")
            return ""
        end
        return tmp[1]
    end
end

function PegExpFuncGenerate(exp_parse)
    local func_name = exp_parse[1].val
    local func_args = {}
    for i = 2, #exp_parse do
        table.insert(func_args, PegExpBaseGenerate(exp_parse[i]))
    end
    return func_name .. "(" .. table.concat(func_args, ", ") .. ")"
end

local function PegExpCodeGenerate(exp_parse)
    return PegExpBaseGenerate(exp_parse)
end

local function PegExpVarExtract(exp_parse, t)
    t = t or {}
    if exp_parse.t ~= nil then
        if exp_parse.t == "var" and not table.contains(t, exp_parse.val) then
            table.insert(t, exp_parse.val)
        end
    else
        for _, v in ipairs(exp_parse) do
            PegExpVarExtract(v, t)
        end
    end
    return t
end

local function PegExpAnalyze(formula)
    local formula_capture = lpeg.Ct((PegSpaceWrap(peg_var_match / tostring)) * "=" * lpeg.C(lpeg.P(1)^1)):match(formula)
    if #formula_capture ~= 2 or formula_capture[1] == nil or formula_capture[2] == nil then
        print("error1")
        return nil
    end
    local exp_parse = peg_expression_parser:match(formula_capture[2])
    if exp_parse == nil then
        print("error2")
        return nil
    end
    local name = formula_capture[1]
    local func_fmt = [[
local Calc_%s = function()
    return %s 
end
    ]]
    local vars = PegExpVarExtract(exp_parse)
    local exp_code = PegExpCodeGenerate(exp_parse)
    return name, vars, string.format(func_fmt, name, exp_code)
end

local bb = {
    "atk = 1 + 2 * 3 / (5 + 6) / (def + max(def2, 2) / maxhp)",
    "atk = def + 2 * 3 / (5 + 6) / (def + max(def, max(2,3)) / maxhp)",
}

for _, v in ipairs(bb) do
    local name, vars, code = PegExpAnalyze(v)
    print(v)
    print(name .. ", " .. dump(vars))
    print(code)
end