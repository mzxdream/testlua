local lpeg = require("lpeg")

-- Lexical Elements
local Space = lpeg.S(" \n\t")^0
local Number = lpeg.C(lpeg.P"-"^-1 * lpeg.R("09")^1) * Space
local TermOp = lpeg.C(lpeg.S("+-")) * Space
local FactorOp = lpeg.C(lpeg.S("*/")) * Space
local Open = "(" * Space
local Close = ")" * Space

-- Grammar
local Exp, Term, Factor = lpeg.V"Exp", lpeg.V"Term", lpeg.V"Factor"
G = lpeg.P{ Exp,
  Exp = lpeg.Ct(Term * (TermOp * Term)^0);
  Term = lpeg.Ct(Factor * (FactorOp * Factor)^0);
  Factor = Number + Open * Exp * Close;
}

G = Space * G * -1

-- Evaluator
function eval (x)
  if type(x) == "string" then
    return tonumber(x)
  else
    local op1 = eval(x[1])
    for i = 2, #x, 2 do
      local op = x[i]
      local op2 = eval(x[i + 1])
      if (op == "+") then op1 = op1 + op2
      elseif (op == "-") then op1 = op1 - op2
      elseif (op == "*") then op1 = op1 * op2
      elseif (op == "/") then op1 = op1 / op2
      end
    end
    return op1
  end
end

-- Parser/Evaluator
function evalExp (s)
  local t = lpeg.match(G, s)
  if not t then error("syntax error", 2) end
  return eval(t)
end

-- small example
--print(evalExp"3 + 5*9 / (1+1) - 12")   --> 13.5

local function serialize(t)
  local serializedValues = {}
  local value, serializedValue
  for i=1,#t do
    value = t[i]
    serializedValue = type(value)=='table' and serialize(value) or value
    table.insert(serializedValues, serializedValue)
  end
  return string.format("{ %s }", table.concat(serializedValues, ', ') )
end

print(serialize(lpeg.match(G, "3 + 5*9 / (1+1) - 12")))
--local t = {"0", "0x111", "123456", "0123456", "0", "BB", "0xFF"}
--for _, v in ipairs(t) do
--    print(tostring(v).. " -> " .. tostring((peg_int / tonumber):match(v)))
--    print(tostring(v).. " -> " .. tostring((peg_num / tonumber):match(v)))
--end
--
--local t2 = {"0.1E-1E", "0.1E-1", "0.1E-2", "1E-2", "1E2", "1.0E2"}
--for _, v in ipairs(t2) do
--    print(tostring(v).. " -> " .. tostring((peg_float / tonumber):match(v)))
--    print(tostring(v).. " -> " .. tostring((peg_num / tonumber):match(v)))
--end
