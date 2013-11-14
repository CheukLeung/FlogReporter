#!/bin/env python
import socket
import json

class metrics:
	def __init__(self):
		self.a = 4
	def stackFree(self):
		s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
		s.connect(("localhost", 12001))
		s.send("GET_STACK 0\n")
		data = s.recv(1024).split()
		s.close()
		return int(data[1])
	def heapFree(self):
		s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
		s.connect(("localhost", 12001))
		s.send("GET_HEAP 0\n")
		data = s.recv(1024).split()
		s.close()
		return int(data[1])
		
if __name__ == '__main__':
	m = metrics()
	i = m.stackFree()
	print "Got response with data: "
