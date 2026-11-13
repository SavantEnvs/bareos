// Console text helpers of the webui proxy: normalization for JSON embedding and
// out-of-band notification filtering.
#include "proxy_session.h"
#include <fuzzer/FuzzedDataProvider.h>
#include <jansson.h>
#include <cstdint>
#include <cstdlib>
#include <string>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size)
{
  FuzzedDataProvider fdp(data, size);
  std::string command = fdp.ConsumeRandomLengthString();
  std::string chunk = fdp.ConsumeRemainingBytesAsString();

  // NormalizeJsonText promises text that is safe to embed in a JSON response.
  std::string text = NormalizeJsonText(chunk);
  json_t* js = json_stringn(text.data(), text.size());
  if (!js) { abort(); }
  json_decref(js);

  std::string norm = NormalizeRawConsoleCommand(command);
  (void)IsExpectedConsoleExitCommand(true, norm);
  (void)IsExpectedConsoleExitCommand(false, command);
  (void)ShouldSuppressRawConsoleChunk(command, chunk);
  (void)FilterRawConsoleChunk(command, chunk);
  return 0;
}
