/* core_portme.c - 裸机RV32 printf和mcycle计时支持，适配所有RISC-V SoC */

#include "core_portme.h"

// ========== UART MMIO ==========
#define UART_BASE 0x20000000u

static inline void uart_putc(unsigned char c) {
    volatile unsigned char* uart = (volatile unsigned char*)UART_BASE;
    *uart = c;
}
static void uart_puts(const char* s) {
    while (*s) uart_putc(*s++);
}

int ee_putchar(int c) { uart_putc((unsigned char)c); return c; }

// ========== 十进制/十六进制输出 ==========
static void put_dec(unsigned int x) {
    char buf[20];
    int i = 0;
    if (x == 0) { uart_putc('0'); return; }
    while (x && i < (int)sizeof(buf)) {
        buf[i++] = (char)('0' + (x % 10));
        x /= 10;
    }
    while (i--) uart_putc(buf[i]);
}
static void put_hex32(unsigned x) {
    for (int i = 7; i >= 0; --i) {
        unsigned nib = (x >> (i*4)) & 0xF;
        uart_putc(nib < 10 ? ('0' + nib) : ('a' + nib - 10));
    }
}
static void put_hex(unsigned int x, int width) {
    char buf[8];
    int i;
    for (i = width-1; i >= 0; --i) {
        buf[i] = "0123456789abcdef"[x & 0xf];
        x >>= 4;
    }
    for (i = 0; i < width; ++i)
        uart_putc(buf[i]);
}

// ========== ee_printf (支持 %04x, %d, %u, %x, %c, %s, %ld, %lu) ==========
void ee_printf(const char* fmt, ...) {
    __builtin_va_list ap;
    __builtin_va_start(ap, fmt);

    for (const char* p = fmt; *p; ++p) {
        if (*p != '%') { uart_putc(*p); continue; }
        ++p;

        int width = 0;
        char pad = 0;
        if (*p == '0') {
            pad = '0';
            ++p;
            while (*p >= '0' && *p <= '9') {
                width = width * 10 + (*p - '0');
                ++p;
            }
        }

        int is_long = 0;
        if (*p == 'l') {
            is_long = 1;
            ++p;
        }

        switch (*p) {
            case 'd': {
                int v = is_long ? __builtin_va_arg(ap, long) : __builtin_va_arg(ap, int);
                if (v < 0) { uart_putc('-'); put_dec((unsigned int)(-v)); }
                else put_dec((unsigned int)(v));
                break;
            }
            case 'u': {
                unsigned int v = is_long ? __builtin_va_arg(ap, unsigned long) : __builtin_va_arg(ap, unsigned);
                put_dec(v);
                break;
            }
            case 'x': {
                unsigned int v = is_long ? __builtin_va_arg(ap, unsigned long) : __builtin_va_arg(ap, unsigned);
                if (pad == '0' && width > 0 && width <= 8)
                    put_hex(v, width);
                else
                    put_hex32((unsigned)v);
                break;
            }
            case 'c': {
                int v = __builtin_va_arg(ap, int);
                uart_putc((unsigned char)v);
                break;
            }
            case 's': {
                const char* s = __builtin_va_arg(ap, const char*);
                if (!s) s = "(null)";
                uart_puts(s);
                break;
            }
            case '%': {
                uart_putc('%');
                break;
            }
            default: {
                uart_putc('%');
                uart_putc(*p);
                break;
            }
        }
    }
    __builtin_va_end(ap);
}

// ========== CoreMark Timing: mcycle ==========
static unsigned int start_cycle, stop_cycle;

void start_time(void) {
    asm volatile ("csrr %0, mcycle" : "=r"(start_cycle));
}
void stop_time(void) {
    asm volatile ("csrr %0, mcycle" : "=r"(stop_cycle));
}
CORE_TICKS get_time(void) { return stop_cycle - start_cycle; }

// ========== CoreMark Portable Hooks ==========
void portable_init(core_portable* p, int* argc, char* argv[]) {
    (void)argc; (void)argv;
    if (p) p->portable_id = 1;
}
static inline void do_ebreak(void) { asm volatile("ebreak"); }
void portable_fini(core_portable* p) {
    if (p) p->portable_id = 0;
    do_ebreak();
}
