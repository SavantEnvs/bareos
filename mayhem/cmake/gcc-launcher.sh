#!/bin/sh
# CXX_COMPILER_LAUNCHER for the one TU per daemon that clang 19 rejects: compile it with g++ instead.
shift
for a in "$@"; do
  shift
  case "$a" in
    -fsanitize=fuzzer-no-link|-Wformat-type-confusion) ;;
    *) set -- "$@" "$a" ;;
  esac
done
exec g++ "$@"
