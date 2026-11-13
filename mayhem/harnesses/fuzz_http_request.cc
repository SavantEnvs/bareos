// HTTP request reader of the webui proxy, fed from a socket pair.
#include "http_protocol.h"
#include <fuzzer/FuzzedDataProvider.h>
#include <sys/socket.h>
#include <unistd.h>
#include <cstdint>
#include <stdexcept>
#include <string>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size)
{
  int sv[2];
  if (socketpair(AF_UNIX, SOCK_STREAM, 0, sv) != 0) { abort(); }
  size_t sent = 0;
  while (sent < size) {
    ssize_t n = send(sv[0], data + sent, size - sent, MSG_DONTWAIT | MSG_NOSIGNAL);
    if (n <= 0) { break; }
    sent += n;
  }
  shutdown(sv[0], SHUT_WR);

  try {
    HttpRequest request = ReadHttpRequest(sv[1]);
    (void)IsWebSocketUpgradeRequest(request);
    if (auto cookie = request.HeaderValue("Cookie")) {
      (void)FindCookieValue(*cookie, "session");
      (void)FindCookieValue(*cookie, "");
    }
    (void)request.HeaderValue("Content-Type");
  } catch (const std::runtime_error&) {
  }
  close(sv[0]);
  close(sv[1]);
  return 0;
}
