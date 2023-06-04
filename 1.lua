local lpeg = require("lpeg")

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

local function PegSpaceWrap(pattern)
    return peg_space_match * pattern * peg_space_match
end

local function PegTupleWrap(pattern)
    pattern = PegSpaceWrap(pattern)
    return pattern * (',' * pattern)^0
end

-- capture
local peg_num_capture = PegSpaceWrap(peg_num_match / tonumber)
local peg_opt_term_capture = PegSpaceWrap(lpeg.C(lpeg.S("+-")))
local peg_opt_factor_capture = PegSpaceWrap(lpeg.C(lpeg.S("*/%")))

print(peg_num_capture:match("    12345.000    "))
print(peg_opt_term_capture:match("  +-*/  "))
print(peg_opt_factor_capture:match(" * / + - "))
local d = table.pack(PegTupleWrap(peg_num_capture):match("12334 , 555, 666, 7777"))
print(d[3])