#ifndef _SIGNAL_ABSFL_H_
#define _SIGNAL_ABSFL_H_
#include "types.h"

typedef enum {
  idle = -1,
  Entry = 0,
  CalcSlipRate = 1,
  Exit = 2
} ABSFLState;

typedef struct {
  U32 ABSFL_w;
  U32 ABSFL_v;
  U32 ABSFL_wheelABS;
  U32 ABSFL_R;
} ABSFLInput;

typedef struct {
  U32 w;
  U32 wheelABS;
  U32 torqueABS;
  U32 v;
  U32 R;
  U32 state;
} ABSFLStateTrace;

#endif
