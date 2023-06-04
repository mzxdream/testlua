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

local function PegNumParse(pattern)
    --return {
    --    t = "number",
    --    val = tonumber(pattern),
    --}
    return "n_" .. pattern
end

local function PegVarParse(pattern)
    return "v_" .. pattern
    --return {
    --    t = "var",
    --    val = pattern,
    --}
end

local function PegBinaryOptParse(pattern)
    return "o_" .. pattern
    --return {
    --    t = "operator",
    --    val = pattern,
    --}
end

local function PegFuncParse(pattern)
    return "f_" .. pattern
    --return {
    --    t = "function",
    --    val = pattern,
    --}
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
}

for _, v in ipairs(tt) do
    local tmp = peg_expression_parser:match(v)
    print(v .. " -> " ..dump(tmp))
end

local function PegExpressionGenerate(formula)
    local formula_capture = lpeg.Ct((PegSpaceWrap(peg_var_match / tostring)) * "=" * lpeg.C(lpeg.P(1)^1)):match(formula)
    if #formula_capture ~= 2 or formula_capture[1] == nil or formula_capture[2] == nil then
        print("error")
        return nil
    end
    local name = formula_capture[1]
    local exp = formula_capture[2]

    return name, exp
end

local bb = {
    "atk = 1 + 2 * 3 / (5 + 6)",
}

for _, v in ipairs(bb) do
    local name, exp = PegExpressionGenerate(v)
    print(v .. " -> " .. name .. ", " .. exp)
end