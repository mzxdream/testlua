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

local function PegSpaceWrap(pattern) -- " pattern "
    return peg_space_match * pattern * peg_space_match
end

local function PegOptWrap(pattern)
    return pattern / function (opt, right)
        return right, opt
    end
end

-- capture
local peg_num_capture = PegSpaceWrap(peg_num_match / tonumber)
local peg_var_capture = PegSpaceWrap(lpeg.C(peg_var_match))
local peg_opt_term_capture = PegSpaceWrap(lpeg.C(lpeg.S("+-")))
local peg_opt_factor_capture = PegSpaceWrap(lpeg.C(lpeg.S("*/%")))

local peg_expression_parser = lpeg.P({
    "exp",
    exp = lpeg.V("term"),
    term = lpeg.Ct(lpeg.V("factor") * PegOptWrap(peg_opt_term_capture * lpeg.V("factor")) ^ 1) + lpeg.V("factor"),
    factor = lpeg.Ct(lpeg.V("basic") * PegOptWrap(peg_opt_factor_capture * lpeg.V("basic")) ^ 1) + lpeg.V("basic"),
    basic = peg_num_capture + "(" * peg_space_match * lpeg.V("exp") * peg_space_match * ")",
})

local tt = {"1 * 2 + 1", "1 + 2 * 1", "3 * (1 + 2)", "1234", "1234.6", " 12345 + 12345", "1 + 2 + 3", " 1 * 2 * 3 ", "1 * 2 * 3 / 4 * 5 / 6 * 7"}
for _, v in ipairs(tt) do
    local tmp = peg_expression_parser:match(v)
    print(v .. " -> " ..dump(tmp))
end