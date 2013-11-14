from ctypes import c_uint, Structure, Union

MAX_STATES = 10

class ABSFLInput(Structure):
	_fields_ = [('ABSFL_w', c_uint),
        		('ABSFL_v', c_uint),
        		('ABSFL_wheelABS', c_uint),
        		('ABSFL_R', c_uint),
				]

# sig_no = 13121 We could create constant for convenience
class ABSFL_INPUT_SIG(Structure):
	_fields_ = [('sig_no', c_uint),
				('input', ABSFLInput),
				]
    def __init__(self):
        super(Structure, self).__init__()
		self.sig_no = 13121

class ABSFLStateTrace(Structure):
	_fields_ = [('w',c_uint),
        		('wheelABS', c_uint),
        		('torqueABS', c_uint),
        		('v', c_uint),
        		('R', c_uint),
        		('state', c_uint),
				]

StateArray = ABSFLStateTrace * MAX_STATES

# sig_no = 13122 We could create constant for convenience
class ABSFL_OUTPUT_SIG(Structure):
	_fields_ = [('sig_no', c_uint),
				('num_states', c_uint),
        		('states', StateArray),
				]
    def __init__(self):
        super(Structure, self).__init__()
		self.sig_no = 13122

class LINX_SIGNAL(Union):
    '''
    LinxAdapter Signal,
    Taken from linx basic example
    '''
    _fields_ = [("sig_no", c_uint),
                ("absfl_input", ABSFL_INPUT_SIG), 
                ("absfl_output", ABSFL_OUTPUT_SIG),
                ]
