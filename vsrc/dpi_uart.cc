
#include <cstdio>
#include <vector>

extern "C" void uart_putc(unsigned char c) {
static std::vector<unsigned char> buf;
// 可選：忽略 CR，視你的程式而定
if (c == '\r') return;
buf.push_back(c);

// 觸發輸出時機：遇到換行或避免緩衝過大
if (c == '\n' || buf.size() > 1024) {
    for (auto ch : buf) std::putchar(ch);
    std::fflush(stdout);
    buf.clear();
}

}