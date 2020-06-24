import unittest
import nico

suite "fonts":
  setup:
    nico.init("nico","tests")
    nico.createWindow("test",32,32,1,false)

  teardown:
    nico.shutdown()

  test "loadFont":
    loadFont(0,"font.png")
    print("hello world",0,0)
    flip()
