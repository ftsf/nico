import unittest
import nico

suite "copymem":
  setup:
    nico.init("nico","tests")
    nico.createWindow("test",32,32,1)

  teardown:
    nico.shutdown()

  test "copyMemToScreen":
    var buffer = newSeq[uint8](512)
    for i in 0..<512:
      buffer[i] = rnd(16).uint8
    for i in 0..10000:
      copyMemToScreen(rnd(128),rnd(128), buffer)

  test "copyMemToScreen negative":
    var buffer = newSeq[uint8](512)
    for i in 0..<512:
      buffer[i] = rnd(16).uint8
    for i in 0..10000:
      copyMemToScreen(rnd(128)-64,rnd(128)-64, buffer)

  test "copyPixelsToMem":
    var buffer = newSeq[uint8](512)
    for i in 0..10000:
      copyPixelsToMem(rnd(128),rnd(128), buffer)
