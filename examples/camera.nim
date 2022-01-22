import nico
import nico/vec
import std/math
import std/strformat

var cx,cy = 0
var useClipping = false

proc gameInit() =
  # load all our assets
  loadSpriteSheet(0, "rotation.png", 16, 16)
  loadMap(0, "map.json")
  setMap(0)

proc gameUpdate(dt: Pfloat) =
  # allow moving the camera
  if btn(pcLeft):
    cx -= 1
  if btn(pcRight):
    cx += 1
  if btn(pcUp):
    cy -= 1
  if btn(pcDown):
    cy += 1
  if btnp(pcA):
    useClipping = not useClipping

proc gameDraw() =
  cls()

  if useClipping:
    # clip rectangle is not affected by camera
    clip(16, 16, screenWidth - 32, screenHeight - 32)

  # you can create a parallax effect with multiple camera values
  setCamera(cx div 2,cy div 2)
  mapdraw(0, 0, 16, 16, 0, 0)

  setColor(8)
  printc("this should move slowly",64, 96)

  # set the camera position, future drawing operations will be offset
  setCamera(cx,cy)
  spr(4, 92, 92, 2, 2)

  setColor(8)
  pset(64,64)

  setColor(9)
  circ(64, 64, 9)

  setColor(9)
  printc("this should move",64, 32)

  clip()

  # disable the camera to draw HUD elements
  setCamera()
  setColor(7)
  printr("this should not move", 126, 2)
  print(&"camera: {cx:3},{cy:3}", 2, 122)


# initialization
nico.init("nico", "test")

# we want a fixed sized screen with perfect square pixels
fixedSize(true)
integerScale(true)
# create the window
nico.createWindow("nico",128,128,4)

# start, say which functions to use for init, update and draw
nico.run(gameInit, gameUpdate, gameDraw)
