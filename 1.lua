local lpeg = require("lpeg")

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

-- match
local peg_sign_match = lpeg.S("+-") ^ -1
local peg_hex_match = lpeg.P("0") * lpeg.S("xX") * lpeg.R("09", "af", "AF") ^ 1
local peg_dec_match = lpeg.R("19") ^ 1 * lpeg.R("09") ^ 0 + lpeg.P("0")
local peg_int_match = peg_sign_match * (peg_hex_match + peg_dec_match)
local peg_float_match = peg_sign_match * peg_dec_match * (lpeg.P(".") * lpeg.R("09") ^ 1) ^ -1 * (lpeg.S("eE") * peg_sign_match * peg_dec_match) ^ -1
local peg_num_match = peg_sign_match * (peg_hex_match + peg_dec_match * (lpeg.P(".") * lpeg.R("09") ^ 1) ^ -1 * (lpeg.S("eE") * peg_sign_match * peg_dec_match) ^ -1)
local peg_space_match = lpeg.S(" \n\t") ^ 0
local peg_letter_match = lpeg.R("az", "AZ") ^ 1
local peg_func_match = lpeg.P("min") + lpeg.P("max") + lpeg.P("ceil") + lpeg.P("floor")

local function PegSpaceWrap(pattern) -- " pattern "
    return peg_space_match * pattern * peg_space_match
end

local function PegTupleWrap(pattern) -- "pattern,pattern,pattern"
    pattern = PegSpaceWrap(pattern)
    return pattern * (',' * pattern)^0
end

local function PegOptPolishWrap(pattern)
    return pattern / function (left, opt, right)
        return opt, left, right
    end
end

-- capture
local peg_num_capture = PegSpaceWrap(peg_num_match / tonumber)
local peg_opt_term_capture = PegSpaceWrap(lpeg.C(lpeg.S("+-")))
local peg_opt_factor_capture = PegSpaceWrap(lpeg.C(lpeg.S("*/%")))

print(peg_num_capture:match("    12345.000    "))
print(peg_opt_term_capture:match("  +-*/  "))
print(peg_opt_factor_capture:match(" * / + - "))
local d = lpeg.Ct(PegTupleWrap(peg_num_capture)):match("12334 , 555, 666, 7777")
print(d[3])


local peg_factor_capture = lpeg.Ct(PegOptPolishWrap(peg_num_capture * peg_opt_factor_capture * peg_num_capture) + peg_num_capture)

local tt = {"1 * 2 + 1", "1234", "1234.6", " 12345 + 12345"}
for _, v in ipairs(tt) do
    local tmp = peg_factor_capture:match(v)
    print(v .. " -> " ..dump(tmp))
end