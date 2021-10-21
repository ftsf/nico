import nico

var hflip = false
var vflip = false
var scale = false
var
  cx = 0
  cy = 0

proc gameInit() =
  loadSpritesheet(0, "rotation.png", 16, 16)

proc gameUpdate(dt: Pfloat) =
  # restart
  if btnp(pcA):
    hflip = not hflip
  if btnp(pcB):
    vflip = not vflip
  if btnp(pcX):
    scale = not scale

  if btn(pcLeft):
    cx -= 1
  if btn(pcRight):
    cx += 1
  if btn(pcUp):
    cy -= 1
  if btn(pcDown):
    cy += 1

proc gameDraw() =
  cls()

  setCamera(cx,cy)

  setColor(1)
  box(64-8-1,64-8-1,18,18)

  if scale:
    sprs(0, 64 - 8, 64 - 8, 1, 1, 2, 2, hflip = hflip, vflip = vflip)
  else:
    spr(0, 64 - 8, 64 - 8, hflip = hflip, vflip = vflip)

# initialization
nico.init("nico", "test")

# we want a fixed sized screen with perfect square pixels
fixedSize(true)
integerScale(true)
# create the window
nico.createWindow("nico",128,128,4)

# start, say which functions to use for init, update and draw
nico.run(gameInit, gameUpdate, gameDraw)
