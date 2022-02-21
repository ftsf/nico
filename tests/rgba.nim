import unittest
import nico

suite "palette":
  setup:
    nico.init("nico","tests")
    nico.createWindow("test",32,32,1,false)

  teardown:
    nico.shutdown()

  test "loadSpritesheet":
    loadSpritesheet(0, "spritesheet.png", 16, 16)
    spr(10,0,0)
    check(pgetRGB(0,0) == palCol(10))

  test "loadSpritesheetRGBA":
    loadSpritesheet(0, "spritesheetRGBA.png", 16, 16)
    spr(10,0,0)
    check(pgetRGB(0,0) == palCol(10))

  test "loadSpritesheetRGB":
    loadSpritesheet(0, "spritesheetRGB.png", 16, 16)
    spr(10,0,0)
    check(pgetRGB(0,0) == palCol(10))
