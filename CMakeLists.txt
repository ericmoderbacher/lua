cmake_minimum_required(VERSION 3.13)
project(lua VERSION 5.5.1 LANGUAGES C)

# Lua is written in clean C99 (no extensions needed)
set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)


# --- Platform detection ---
# Lua uses preprocessor defines to enable platform-specific features:
#   LUA_USE_MACOSX  → POSIX APIs + dlopen (no -ldl needed on macOS) + libedit for readline
#   LUA_USE_LINUX   → POSIX APIs + dlopen (needs -ldl) + libreadline
#   Windows         → auto-detected in luaconf.h, no extra defines needed

if(APPLE)
  set(LUA_PLATFORM_DEFINES LUA_USE_MACOSX)
  set(LUA_PLATFORM_LIBS)                     # macOS dlopen is in libSystem, no extra lib
elseif(UNIX)
  set(LUA_PLATFORM_DEFINES LUA_USE_LINUX)
  set(LUA_PLATFORM_LIBS dl)                  # dlopen lives in libdl on Linux
elseif(WIN32)
  set(LUA_PLATFORM_DEFINES)
  set(LUA_PLATFORM_LIBS)
endif()


# --- Source file organization ---
# Lua's source is split into three layers, mirroring the original Makefile:

# CORE: the virtual machine, parser, garbage collector, and all internal machinery.
# ltests.c is always compiled but its code is wrapped in #if defined(LUA_DEBUG),
# so it compiles to nothing unless the test harness is enabled.
set(LUA_CORE_SRC
  lapi.c      # C API implementation (lua_pushvalue, lua_gettable, etc.)
  lcode.c     # bytecode emitter (parser → opcodes)
  lctype.c    # character classification (locale-independent)
  ldebug.c    # debug interface (line numbers, stack traces)
  ldo.c       # call/return machinery, coroutine resume/yield, protected calls
  ldump.c     # binary chunk serializer (luaU_dump)
  lfunc.c     # function prototypes, upvalue management, closures
  lgc.c       # incremental/generational garbage collector
  llex.c      # lexical analyzer (tokenizer)
  lmem.c      # memory allocator wrapper (all Lua allocations go through here)
  lobject.c   # object representation, type conversions, string formatting
  lopcodes.c  # opcode metadata tables (names, modes, operand formats)
  lparser.c   # recursive descent parser (source → AST → bytecode via lcode)
  lstate.c    # global/per-thread state creation and teardown
  lstring.c   # interned string table (all strings are unique and hashed)
  ltable.c    # hash tables (the only data structure in Lua)
  ltm.c       # tag methods (metatables: __add, __index, __newindex, etc.)
  lundump.c   # binary chunk deserializer (loads precompiled bytecode)
  lvm.c       # the main interpreter loop (executes opcodes)
  lzio.c      # buffered stream abstraction for the parser
  ltests.c    # internal test hooks (only active when LUA_DEBUG is defined)
)

# AUX: the "auxiliary library" — higher-level helpers built on top of the C API.
# Things like luaL_checkinteger, luaL_newmetatable, luaL_Buffer, error formatting.
set(LUA_AUX_SRC
  lauxlib.c
)

# STDLIB: the standard libraries that ship with Lua.
# Each file registers one library (e.g. lmathlib.c → the "math" table).
set(LUA_LIB_SRC
  lbaselib.c  # base functions: print, type, pairs, ipairs, pcall, require, etc.
  ldblib.c    # debug library: debug.getinfo, debug.sethook, debug.traceback
  liolib.c    # io library: io.open, io.read, io.write, file handles
  lmathlib.c  # math library: math.sin, math.random, math.huge, etc.
  loslib.c    # os library: os.clock, os.time, os.execute, os.getenv
  ltablib.c   # table library: table.insert, table.sort, table.move
  lstrlib.c   # string library: string.find, string.format, string.gsub, etc.
  lutf8lib.c  # utf8 library: utf8.codepoint, utf8.codes, utf8.len
  loadlib.c   # package/require system and dynamic loading (dlopen/LoadLibrary)
  lcorolib.c  # coroutine library: coroutine.create, resume, yield, wrap
  linit.c     # opens all standard libraries into a new state
)


# --- Static library ---
# This is the main build product for embedding Lua in other applications.
# Link against this target to get the full Lua runtime.

