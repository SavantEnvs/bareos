// bareos-webui-proxy.ini parser.
#include "proxy_config.h"
#include <cstdint>
#include <string>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size)
{
  try {
    ProxyConfig config
        = LoadProxyConfigFromString(std::string(reinterpret_cast<const char*>(data), size));
    (void)config.configured_directors.size();
  } catch (const ProxyConfigError&) {
  }
  return 0;
}
