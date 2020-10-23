import nico
import nico/vec
import math

var angle = 0f
var mode = 0
var pos: Vec2f

proc gameInit() =
  # load all our assets
  loadSpriteSheet(0, "rotation.png", 16, 16)
  angle = 0f
  pos = vec2f(screenWidth div 2, screenHeight div 2)

proc gameUpdate(dt: Pfloat) =
  if btn(pcLeft):
    angle -= 3f * dt
  if btn(pcRight):
    angle += 3f * dt
  if btn(pcUp):
    pos += angle.angleToVec * 50f * dt

  if btnp(pcA):
    mode += 1
    if mode > 2:
      mode = 0

proc gameDraw() =
  cls()
  if mode == 0:
    sprRot(0, pos.x, pos.y, angle, 1, 1)
  elif mode == 1:
    sprRot(1, pos.x, pos.y, angle, 2, 1)
  else:
    sprRot(3, pos.x, pos.y, angle, 1, 2)

# initialization
nico.init("nico", "test")

# we want a fixed sized screen with perfect square pixels
fixedSize(true)
integerScale(true)
# create the window
nico.createWindow("nico",128,128,4)

# start, say which functions to use for init, update and draw
nico.run(gameInit, gameUpdate, gameDraw)
