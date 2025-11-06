
#include <cstdio>
#include <vector>

extern "C" void uart_putc(unsigned char c) {
static std::vector<unsigned char> buf;

if (c == '\r') return;
buf.push_back(c);


if (c == '\n' || buf.size() > 1024) {
    for (auto ch : buf) std::putchar(ch);
    std::fflush(stdout);
    buf.clear();
}

}