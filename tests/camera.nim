import unittest
import nico

suite "camera":
  setup:
    nico.init("nico","tests")
    nico.createWindow("test",32,32,1,false)

  teardown:
    nico.shutdown()

  test "camera":
    setCamera()
    setColor(1)
    boxfill(0,0,1,1)
    check(pgetRaw(0,0) == 1)

    setColor(2)
    setCamera(-8,-8)
    boxfill(0,0,1,1)
    check(pgetRaw(8,8) == 2)

    setColor(3)
    setCamera(-16,-16)
    print("X", 0, 0)
    check(pgetRaw(16,16) == 3)
