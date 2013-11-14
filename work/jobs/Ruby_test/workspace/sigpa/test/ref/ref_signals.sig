#ifndef _SIGNALS_SIG_
#define _SIGNALS_SIG_

#define LINX_SIGSELECT int

enum testenum {ENUM1, ENUM2, ENUM3};
typedef unsigned char byte;
struct struct_type { int a, b; } ;

/* !-ARRAY_SIZE(array_val, array_size)-! */

#define OUTPUT_SIG 13121 /*!- SIGNO(struct output_sig) -!*/
struct output_sig {
  LINX_SIGSELECT sig_no;
  int output;
  int array_val[10];
  int array_size;
  byte byte_val;
  enum testenum enum_val;
  struct struct_type struct_val;
};

union LINX_SIGNAL {
  LINX_SIGSELECT sig_no;
  struct output_sig output;
};

#endif /* _SIGNALS_SIG_ */
