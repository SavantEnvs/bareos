#!/usr/bin/env bash
#
# mayhem/test.sh — RUN this repo's OWN functional test suite (already built by mayhem/build.sh).
# exit 0 = pass. EDIT per repo. PATCH-grade oracle: after an agent patches the source, the grader
# rebuilds (build.sh) then runs this. DELETE this file if the repo has no meaningful tests.
#
# IMPORTANT:
#  * Must assert BEHAVIOR/OUTPUT, not just exit status. The oracle has to check asserted values /
#    golden-output diffs / known-answer results — so a PATCH that "fixes" a bug by making the program
#    exit(0) (or any no-op) FAILS here. Running inputs and checking only "exit 0 / didn't crash" is
#    NOT a functional test (it's trivially reward-hackable) — use the project's real assertion suite.
#  * Do NOT build here — mayhem/build.sh already compiled the test suite (with the project's normal
#    flags). This script only RUNS the pre-built tests and reports counts. If the test runner is
#    missing, that's a build.sh bug — fail loudly rather than silently rebuilding.
#  * REQUIRED OUTPUT — a CTRF (https://ctrf.io) summary so Mayhem/the PATCH grader reads the counts:
#      - writes a CTRF JSON report to ${CTRF_REPORT:-$SRC/ctrf-report.json}, and
#      - prints a one-line `CTRF {...}` marker to stdout (same JSON, compact).
#    Only `results.summary` (with tests/passed/failed/pending/skipped/other) is required.
#    Use the emit_ctrf helper below; it computes tests = passed+failed+skipped and sets the exit
#    code (0 iff failed==0). Map your framework's output to passed/failed/skipped.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${MAYHEM_JOBS:=$(nproc)}"   # build parallelism; env-overridable, falls back to nproc (use -j"$MAYHEM_JOBS")
cd "$SRC"
: "${CTRF_REPORT:=$SRC/mayhem/build-tests/ctrf-report.json}"   # keep the report out of the source tree

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
# Writes a CTRF report (file + stdout `CTRF {...}` marker) and returns non-zero iff failed>0.
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

# Runs the gtest suites mayhem/build.sh built (webui-proxy, config parsers, lib helpers) through ctest.
# Every test asserts known-answer values (parsed config fields, base64/CRC vectors, proxy session behaviour).
BUILD=mayhem/build-tests
[ -f "$BUILD/CTestTestfile.cmake" ] || { echo "missing $BUILD: mayhem/build.sh did not build the tests" >&2; exit 2; }

log=$(mktemp)
(cd "$BUILD" && ctest -j"$MAYHEM_JOBS" -V -E _NOT_BUILT > "$log" 2>&1)
tail -8 "$log"
summary=$(grep -E 'tests passed, [0-9]+ tests failed out of [0-9]+' "$log" | tail -1)
total=$(echo "$summary" | sed -E 's/.* out of ([0-9]+).*/\1/')
failed=$(echo "$summary" | sed -E 's/.*, ([0-9]+) tests failed.*/\1/')
if ! [[ "$total" =~ ^[0-9]+$ && "$failed" =~ ^[0-9]+$ ]]; then
  echo "could not parse ctest summary" >&2
  emit_ctrf "cmake-ctest" 0 1 0
  exit 1
fi
# ctest alone only checks each test binary's exit status. Count the gtest "[       OK ]" lines the
# binaries print for each assertion-checked case, so a binary that exits 0 without running is a failure.
ok=$(grep -c '\[       OK \]' "$log" || true)
rm -f "$log"
if [ "$ok" -gt $(( total - failed )) ]; then ok=$(( total - failed )); fi
failed=$(( total - ok ))
# A missing test binary would silently shrink the suite; the build produces >100 tests.
if [ "$total" -lt 100 ]; then
  echo "only $total tests ran (expected >= 100): test build incomplete" >&2
  failed=$(( failed + 1 ))
fi
emit_ctrf "cmake-ctest" "$ok" "$failed" 0
