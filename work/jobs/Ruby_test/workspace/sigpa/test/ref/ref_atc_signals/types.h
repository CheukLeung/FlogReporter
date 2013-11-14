/*
 * File: types.h
 *
 */

#ifndef __TYPES_H__
#define __TYPES_H__

#define MAX_STATES  10

#ifndef TRUE
# define TRUE     (1U)
#endif

#ifndef FALSE
# define FALSE    (0U)
#endif

/* Data types */
typedef signed char    S8;
typedef unsigned char  U8;
typedef short          S16;
typedef unsigned short U16;
typedef int            S32;
typedef unsigned int   U32;

/* Min and max values for data types */
#define MAX_S8       ((S8)(127))
#define MIN_S8       ((S8)(-128))
#define MAX_U8       ((U8)(255U))
#define MIN_U8       ((U8)(0U))
#define MAX_S16      ((S16)(32767))
#define MIN_S16      ((S16)(-32768))
#define MAX_U16      ((U16)(65535U))
#define MIN_U16      ((U16)(0U))
#define MAX_S32      ((S32)(2147483647))
#define MIN_S32      ((S32)(-2147483647-1))
#define MAX_U32      ((U32)(0xFFFFFFFFU))
#define MIN_U32      ((U32)(0U))

#endif  /* __TYPES_H__ */
