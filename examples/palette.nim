import nico


proc gameInit() =
  setPalette(loadPalettePico8())
  loadSpriteSheet(0, "spritesheet.png")
  loadSpriteSheet(1, "spritesheetRGBA.png")

proc gameUpdate(dt: float32) =
  discard

proc gameDraw() =
  cls()
  setSpritesheet(0)
  for i in 0..<8:
    spr(16+i, i * 8, 0)
  setSpritesheet(1)
  for i in 0..<8:
    spr(16+i, i * 8, 8)

nico.init("nico","palette")
nico.createWindow("palette", 128, 128, 3)
nico.run(gameInit, gameUpdate, gameDraw)
