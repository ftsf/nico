import nico, nico/[tweaks, gui2]
import macros

tweaks("Main"):
  tweaks("Color"):
    tweak(color, 0, 0 .. 15)
  tweak(rotation, 0f, 0f..360f)
  tweak(drawing, false)

var someVal = 0
tweaks("otherPane"):
  addTweak("GivenName", someVal, -10..10)

proc gameInit() =
  setPalette(loadPalettePico8())

proc gameUpdate(dt: float32) =
  guiStartFrame()
  guiPos(screenWidth div 2, 0)
  guiSize(screenWidth div 2, screenHeight)
  tweaksGUI2()

proc gameDraw() =
  cls()
  guiDraw()

nico.init("nico","tweaks")
nico.createWindow("tweaker", 256, 256, 3)
nico.run(gameInit, gameUpdate, gameDraw)
