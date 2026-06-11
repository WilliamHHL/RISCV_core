#include <stdint.h>
#include <stddef.h>

void *memcpy(void *dst, const void *src, size_t n) {
    uint8_t *d = (uint8_t*)dst;
    const uint8_t *s = (const uint8_t*)src;

    if (n == 0 || d == s) return dst;

    // 头：把目标对齐到4字节（避免未对齐SW）
    while (((uintptr_t)d & 3) && n) {
        *d++ = *s++;
        n--;
    }

    // 中：若源也4字节对齐，使用LW/SW；否则保持字节搬运，避免未对齐LW
    if ((((uintptr_t)s & 3) == 0)) {
        while (n >= 4) {
            uint32_t w = *(const uint32_t*)s; // 对齐LW
            *(uint32_t*)d = w;                // 对齐SW
            s += 4; d += 4; n -= 4;
        }
    } else {
        while (n >= 4) {
            d[0] = s[0];
            d[1] = s[1];
            d[2] = s[2];
            d[3] = s[3];
            d += 4; s += 4; n -= 4;
        }
    }

    // 尾：字节收尾
    while (n--) {
        *d++ = *s++;
    }
    return dst;
}