add_library(lua_lib STATIC ${LUA_CORE_SRC} ${LUA_AUX_SRC} ${LUA_LIB_SRC})
target_include_directories(lua_lib PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_compile_definitions(lua_lib PUBLIC ${LUA_PLATFORM_DEFINES})
set_target_properties(lua_lib PROPERTIES OUTPUT_NAME lua)

if(UNIX)
  # Position-independent code is needed so this static library can be linked
  # into shared libraries or position-independent executables.
  set_target_properties(lua_lib PROPERTIES POSITION_INDEPENDENT_CODE ON)
endif()


# --- Interpreter ---
# The standalone "lua" REPL/script runner. This is just lua.c (a thin main()
# that creates a Lua state, opens the standard libs, and runs the REPL or
# a script file) linked against the library above.

add_executable(lua_exe lua.c)
target_link_libraries(lua_exe PRIVATE lua_lib m ${LUA_PLATFORM_LIBS})
set_target_properties(lua_exe PROPERTIES OUTPUT_NAME lua)

if(UNIX AND NOT APPLE)
  # -Wl,-E tells the linker to export all symbols from the executable.
  # This is needed so that C libraries loaded at runtime via require()
  # can resolve Lua API symbols (like lua_pushstring) from the host process.
  # macOS doesn't need this — its dynamic linker handles it differently.
  target_link_options(lua_exe PRIVATE -Wl,-E)
endif()


# --- Testing ---
# Lua's test suite lives in testes/all.lua. It requires:
#   1. A special interpreter built with LUA_USER_H="ltests.h", which enables
#      internal debug hooks (the global "T" table with low-level test functions).
#   2. Shared C libraries in testes/libs/ that the loadlib/require tests load.

option(LUA_BUILD_TESTS "Build Lua test infrastructure" OFF)

if(LUA_BUILD_TESTS)
  enable_testing()

  # Test-enabled library: same sources but compiled with LUA_USER_H="ltests.h".
  # ltests.h defines LUA_DEBUG and LUAI_ASSERT, which:
  #   - Activates all the code in ltests.c (internal test hooks)
  #   - Turns on assertion checks throughout the VM
  #   - Enables memory allocation tracking and stress testing
  add_library(lua_lib_test STATIC ${LUA_CORE_SRC} ${LUA_AUX_SRC} ${LUA_LIB_SRC})
  target_include_directories(lua_lib_test PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
  target_compile_definitions(lua_lib_test PUBLIC ${LUA_PLATFORM_DEFINES})
  target_compile_definitions(lua_lib_test PRIVATE "LUA_USER_H=\"ltests.h\"")
  if(UNIX)
    set_target_properties(lua_lib_test PROPERTIES POSITION_INDEPENDENT_CODE ON)
  endif()

  # Test interpreter linked against the test-enabled library
  add_executable(lua_test lua.c)
  target_link_libraries(lua_test PRIVATE lua_lib_test m ${LUA_PLATFORM_LIBS})
  target_compile_definitions(lua_test PRIVATE "LUA_USER_H=\"ltests.h\"")
  set_target_properties(lua_test PROPERTIES OUTPUT_NAME lua_test)
  if(UNIX AND NOT APPLE)
    target_link_options(lua_test PRIVATE -Wl,-E)
  endif()
  if(APPLE)
    # On macOS, LUA_USE_MACOSX sets LUA_READLINELIB to "libedit.dylib".
    # When libedit is loaded, it swallows prompts when stdin is a pipe,
    # which breaks the interactive-mode prompt tests (they pipe input via
    # < file and expect prompts in stdout).
    # We set the LUA_READLINELIB env var (not compile-time!) to a bogus
    # name so sub-processes fall back to no-readline mode. This preserves
    # the compile-time default for the -E flag tests (which ignore env vars
    # and expect the real libedit.dylib to load successfully).
    set(LUA_TEST_ENV "LUA_READLINELIB=nonexistent")
  endif()

  # --- Test shared libraries ---
  # The loadlib tests (testes/all.lua → libs.lua) load C modules at runtime
  # via require(). These .so/.dylib files provide those test modules.
  # They reference Lua API symbols but DON'T link against liblua — instead
  # they resolve those symbols from the host interpreter at load time.
  # On macOS this requires -undefined dynamic_lookup to tell the linker
  # "trust me, these symbols will exist at runtime."
  # On Linux the -Wl,-E on the interpreter handles this.

  set(TEST_LIBS_DIR ${CMAKE_CURRENT_SOURCE_DIR}/testes/libs)
  # Build .so files directly into the source testes/libs/ directory.
  # The test harness spawns sub-processes of lua_test that use the default
  # package.cpath (which includes ./libs/?.so relative to the testes/ working
  # directory). The original Makefile builds them in-place too.
  set(TEST_LIBS_OUT ${TEST_LIBS_DIR})

  foreach(libname lib1 lib11 lib2 lib21)
    add_library(${libname} MODULE ${TEST_LIBS_DIR}/${libname}.c)
    target_include_directories(${libname} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
    set_target_properties(${libname} PROPERTIES
      PREFIX ""                                  # output "lib1.so" not "liblib1.so"
      LIBRARY_OUTPUT_DIRECTORY ${TEST_LIBS_OUT}  # place next to where tests expect them
    )
    if(APPLE)
      target_link_options(${libname} PRIVATE -undefined dynamic_lookup)
    endif()
  endforeach()

  # lib2-v2 is built from lib22.c (tests version-specific loading)
  add_library(lib2-v2 MODULE ${TEST_LIBS_DIR}/lib22.c)
  target_include_directories(lib2-v2 PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
  set_target_properties(lib2-v2 PROPERTIES
    PREFIX ""
    LIBRARY_OUTPUT_DIRECTORY ${TEST_LIBS_OUT}
  )
  if(APPLE)
    target_link_options(lib2-v2 PRIVATE -undefined dynamic_lookup)
  endif()

  # --- CTest definitions ---
  # _U=false  → full test suite including internal VM tests (needs ltests.h build)
  # _U=true   → user-level tests only (portable subset, skips internal hooks)
  # Tests use relative dofile() calls (dofile("main.lua"), etc.) so the
  # working directory must be the testes/ source directory.
  # The test libs (.so files) are in the build tree, so we prepend that
  # path to package.cpath via -e so require() can find them.

  set(TESTES_DIR ${CMAKE_CURRENT_SOURCE_DIR}/testes)

  add_test(
    NAME lua_full_tests
    COMMAND lua_test -e "_U=false" ${TESTES_DIR}/all.lua
    WORKING_DIRECTORY ${TESTES_DIR}
  )
  if(LUA_TEST_ENV)
    set_tests_properties(lua_full_tests PROPERTIES ENVIRONMENT "${LUA_TEST_ENV}")
  endif()

  add_test(
    NAME lua_user_tests
    COMMAND lua_test -e "_U=true" ${TESTES_DIR}/all.lua
    WORKING_DIRECTORY ${TESTES_DIR}
  )
  if(LUA_TEST_ENV)
    set_tests_properties(lua_user_tests PROPERTIES ENVIRONMENT "${LUA_TEST_ENV}")
  endif()
endif()


# --- Benchmarks / Profiling ---
# Performance benchmarks that output a scorecard of ops/sec numbers.
# Enabled separately from tests — these measure speed, not correctness.
# Run with: ctest --test-dir build -R bench --verbose
# The --verbose flag (or -V) is important: it shows the scorecard output
# that would otherwise be hidden behind "Passed".

option(LUA_BUILD_BENCHMARKS "Build Lua performance benchmarks" OFF)

if(LUA_BUILD_BENCHMARKS)
  if(NOT LUA_BUILD_TESTS)
    # Benchmarks only need the production interpreter, not the test one.
    # But if tests are also enabled, we reuse their CTest setup.
    enable_testing()
  endif()

  set(BENCH_DIR ${CMAKE_CURRENT_SOURCE_DIR}/testes/benchmarks)

  # Each benchmark script prints BENCH lines with ops/sec numbers.
  # CTest's PASS_REGULAR_EXPRESSION makes it look for "Done." at the end
  # to confirm the benchmark ran to completion (not just "did it exit 0?").

  add_test(NAME bench_math
    COMMAND lua_exe ${BENCH_DIR}/bench_math.lua
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/testes
  )
  set_tests_properties(bench_math PROPERTIES
    LABELS "benchmark"
    PASS_REGULAR_EXPRESSION "Done\\."
    TIMEOUT 120
  )

  add_test(NAME bench_tables
    COMMAND lua_exe ${BENCH_DIR}/bench_tables.lua
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/testes
  )
  set_tests_properties(bench_tables PROPERTIES
    LABELS "benchmark"
    PASS_REGULAR_EXPRESSION "Done\\."
    TIMEOUT 120
  )

  add_test(NAME bench_calls
    COMMAND lua_exe ${BENCH_DIR}/bench_calls.lua
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/testes
  )
  set_tests_properties(bench_calls PROPERTIES
    LABELS "benchmark"
    PASS_REGULAR_EXPRESSION "Done\\."
    TIMEOUT 120
  )
endif()
