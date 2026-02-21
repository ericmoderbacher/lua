-- Benchmark utilities — shared timing and reporting infrastructure.
-- Each benchmark sources this, runs its workload, and calls report().

local M = {}

-- Format large numbers with K/M/G suffixes
function M.human(n)
  if n >= 1e9 then return string.format("%.1fG", n / 1e9)
  elseif n >= 1e6 then return string.format("%.1fM", n / 1e6)
  elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
  else return string.format("%.0f", n)
  end
end

-- Run a benchmark function, return elapsed CPU seconds.
-- Calls f() once for warmup, then runs it `reps` times.
function M.time(f, reps)
  reps = reps or 1
  f()  -- warmup: trigger any JIT/cache effects
  collectgarbage("collect")
  collectgarbage("collect")
  local t0 = os.clock()
  for _ = 1, reps do
    f()
  end
  local t1 = os.clock()
  return t1 - t0
end

-- Print a scorecard line.
-- name:    benchmark name (e.g. "loop_add")
-- ops:     total number of operations performed
-- elapsed: wall-clock seconds from M.time()
function M.report(name, ops, elapsed)
  local rate = ops / elapsed
  -- BENCH prefix lets CTest regex match on it for pass/fail
  print(string.format("BENCH %-20s %10s ops  %8.3fs  %10s ops/sec",
    name, M.human(ops), elapsed, M.human(rate)))
end

-- Separator for grouping related benchmarks
function M.section(title)
  print(string.format("\n=== %s ===", title))
end

return M
