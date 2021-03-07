import unittest
import nico

suite "config":
  setup:
    nico.init("nico","tests")
    nico.createWindow("test",32,32,1)

  teardown:
    nico.shutdown()

  test "loadMap":
    loadSpriteSheet(0, "spritesheet.png", 16, 16)
    loadMap(0, "map.json")
    setMap(0)

    check(mapWidth() == 16)
    check(mapHeight() == 16)

  test "wrongTileSize":
    expect Exception:
      loadSpriteSheet(0, "spritesheet.png", 15, 15)

  test "mset mget":
    loadSpriteSheet(0, "spritesheet.png", 16, 16)
    loadMap(0, "map.json")
    setMap(0)

    check(mget(8,8) == 8)

    mset(8,8,0)
    check(mget(8,8) == 0)

  test "loadMap with layer":
    loadSpriteSheet(0, "spritesheet.png", 16, 16)
    loadMap(0, "map.json")
    loadMap(1, "map.json", layer = 1)

    setMap(0)
    check(mget(1,0) == 1)

    setMap(1)
    check(mget(1,0) == 7)

  test "loadMap layer out of range":
    expect RangeError:
      loadMap(0, "map.json", layer = -1)

    expect RangeError:
      loadMap(0, "map.json", layer = 2)

  test "mapDraw":
    loadSpriteSheet(0, "spritesheet.png", 16, 16)
    loadMap(0, "map.json")
    setMap(0)

    mapDraw(0,0,mapWidth(),mapHeight(),0,0)

    check(pget(16*1, 16*1) == 0)
    check(pget(16*1+8, 16*1+8) == 1)

  test "mapDrawFiltered":
    loadSpriteSheet(0, "spritesheet.png", 16, 16)
    loadMap(0, "map.json")
    setMap(0)

    # set tile 17 to have bit 0 set
    fset(17, 0, true)

    # set map filter to only draw tiles with 0 bit set
    mapFilter(0, true)

    mapDraw(0,0,mapWidth(),mapHeight(),0,0)

    # this tile (1,0) should not be drawn as it is tile 2 which has no flag bit set
    check(pget(16*1+8, 16*0+8) == 0)

    # this tile (1,1) should be drawn as it is tile 17 which set set flag bit 0
    check(pget(16*1+8, 16*1+8) == 1)
