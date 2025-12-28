/* core_portme.h - 通用RV32裸机CoreMark移植头文件 */
#ifndef CORE_PORTME_H
#define CORE_PORTME_H
#include <stddef.h>

/* 基本类型定义 */
typedef unsigned char      ee_u8;
typedef signed short       ee_s16;
typedef unsigned short     ee_u16;
typedef signed int         ee_s32;
typedef unsigned int       ee_u32;
typedef unsigned int       ee_ptr_int;

/* 迭代次数（可用 -DITERATIONS=... 覆盖） */
#ifndef ITERATIONS
#define ITERATIONS 1
#endif

/* 浮点支持（启用后可输出小数秒数） */
#define HAS_FLOAT 0

/* 用mcycle计时 */
#define HAS_TIME  1
typedef ee_u32 CORE_TICKS;

/* 多线程支持（单核写1，多核可改） */
#define MULTITHREAD 1
#define USE_PTHREAD 0
#define NUM_CONTEXTS 1
#define default_num_contexts NUM_CONTEXTS

/* 内存定义 */
#define MEM_LOCATION "DMEM"

/* 内存分配方式：static */
#ifndef MEM_METHOD
#define MEM_METHOD 0
#endif
static inline void* align_mem(void* p) { return p; }

typedef ee_u32 ee_size_t;
static inline void* portable_malloc(ee_size_t size) { (void)size; return 0; }
static inline void  portable_free(void* p)          { (void)p; }

/* 编译器标识 */
#ifndef COMPILER_VERSION
#define COMPILER_VERSION "riscv gcc"
#endif

#ifndef COMPILER_FLAGS
#define COMPILER_FLAGS "-Os -ffreestanding -nostdlib -march=rv32i -mabi=ilp32"
#endif

/* ========== 计时相关 ==========
   只需设置CPU主频即可通用所有内核
*/
#define CPU_FREQ_HZ 40000000u  // 填你的主频，单位Hz

static inline unsigned int  time_in_secs(CORE_TICKS ticks) {
    return ticks / CPU_FREQ_HZ;
}

/* 打印由 core_portme.c 提供 */
void ee_printf(const char* fmt, ...);

/* CoreMark 需要的 portable hooks */
typedef struct {
  int portable_id;
} core_portable;

void portable_init(core_portable* p, int* argc, char* argv[]);
void portable_fini(core_portable* p);

#endif /* CORE_PORTME_H */
