// Bootstrap-record (restore .bsr) parser, as used by bls/bextract/bcopy/the storage daemon.
#include "include/bareos.h"
#include "stored/bsr.h"
#include "lib/parse_bsr.h"
#include "input_file.h"

#include <cstring>

extern "C" int LLVMFuzzerInitialize(int*, char***)
{
  OSDependentInit();
  return 0;
}

// parse_bsr reads through the config lexer (LexGetToken, lex.cc), where "@" starts an include:
// "@|cmd" forks a shell via OpenBpipe and "@/path" reads any file. Keep the fuzzer away from both.
extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size)
{
  if (memchr(data, '@', size)) { return 0; }
  std::string path = StageInputFile(data, size);
  auto* bsr = libbareos::parse_bsr(nullptr, path.data());
  libbareos::FreeBsr(bsr);
  return 0;
}
