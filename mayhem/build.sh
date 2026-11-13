#!/usr/bin/env bash
#
# mayhem/build.sh — builds the sanitized fuzz harnesses (+ -standalone reproducers) and the test suite.
# Runs in the commit image as `mayhem` in /mayhem. Offline and re-runnable: every dependency is an apt
# -dev package or lives under /opt/toolchains/deps.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
: "${SRC:=/mayhem}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS SRC
# harnesses.cmake reads LIB_FUZZING_ENGINE and STANDALONE_FUZZ_MAIN from the environment.
: "${STANDALONE_FUZZ_MAIN:=/opt/mayhem/StandaloneFuzzTargetMain.c}"
export STANDALONE_FUZZ_MAIN
# Linked into every fuzz and -standalone binary: disables LeakSanitizer at build time.
export MH_LSAN_OFF="$SRC/mayhem/lsan_off.cc"

cd "$SRC"

DEPS=/opt/toolchains/deps
COMMON=(
  -G Ninja
  -DCMAKE_MODULE_PATH="$SRC/mayhem/cmake/modules"
  -DENABLE_WEBUI=OFF -DENABLE_SYSTEMTESTS=OFF -DENABLE_PYTHON=OFF -DENABLE_NLS=OFF -DENABLE_CAPABILITY=OFF
  -DFETCHCONTENT_FULLY_DISCONNECTED=ON
  -DCPM_utf8cpp_SOURCE="$DEPS/utfcpp-4.2.1/src"
  -DCPM_tl-expected_SOURCE="$DEPS/tl-expected-1.1.0/src"
)

# A re-run reconfigures from scratch: cmake discards a cache whose compiler was recorded by absolute path
# when it is now given by name, and loses the -D overrides in the process. Object files are kept.
rm -f mayhem/build/CMakeCache.txt mayhem/build-tests/CMakeCache.txt

# 1) Sanitized project + harnesses. mayhem/cmake/project_include.cmake adds the harness targets to
#    upstream's own build graph (mh_all), so the fuzzed libraries are instrumented too.
FUZZ_FLAGS="$SANITIZER_FLAGS $DEBUG_FLAGS -fsanitize=fuzzer-no-link"
cmake -S . -B mayhem/build "${COMMON[@]}" \
  -DCMAKE_BUILD_TYPE=Debug -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
  -DCMAKE_C_FLAGS="$FUZZ_FLAGS" -DCMAKE_CXX_FLAGS="$FUZZ_FLAGS" \
  -DCMAKE_C_FLAGS_DEBUG=-O1 -DCMAKE_CXX_FLAGS_DEBUG=-O1 \
  -DCMAKE_PROJECT_INCLUDE="$SRC/mayhem/cmake/project_include.cmake"
cmake --build mayhem/build --target mh_all -j"$MAYHEM_JOBS"

# 2) Test suite with the project's normal flags (gcc: upstream's -Werror trips on a gcc-14 false positive
#    and clang-19 cannot compile the daemons' authenticate.cc against libstdc++ 14).
TEST_FLAGS="-Wno-maybe-uninitialized $COVERAGE_FLAGS"
cmake -S . -B mayhem/build-tests "${COMMON[@]}" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ \
  -DCMAKE_C_FLAGS="$TEST_FLAGS" -DCMAKE_CXX_FLAGS="$TEST_FLAGS" -DBUILD_TESTING=ON
cmake --build mayhem/build-tests -j"$MAYHEM_JOBS" --target \
  test_webui_proxy bool_string globbing_test test_config_parser_dir test_config_parser_fd \
  test_config_parser_console test_is_name_valid sort_stringvector test_edit test_bsnprintf test_crc32
