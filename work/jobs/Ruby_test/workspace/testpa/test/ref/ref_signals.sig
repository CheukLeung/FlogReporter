#ifndef _SIGNALS_SIG_
#define _SIGNALS_SIG_

#include <linx.h>
#include "signal_absfl.h"

#define ABSFL_INPUT_SIG 13121 /*!- SIGNO(struct absfl_input_sig) -!*/
struct absfl_input_sig {
  LINX_SIGSELECT sig_no;
  ABSFLInput input;
};

#define ABSFL_OUTPUT_SIG 13122 /*!- SIGNO(struct absfl_output_sig) -!*/
struct absfl_output_sig {
  LINX_SIGSELECT sig_no;
  U32 num_states;
  ABSFLStateTrace states[MAX_STATES];
};

union LINX_SIGNAL {
  LINX_SIGSELECT sig_no;
  struct absfl_input_sig absfl_input;
  struct absfl_output_sig absfl_output;
};

#endif /* _SIGNALS_SIG_ */
