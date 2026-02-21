-- Benchmark: table operations
-- Tests table creation, access, iteration, and sorting.

package.path = package.path .. ";./benchmarks/?.lua"
local B = require("bench_util")

local N = 1e6

B.section("Table Creation")

-- Create small tables (hash part)
do
  local n = N
  local t = B.time(function()
    for i = 1, n do
      local _ = {x = i, y = i + 1, z = i + 2}
    end
  end)
  B.report("create_small_hash", n, t)
end

-- Create array tables
do
  local n = N
  local t = B.time(function()
    for i = 1, n do
      local _ = {i, i+1, i+2, i+3, i+4, i+5, i+6, i+7}
    end
  end)
  B.report("create_array_8", n, t)
end


B.section("Table Access")

-- Sequential array read
do
  local size = 10000
  local arr = {}
  for i = 1, size do arr[i] = i end
  local n = N * 2
  local t = B.time(function()
    local sum = 0
    for rep = 1, n // size do
      for i = 1, size do sum = sum + arr[i] end
    end
  end)
  B.report("array_read_seq", n, t)
end

-- Hash table read (string keys)
do
  local keys = {}
  local tbl = {}
  for i = 1, 1000 do
    local k = "key_" .. i
    keys[i] = k
    tbl[k] = i
  end
  local nkeys = #keys
  local n = N * 2
  local t = B.time(function()
    local sum = 0
    for rep = 1, n // nkeys do
      for i = 1, nkeys do sum = sum + tbl[keys[i]] end
    end
  end)
  B.report("hash_read_str", n, t)
end

-- Array write
do
  local size = 10000
  local arr = {}
  for i = 1, size do arr[i] = 0 end
  local n = N * 2
  local t = B.time(function()
    for rep = 1, n // size do
      for i = 1, size do arr[i] = i end
    end
  end)
  B.report("array_write_seq", n, t)
end


B.section("Table Iteration")

-- ipairs iteration
do
  local size = 10000
  local arr = {}
  for i = 1, size do arr[i] = i end
  local reps = N // size
  local t = B.time(function()
    local sum = 0
    for _ = 1, reps do
      for _, v in ipairs(arr) do sum = sum + v end
    end
  end)
  B.report("ipairs_iter", reps * size, t)
end

-- pairs iteration (hash table)
do
  local tbl = {}
  for i = 1, 1000 do tbl["k" .. i] = i end
  local reps = N // 1000
  local t = B.time(function()
    local sum = 0
    for _ = 1, reps do
      for _, v in pairs(tbl) do sum = sum + v end
    end
  end)
  B.report("pairs_iter", reps * 1000, t)
end


B.section("Table Sort")

-- Sort 10K integers
do
  local size = 10000
  local reps = 20
  local t = B.time(function()
    for _ = 1, reps do
      local arr = {}
      for i = 1, size do arr[i] = size - i end  -- reverse order (worst case)
      table.sort(arr)
    end
  end)
  -- n*log2(n) comparisons per sort
  local comps = reps * size * math.log(size, 2)
  B.report("sort_10k_int", math.floor(comps), t)
end

-- Sort with custom comparator (adds function call overhead)
do
  local size = 10000
  local reps = 20
  local t = B.time(function()
    for _ = 1, reps do
      local arr = {}
      for i = 1, size do arr[i] = size - i end
      table.sort(arr, function(a, b) return a < b end)
    end
  end)
  local comps = reps * size * math.log(size, 2)
  B.report("sort_10k_custom", math.floor(comps), t)
end

print("\nDone.")
