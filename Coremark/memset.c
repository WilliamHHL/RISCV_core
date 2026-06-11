#include <stdint.h>
#include <stddef.h>

void *memset(void *dst, int c, size_t n) {
    uint8_t *d = (uint8_t*)dst;
    uint8_t b = (uint8_t)c;

    // 头：对齐到4字节
    while (((uintptr_t)d & 3) && n) {
        *d++ = b;
        n--;
    }

    // 中：用字写（对齐SW）
    if (n >= 4) {
        uint32_t w = (uint32_t)b;
        w |= w << 8;
        w |= w << 16;
        while (n >= 4) {
            *(uint32_t*)d = w;
            d += 4; n -= 4;
        }
    }

    // 尾：字节收尾
    while (n--) {
        *d++ = b;
    }
    return dst;
}
