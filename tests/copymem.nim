import unittest
import nico

suite "copymem":
  setup:
    nico.init("nico","tests")
    nico.createWindow("test",32,32,1)

  teardown:
    nico.shutdown()

  test "copyMemToScreen":
    var buffer: array[512,uint8]
    for i in 0..<512:
      buffer[i] = rnd(16).uint8
    for i in 0..10000:
      copyMemToScreen(rnd(128),rnd(128),rnd(128), buffer[0].addr)

  test "copyMemToScreen negative":
    var buffer: array[512,uint8]
    for i in 0..<512:
      buffer[i] = rnd(16).uint8
    for i in 0..10000:
      copyMemToScreen(rnd(128)-64,rnd(128)-64,rnd(128)-64, buffer[0].addr)

  test "copyPixelsToMem":
    var buffer: array[512,uint8]
    for i in 0..10000:
      copyPixelsToMem(rnd(128),rnd(128),rnd(512), buffer[0].addr)
