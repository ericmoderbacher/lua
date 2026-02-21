-- Benchmark: function calls, closures, coroutines, strings, GC
-- Tests overhead of Lua's higher-level features.

package.path = package.path .. ";./benchmarks/?.lua"
local B = require("bench_util")

local N = 2e6


B.section("Function Calls")

-- Direct function call (global)
do
  local function f(x) return x + 1 end
  local n = N * 4
  local t = B.time(function()
    local sum = 0
    for i = 1, n do sum = f(sum) end
  end)
  B.report("call_local_fn", n, t)
end

-- Method call (colon syntax, table lookup + call)
do
  local obj = {}
  function obj:add(x) self.v = (self.v or 0) + x end
  local n = N * 2
  local t = B.time(function()
    obj.v = 0
    for i = 1, n do obj:add(i) end
  end)
  B.report("method_call", n, t)
end

-- Closure creation + immediate call
do
  local n = N
  local t = B.time(function()
    local sum = 0
    for i = 1, n do
      local f = function() return i * 2 end
      sum = sum + f()
    end
  end)
  B.report("closure_create_call", n, t)
end

-- Variadic function (... handling)
do
  local function sum(...)
    local s = 0
    for i = 1, select("#", ...) do s = s + select(i, ...) end
    return s
  end
  local n = N
  local t = B.time(function()
    local total = 0
    for i = 1, n do total = total + sum(i, i+1, i+2) end
  end)
  B.report("variadic_3arg", n, t)
end

-- Recursive Fibonacci (measures call/return overhead)
do
  local function fib(n)
    if n < 2 then return n end
    return fib(n - 1) + fib(n - 2)
  end
  -- fib(30) makes ~2.7M calls
  local t = B.time(function() fib(30) end)
  B.report("fib_recursive", 2692537, t)  -- exact call count for fib(30)
end


B.section("Coroutines")

-- Coroutine resume/yield cycle
do
  local n = N
  local t = B.time(function()
    local co = coroutine.create(function()
      local i = 0
      while true do
        i = i + 1
        coroutine.yield(i)
      end
    end)
    for _ = 1, n do
      coroutine.resume(co)
    end
  end)
  B.report("coro_resume_yield", n, t)
end

-- coroutine.wrap (lighter weight than create+resume)
do
  local n = N
  local t = B.time(function()
    local gen = coroutine.wrap(function()
      local i = 0
      while true do
        i = i + 1
        coroutine.yield(i)
      end
    end)
    for _ = 1, n do gen() end
  end)
  B.report("coro_wrap_call", n, t)
end


B.section("Strings")

-- String concatenation (short strings, forces interning)
do
  local n = N // 2
  local t = B.time(function()
    local s = ""
    for i = 1, 1000 do s = s .. "x" end  -- O(n^2) but only 1000
    -- now test format (the common fast path)
    for i = 1, n do
      local _ = string.format("item_%d", i)
    end
  end)
  B.report("string_format", n, t)
end

-- Pattern matching
do
  local n = N // 4
  local line = "2026-02-20 12:34:56 ERROR [main] something went wrong here"
  local t = B.time(function()
    for i = 1, n do
      string.match(line, "(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+) (%w+)")
    end
  end)
  B.report("string_match", n, t)
end


B.section("Garbage Collection Pressure")

-- Allocation-heavy: create and discard lots of small tables
do
  local n = N
  local t = B.time(function()
    for i = 1, n do
      local _ = {i, i+1, i+2}
    end
  end)
  B.report("gc_alloc_small", n, t)
end

-- Mixed allocation: tables + closures + strings
do
  local n = N // 2
  local t = B.time(function()
    for i = 1, n do
      local t = {x = i, name = "obj_" .. i}
      t.update = function(self) self.x = self.x + 1 end
      t:update()
    end
  end)
  B.report("gc_alloc_mixed", n, t)
end

print("\nDone.")
