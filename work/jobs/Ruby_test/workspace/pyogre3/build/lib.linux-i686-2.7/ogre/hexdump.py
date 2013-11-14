# ----------------------------------------------------------------
# hexdump.py
# ----------------------------------------------------------------
"""
Private functions for dumping hex data.
"""

def _ascii(byte):
    """Determine how to show a byte in ascii."""
    if 32 <= byte <= 126:
        return chr(byte)
    elif 160 <= byte <= 255:
        return '.'
    else:
        return '.'


def hexdump(data, width=16, prefix=''):
    """Dump a byte buffer as hex data"""
    hexstr = ''
    address = 0
    dataadd = 0
    datahex = ''
    datastr = ''
    newln = ''

    for i in range(len(data)):
        n = data[i]
        if isinstance(n, str):
            n = ord(n)
        datahex += '%02X ' % n
        datastr += _ascii(n)
        address += 1
        if (address % width) == 0:
            hexstr += newln + prefix + "0x%04X  %s  '%s'" % (dataadd,
                                                             datahex,
                                                             datastr)
            dataadd = address
            datahex = ''
            datastr = ''
            newln = '\n'

    if datastr != '':
        # print extra spaces to last line so that hexdump columns
        # will be aligned
        a = width - (address % width)
        datahex += '   ' * a
        hexstr += newln + prefix + "0x%04X  %s  '%s'" % (dataadd,
                                                         datahex,
                                                         datastr)

    return hexstr

# End of file
