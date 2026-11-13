// Stage a fuzz input in a reusable scratch file for parsers that only take a path.
#pragma once
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <unistd.h>

inline const char* StageInputFile(const uint8_t* data, size_t size)
{
  static std::string path;
  if (path.empty()) {
    const char* tmp = getenv("TMPDIR");
    path = std::string(tmp && *tmp ? tmp : "/tmp") + "/bareos-fuzz-XXXXXX";
    int fd = mkstemp(path.data());
    if (fd < 0) { abort(); }
    close(fd);
    atexit([] { unlink(path.c_str()); });
  }
  FILE* f = fopen(path.c_str(), "wb");
  if (!f) { abort(); }
  if (size) { fwrite(data, 1, size, f); }
  fclose(f);
  return path.c_str();
}
