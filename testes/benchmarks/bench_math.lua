-- Benchmark: loop + math performance
-- Tests raw loop throughput and arithmetic/trig operation speed.

package.path = package.path .. ";./benchmarks/?.lua"
local B = require("bench_util")

local N = 5e6   -- operations per benchmark

B.section("Integer Arithmetic")

-- Pure loop overhead (empty body) — baseline for comparison
do
  local n = N * 4
  local t = B.time(function()
    local x = 0
    for i = 1, n do x = i end
  end)
  B.report("empty_loop", n, t)
end

-- Integer addition in a tight loop
do
  local n = N * 4
  local t = B.time(function()
    local sum = 0
    for i = 1, n do sum = sum + i end
  end)
  B.report("int_add", n, t)
end

-- Integer multiply + accumulate
do
  local n = N * 2
  local t = B.time(function()
    local sum = 0
    for i = 1, n do sum = sum + i * i end
  end)
  B.report("int_mul_acc", n, t)
end

-- Integer modulo (common in index calculations)
do
  local n = N * 2
  local t = B.time(function()
    local sum = 0
    for i = 1, n do sum = sum + i % 127 end
  end)
  B.report("int_mod", n, t)
end

-- Bitwise operations (new in Lua 5.3+)
do
  local n = N * 2
  local t = B.time(function()
    local x = 0xDEADBEEF
    for i = 1, n do
      x = (x >> 1) ~ (x << 3) & 0xFFFFFFFF
    end
  end)
  B.report("bitwise_ops", n, t)
end


B.section("Floating Point Arithmetic")

-- Float add (force float with 0.0)
do
  local n = N * 4
  local t = B.time(function()
    local sum = 0.0
    for i = 1, n do sum = sum + i * 0.1 end
  end)
  B.report("float_add", n, t)
end

-- Float multiply-accumulate (FMA pattern)
do
  local n = N * 2
  local t = B.time(function()
    local sum = 0.0
    for i = 1, n do sum = sum + i * 3.14159 end
  end)
  B.report("float_mul_acc", n, t)
end

-- Float division
do
  local n = N * 2
  local t = B.time(function()
    local sum = 0.0
    for i = 1, n do sum = sum + 1.0 / (i + 1.0) end
  end)
  B.report("float_div", n, t)
end


B.section("Math Library (trig, sqrt, log)")

-- math.sqrt — common in distance calculations
do
  local sqrt = math.sqrt
  local n = N
  local t = B.time(function()
    local sum = 0.0
    for i = 1, n do sum = sum + sqrt(i) end
  end)
  B.report("math_sqrt", n, t)
end

-- math.sin + math.cos (trig pair)
do
  local sin, cos = math.sin, math.cos
  local n = N
  local t = B.time(function()
    local sum = 0.0
    for i = 1, n do sum = sum + sin(i) + cos(i) end
  end)
  B.report("math_sincos", n * 2, t)  -- 2 trig calls per iteration
end

-- math.log + math.exp
do
  local log, exp = math.log, math.exp
  local n = N
  local t = B.time(function()
    local sum = 0.0
    for i = 1, n do sum = sum + log(i + 1) + exp(-i * 1e-7) end
  end)
  B.report("math_logexp", n * 2, t)
end

-- math.atan (2-arg) — common in angle calculations
do
  local atan = math.atan
  local n = N
  local t = B.time(function()
    local sum = 0.0
    for i = 1, n do sum = sum + atan(i, i + 1) end
  end)
  B.report("math_atan2", n, t)
end


B.section("Mixed Workloads")

-- Simulated particle step: position += velocity, distance check
do
  local sqrt = math.sqrt
  local n = N
  local t = B.time(function()
    local px, py, pz = 0.0, 0.0, 0.0
    local vx, vy, vz = 0.1, 0.2, 0.3
    for i = 1, n do
      px = px + vx
      py = py + vy
      pz = pz + vz
      local d = sqrt(px*px + py*py + pz*pz)
      vx = vx + 0.001 / d
    end
  end)
  B.report("particle_step", n, t)
end

-- Mandelbrot escape iteration (classic compute benchmark)
do
  local n = 0
  local t = B.time(function()
    n = 0
    for py = -1.0, 1.0, 0.005 do
      for px = -2.0, 0.5, 0.005 do
        local zr, zi = 0.0, 0.0
        local iter = 0
        while iter < 100 do
          local zr2, zi2 = zr*zr, zi*zi
          if zr2 + zi2 > 4.0 then break end
          zi = 2*zr*zi + py
          zr = zr2 - zi2 + px
          iter = iter + 1
        end
        n = n + 1
      end
    end
  end)
  B.report("mandelbrot", n * 100, t)  -- worst case 100 iters per pixel
end

print("\nDone.")
