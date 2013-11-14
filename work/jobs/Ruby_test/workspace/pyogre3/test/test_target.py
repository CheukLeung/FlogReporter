# ----------------------------------------------------------------
# test_target.py - Test cases that requires a target connection
# ----------------------------------------------------------------
import ogre
import ogre_sig
import array_sig
import signals

import unittest
import logging
import logging.config
import select
import time
import timeit
import os


# ----------------------------------------------------------------
class TestTarget(unittest.TestCase):

   def setUp(self):
      self.url = '%s://%s:%s' % (os.environ['OGRE_COMM'],
                                 os.environ['OGRE_NODE'],
                                 os.environ['OGRE_PORT'])
      #logging.info('Using URL: %s' % (self.url))
      self.conn = ogre.create(self.url, "testogre")


   def test_unpack_nested_array0(self):
      self.conn.hunt("ogre_echo")
      pid = self.conn.receive([ogre.HUNT_SIG]).sender()

      sig1 = ogre_sig.OGRE_DYN_REQ()
      sig1.int1 = 47
      sig1.dyn1_array[:] = []
      
      # TODO ..............
      
      self.conn.send(sig1, pid)

      sig2 = self.conn.receive()
      self.assertEqual(sig1, sig2)

      
   def test_array(self):
      self.conn.hunt("ogre_echo")
      pid = self.conn.receive([ogre.HUNT_SIG]).sender()

      sig1 = array_sig.ArraySig()
      
      sig1.a = 47
      sig1.b.foo = 91
      sig1.b.bar = 92
      sig1.c.foo = 93
      sig1.c.bar = 94

      sig1.fix1_array[0].foo = 1
      sig1.fix1_array[0].bar = 2
      sig1.fix1_array[1].foo = 11
      sig1.fix1_array[1].bar = 12
      sig1.fix1_array[2].foo = 21
      sig1.fix1_array[2].bar = 22

      sig1.fix2_array[0] = 101
      sig1.fix2_array[1] = 102

      sig1.dyn1_array_len = 3
      #sig1.dyn1_array.append( array_sig.StructB())
      sig1.dyn1_array.append( array_sig.StructB())
      sig1.dyn1_array.append( array_sig.StructB())
      sig1.dyn1_array[0].foo = 201
      sig1.dyn1_array[0].bar = 202
      sig1.dyn1_array[1].foo = 211
      sig1.dyn1_array[1].bar = 212
      sig1.dyn1_array[2].foo = 221
      sig1.dyn1_array[2].bar = 222

      sig1.dyn2_array = [1,3,7,11,13]
      sig1.dyn2_array_len = len(sig1.dyn2_array);
      
      self.conn.send(sig1, pid)
      #print sig1

      sig2 = self.conn.receive()
      #print sig2
      self.assertEqual(sig1, sig2)


   def test_align(self):
      self.conn.hunt("ogre_proc")
      pid = self.conn.receive([ogre.HUNT_SIG]).sender()

      sync = ogre_sig.OGRE_ALIGN_REQ()
      sync.int1 = 1
      sync.int2 = 2
      sync.int3 = 3
      sync.int4 = 4
      sync.i1[0].int11 = 11
      sync.i1[0].int12 = 12
      sync.i1[1].int11 = 13
      sync.i1[1].int12 = 14
      sync.i1[2].int11 = 15
      sync.i1[2].int12 = 16
      sync.int5 = 5
      sync.int6 = 6
      sync.i2.int21 = 21
      sync.i2.int22 = 22
      sync.i2.int23 = 23
      sync.i2.int24 = 24
      sync.int7 = 7
      sync.int8 = 8
      self.conn.send(sync, pid)

      reply = self.conn.receive()
      self.assertEqual(reply.int1, 1)
      self.assertEqual(reply.int2, 2)
      self.assertEqual(reply.int3, 3)
      self.assertEqual(reply.int4, 4)

      self.assertEqual(reply.i1[0].int11, 11)
      self.assertEqual(reply.i1[0].int12, 12)
      self.assertEqual(reply.i1[1].int11, 13)
      self.assertEqual(reply.i1[1].int12, 14)
      self.assertEqual(reply.i1[2].int11, 15)
      self.assertEqual(reply.i1[2].int12, 16)

      self.assertEqual(reply.int5, 5)
      self.assertEqual(reply.int6, 6)

      self.assertEqual(reply.i2.int21, 21)
      self.assertEqual(reply.i2.int22, 22)
      self.assertEqual(reply.i2.int23, 23)
      self.assertEqual(reply.i2.int24, 24)

      self.assertEqual(reply.int7, 7)
      self.assertEqual(reply.int8, 8)
      self.assertEqual(reply.ok, 1)


   def test_big_signals(self):
      self.conn.hunt("ogre_proc")
      pid = self.conn.receive([ogre.HUNT_SIG]).sender()
      t1 = self._send_receive_big_signal(5000, 100, pid)
      t2 = self._send_receive_big_signal(100, 5000, pid)
      t1 = int(t1 * 1000)
      t2 = int(t2 * 1000)
      self.assert_(t2 < 2 * t1, "%d ms, %d ms" % (t1, t2))
      self.assert_(t1 < 2 * t2, "%d ms, %d ms" % (t1, t2))

   def _send_receive_big_signal(self, req_size, rsp_size, pid):
      sig = ogre_sig.OGRE_BIG_REQ()
      sig.requested_data_size = rsp_size
      sig.data_size = req_size
      sig.data[:] = [0x55 for i in range(req_size)]

      # Send and wait for a reply
      start = time.time()
      self.conn.send(sig, pid)
      reply = self.conn.receive()
      end = time.time()

      # Verify the reply
      self.assertEqual(1, reply.ok)
      self.assertEqual(rsp_size, len(reply.data))
      map(lambda e: self.assertEqual(e, 0xaa), reply.data)
      return end - start

   def test_hunt(self):
      # Process not found
      self.conn.hunt("kalle")
      sig = self.conn.receive([ogre.HUNT_SIG], timeout=1.0)
      self.assertEqual(None, sig);

      # Hunt signal
      self.conn.hunt("ogre_echo", signals.HuntInd())
      hunt_sig = self.conn.receive()
      self.assertNotEqual(0, hunt_sig.sender());

   def test_attach(self):
      conn1 = ogre.create(self.url, "kill_proc")
      self.conn.hunt("kill_proc")
      pid = self.conn.receive().sender()
      self.assert_(pid != 0);
      ref = self.conn.attach(pid)

      # Close the phantom process and wait for the attach signal
      conn1.close()
      sig = self.conn.receive()
      self.assertEqual(sig.sigNo, ogre.ATTACH_SIG)
      self.conn.detach(ref)

   def test_ogre_echo(self):
      self.conn.hunt("ogre_echo")
      pid = self.conn.receive().sender()
      self.assertNotEqual(pid, 0);

      sync = signals.SyncReq()
      sync.t1 = 1
      sync.t2 = 2
      sync.t3 = 3
      sync.t4 = 4
      self.conn.send(sync, pid)

      reply = self.conn.receive()
      self.assertEqual(reply.t1, 1)
      self.assertEqual(reply.t2, 2)
      self.assertEqual(reply.t3, 3)
      self.assertEqual(reply.t4, 4)

   def test_unknown_signal(self):
      self.conn.hunt("ogre_echo")
      pid = self.conn.receive().sender()
      self.assertNotEqual(pid, 0);

      unknown = signals.UnregisteredInd()
      self.conn.send(unknown, pid)

      # Verify the unknown (unregistered) received signal is an
      # instance of ogre.UnknownSignal
      reply = self.conn.receive()
      self.assert_(isinstance(reply, ogre.UnknownSignal))
      self.assert_(reply.sigNo == signals.UnregisteredInd.SIGNO)


   def test_async_receive(self):
      conn1 = ogre.create(self.url, "client1")
      conn2 = ogre.create(self.url, "client2")

      fd1 = conn1.get_blocking_object()
      fd2 = conn2.get_blocking_object()

      # Client 1 send signals to client2
      sync = signals.SyncReq()
      sync.t1 = 1
      conn1.send(sync, conn2.pid())
      conn1.send(sync, conn2.pid())

      # Client 2 send signals to client1
      sync = signals.SyncReq()
      sync.t1 = 2
      conn2.send(sync, conn1.pid())
      conn2.send(sync, conn1.pid())

      # Receive all four signals
      conn1.init_async_receive()
      conn2.init_async_receive()
      no_of_signals  = 0
      while no_of_signals < 4:
         (rfd, wdf, efd) = select.select([fd1, fd2], [], [])
         if fd1 in rfd:
            reply = conn1.async_receive()
            conn1.init_async_receive()
            self.assert_(reply.t1 == 2)
            no_of_signals += 1
         if fd2 in rfd:
            conn2.init_async_receive()
            reply = conn2.async_receive()
            self.assert_(reply.t1 == 1)
            no_of_signals += 1

      # Cleanup
      conn1.cancel_async_receive()
      conn2.cancel_async_receive()
      conn1.close()
      conn2.close()


   def tearDown(self):
      self.conn.close()
      pass


# ----------------------------------------------------------------      
if __name__ == '__main__':
   logging.config.fileConfig('testlog.ini')
   unittest.main()

# End of file
