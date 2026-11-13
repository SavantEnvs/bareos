// Resource-config parser of one Bareos daemon, selected at compile time by
// CFG_DIR / CFG_FD / CFG_CONSOLE. Input is the whole config file.
#include "include/bareos.h"
#include "lib/parse_conf.h"
#include "input_file.h"
#include <cstring>
#include <memory>

#if defined(CFG_DIR)
#  include "dird/dird_globals.h"
#  include "dird/dird_conf.h"
#  define INIT_CONFIG(path) directordaemon::InitDirConfig(path, M_INFO)
#  define SET_GLOBAL(p) (directordaemon::my_config = (p))
#elif defined(CFG_FD)
#  include "filed/filed_globals.h"
#  include "filed/filed_conf.h"
#  define INIT_CONFIG(path) filedaemon::InitFdConfig(path, M_INFO)
#  define SET_GLOBAL(p) (filedaemon::my_config = (p))
#elif defined(CFG_CONSOLE)
#  include "console/console_globals.h"
#  include "console/console_conf.h"
#  define INIT_CONFIG(path) console::InitConsConfig(path, M_INFO)
#  define SET_GLOBAL(p) (console::my_config = (p))
#else
#  error "define one of CFG_DIR CFG_FD CFG_CONSOLE"
#endif

static bool DiscardOutput(void*, const char*, ...) { return true; }

extern "C" int LLVMFuzzerInitialize(int*, char***)
{
  OSDependentInit();
  return 0;
}

// "@" starts an include: "@|cmd" forks a shell, "@/dev/stdin" blocks. Keep the fuzzer away from both.
extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size)
{
  if (memchr(data, '@', size)) { return 0; }
  const char* path = StageInputFile(data, size);
  std::unique_ptr<ConfigurationParser> parser(INIT_CONFIG(path));
  SET_GLOBAL(parser.get());
  if (parser->ParseConfig()) { parser->DumpResources(DiscardOutput, nullptr); }
  SET_GLOBAL(nullptr);
  return 0;
}
