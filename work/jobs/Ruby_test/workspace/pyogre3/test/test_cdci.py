# ----------------------------------------------------------------
# test_cdci.py - 
# ----------------------------------------------------------------
import ogre
import cdci_sig

import unittest
import logging
import logging.config
import os


# ----------------------------------------------------------------
class TestUnion(unittest.TestCase):

   def setUp(self):
      self.url = '%s://%s:%s' % (os.environ['OGRE_COMM'],
                                 os.environ['OGRE_NODE'],
                                 os.environ['OGRE_PORT'])

   def test_union_in_array_1(self):
      """
      Verifies an array of struct with unions. Each union shall have
      its own union selector.
      """
      p = ogre.Process(self.url, 'ogre_echo')
      sig = cdci_sig.CDCI_TR_GET_DEVICE_CAPABILITY_CFM()
      sig.trId = 7 

      sig.capabilities = [ cdci_sig.trCapability() for i in range(3) ]

      sig.capabilities[0].capabilityIdentity = 1
      sig.capabilities[0].capabilityLength = 6
      sig.capabilities[0].trCapabils.tx.intTxGainCal = 21
      sig.capabilities[0].trCapabils.tx.txFqbandLowEdge = 22
      sig.capabilities[0].trCapabils.tx.txFqbandHighEdge = 23

      sig.capabilities[1].capabilityIdentity = 2
      sig.capabilities[1].capabilityLength = 0

      sig.capabilities[2].capabilityIdentity = 5
      sig.capabilities[2].capabilityLength = 4
      sig.capabilities[2].trCapabils.confUlCarrierBandwidth.minBandwidth = 31
      sig.capabilities[2].trCapabils.confUlCarrierBandwidth.maxBandwidth = 32

      p.send(sig)
      sig2 = p.receive()

      self.assertEquals(7,  sig2.trId)
      self.assertEquals(3,  len(sig2.capabilities))

      self.assertEquals(1,  sig2.capabilities[0].capabilityIdentity)
      self.assertEquals(21, sig2.capabilities[0].trCapabils.tx.intTxGainCal)
      self.assertEquals(22, sig2.capabilities[0].trCapabils.tx.txFqbandLowEdge)
      self.assertEquals(23, sig2.capabilities[0].trCapabils.tx.txFqbandHighEdge)

      self.assertEquals(2,  sig2.capabilities[1].capabilityIdentity)

      self.assertEquals(5,  sig2.capabilities[2].capabilityIdentity)
      self.assertEquals(31, sig2.capabilities[2].trCapabils.confUlCarrierBandwidth.minBandwidth)
      self.assertEquals(32, sig2.capabilities[2].trCapabils.confUlCarrierBandwidth.maxBandwidth)
      p.close()


   def test_union_in_array_2(self):
      """
      
      """
      p = ogre.Process(self.url, 'ogre_echo')
      sig = cdci_sig.CDCI_TR_GET_DEVICE_CAPABILITY_CFM()
      sig.trId = 49

      sig.capabilities[0].capabilityIdentity = 2
      sig.capabilities[0].capabilityLength = 6

      sig.capabilities[0].trCapabils.tx.intTxGainCal = 21
      sig.capabilities[0].trCapabils.tx.txFqbandLowEdge = 22
      sig.capabilities[0].trCapabils.tx.txFqbandHighEdge = 23

      sig.capabilities[0].trCapabils.rx.rxFqbandLowEdge = 41
      sig.capabilities[0].trCapabils.rx.rxFqbandHighEdge = 42

      sig.capabilities[0].trCapabils.confUlCarrierBandwidth.minBandwidth = 31
      sig.capabilities[0].trCapabils.confUlCarrierBandwidth.maxBandwidth = 32

      p.send(sig)
      sig2 = p.receive()

      # Verify the reply
      self.assertEquals(49, sig2.trId)
      self.assertEquals(1,  len(sig2.capabilities))

      self.assertEquals(2,  sig2.capabilities[0].capabilityIdentity)
      self.assertEquals(41, sig2.capabilities[0].trCapabils.rx.rxFqbandLowEdge)
      self.assertEquals(42, sig2.capabilities[0].trCapabils.rx.rxFqbandHighEdge)
      p.close()

   def tearDown(self):
      pass


# ----------------------------------------------------------------      
if __name__ == '__main__':
   logging.config.fileConfig('testlog.ini')
   unittest.main()

# End of file
