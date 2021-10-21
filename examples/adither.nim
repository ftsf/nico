import nico

var ditherLevel = 0.5f
var xorMode = false

proc gameInit() =
  setPalette(loadPalettePico8())

proc gameUpdate(dt: Pfloat) =
  if btn(pcUp):
    ditherLevel += 0.01f
  if btn(pcDown):
    ditherLevel -= 0.01f
  if btnp(pcA):
    xorMode.incWrap()

proc gameDraw() =
  cls()
  if xorMode:
    ditherADitherXor(ditherLevel)
  else:
    ditherADitherAdd(ditherLevel)
  setColor(7)
  boxfill(0,0,screenWidth,screenHeight)

  ditherNone()
  print($ditherLevel, 1, 1)
  setColor(0)
  print($ditherLevel, 1, 14)

# initialization
nico.init("nico", "test")

# we want a fixed sized screen with perfect square pixels
fixedSize(true)
integerScale(true)
# create the window
nico.createWindow("nico",128,128,4)

# start, say which functions to use for init, update and draw
nico.run(gameInit, gameUpdate, gameDraw)
