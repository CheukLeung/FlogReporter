/* base_type_sig.sig */

#include "osetypes.h"

typedef enum { False = 0, True = 1 } Boolean;
enum Etype { FOO, BAR, FOOBAR };

typedef unsigned char OSBOOLEAN;



#define BASE_TYPE_SIG 10276 /* !-SIGNO(struct base_type_sig)-! */
struct base_type_sig
{
  SIGSELECT sigNo;
  U32 uint1;
  S32 sint1;

  U16 uint2;
  S16 sint2;

  U8  uint3;
  S8  sint3;
#if 1
  unsigned int   uint4;
  int            sint4;

  unsigned short uint5;
  short          sint5;

  unsigned char  uint6;
  char           sint6;

  int              e1;
  OSBOOLEAN        b1;
  OSBOOLEAN        b2;
#endif

};

/* End of file */
