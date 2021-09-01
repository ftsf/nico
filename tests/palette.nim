import unittest
import nico

suite "palette":
  setup:
    nico.init("nico","tests")
    nico.createWindow("test",32,32,1,false)

  teardown:
    nico.shutdown()

  test "loadPaletteFromGPL":
    setPalette(loadPaletteFromGPL("palette.gpl"))
    pset(0,0,1)
    check(palSize() == 32)
    check(pgetRGB(0,0) == (216'u8,118'u8,68'u8))

  test "loadPaletteFromGPL2":
    setPalette(loadPaletteFromGPL("aurora.gpl"))
    check(palCol(16) == (0'u8, 127'u8, 127'u8))
    pset(0,0,16)
    check(palSize() == 256)
    check(pgetRGB(0,0) == (0'u8, 127'u8, 127'u8))

  test "loadPaletteFromImage":
    setPalette(loadPaletteFromImage("palette.png"))
    check(palSize() == 32)
    pset(0,0,8)

  test "loadPaletteFromImage2":
    setPalette(loadPaletteFromImage("pal_aurora-1x.png"))
    check(palSize() == 256)
    check(palCol(16) == (0'u8, 127'u8, 127'u8))
    pset(0,0,16)
    check(pgetRGB(0,0) == (0'u8, 127'u8, 127'u8))

  test "loadPalettePico8Extra":
    setPalette(loadPalettePico8Extra())
    check(palSize() == 32)
    pset(0,0,16)

  test "loadPaletteCGA":
    setPalette(loadPaletteCGA())
    pset(0,0,1)
    check(palSize() == 4)
    check(pgetRGB(0,0) == (85'u8,255'u8,255'u8))
