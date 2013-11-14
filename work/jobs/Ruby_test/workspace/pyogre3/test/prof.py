# ----------------------------------------------------------------
# prof.py - 
# ----------------------------------------------------------------
import ogre
import ogre_sig

import os
import profile


def _send_receive_big_signal(req_size, rsp_size, pid, gw):
      sig = ogre_sig.ogre_big_req()
      sig.requested_data_size = rsp_size
      sig.data_size = req_size
      sig.data[:] = [0x55 for i in range(req_size)]

      gw.send(sig, pid)
      reply = gw.receive()

def tst():
    gw.hunt("ogre_proc")
    pid = gw.receive().sender()
    for i in range(100):
        _send_receive_big_signal(100, 100, pid, gw)
    

url = '%s://%s:%s' % (os.environ['OGRE_COMM'],
                      os.environ['OGRE_NODE'],
                      os.environ['OGRE_PORT'])
gw = ogre.create(url, "testosegw")

gw.hunt("ogre_proc")
pid = gw.receive().sender()
profile.run("tst()")

gw.close()


# End of file
