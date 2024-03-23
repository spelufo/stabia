#include <assert.h> // assert
#include <math.h>
#include <stdio.h>  // printf
#include <stdlib.h> // calloc
#include <stdint.h> // int*_t
#include <time.h>

typedef uint8_t   u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t    i8;
typedef int16_t  i16;
typedef int32_t  i32;
typedef int64_t  i64;

typedef _Float16 f16; 
typedef float    f32;
typedef double   f64;


#ifdef __cplusplus
#define export extern "C"
#else
#define export
#endif
