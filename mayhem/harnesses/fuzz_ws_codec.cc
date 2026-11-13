// WebSocket handshake and frame decoder of the webui proxy.
// Input: [handshake headers][buffered bytes][frames on the socket].
#include "ws_codec.h"
#include <fuzzer/FuzzedDataProvider.h>
#include <sys/socket.h>
#include <unistd.h>
#include <cstdint>
#include <stdexcept>
#include <string>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size)
{
  FuzzedDataProvider fdp(data, size);
  std::string headers = fdp.ConsumeRandomLengthString();
  std::string buffered = fdp.ConsumeRandomLengthString();
  std::string wire = fdp.ConsumeRemainingBytesAsString();

  int sv[2];
  if (socketpair(AF_UNIX, SOCK_STREAM, 0, sv) != 0) { abort(); }
  size_t sent = 0;
  while (sent < wire.size()) {
    ssize_t n = send(sv[0], wire.data() + sent, wire.size() - sent,
                     MSG_DONTWAIT | MSG_NOSIGNAL);
    if (n <= 0) { break; }
    sent += n;
  }
  shutdown(sv[0], SHUT_WR);

  try {
    WsCodec codec = WsCodec::Accept(sv[1], headers, buffered);
    while (!codec.IsClosed()) { (void)codec.RecvMessage(); }
  } catch (const std::runtime_error&) {
  }
  close(sv[0]);
  close(sv[1]);
  return 0;
}
