import nico
import nico/vec
import math

const moveSpeed = 50f

var debugStencil = false

var a,b,c: Vec2f
var av,bv,cv: Vec2f

proc gameInit() =
  a = vec2f(rnd(0,screenWidth),rnd(0,screenHeight))
  b = vec2f(rnd(0,screenWidth),rnd(0,screenHeight))
  c = vec2f(rnd(0,screenWidth),rnd(0,screenHeight))
  av = vec2f(rnd(-moveSpeed,moveSpeed),rnd(-moveSpeed,moveSpeed))
  bv = vec2f(rnd(-moveSpeed,moveSpeed),rnd(-moveSpeed,moveSpeed))
  cv = vec2f(rnd(-moveSpeed,moveSpeed),rnd(-moveSpeed,moveSpeed))

proc gameUpdate(dt: float32) =
  a += av * dt
  b += bv * dt
  c += cv * dt

  if a.x < 0:
    a.x = 0
    av.x = -av.x
  if a.y < 0:
    a.y = 0
    av.y = -av.y
  if a.x > screenWidth - 1:
    a.x = (screenWidth - 1).float32
    av.x = -av.x
  if a.y > screenHeight - 1:
    a.y = (screenHeight - 1).float32
    av.y = -av.y

  if b.x < 0:
    b.x = 0
    bv.x = -bv.x
  if b.y < 0:
    b.y = 0
    bv.y = -bv.y
  if b.x > screenWidth - 1:
    b.x = (screenWidth - 1).float32
    bv.x = -bv.x
  if b.y > screenHeight - 1:
    b.y = (screenHeight - 1).float32
    bv.y = -bv.y

  if c.x < 0:
    c.x = 0
    cv.x = -cv.x
  if c.y < 0:
    c.y = 0
    cv.y = -cv.y
  if c.x > screenWidth - 1:
    c.x = (screenWidth - 1).float32
    cv.x = -cv.x
  if c.y > screenHeight - 1:
    c.y = (screenHeight - 1).float32
    cv.y = -cv.y

  if btnp(pcA):
    debugStencil = not debugStencil

proc gameDraw() =
  stencilClear(0) # clear the stencil buffer to 0
  cls()
  # draw background
  setColor(8)
  line(a.x,a.y,b.x,b.y)
  line(b.x,b.y,c.x,c.y)
  line(c.x,c.y,a.x,a.y)

  # draw the hole of our donut onto the stencil buffer
  setColor(-1) # color -1 means write 1 in stencil buffer
  circfill(64 + sin(time() / 3f) * 4f,64 + sin(time() / 1.234f) * 4f, 8 + sin(time() / 2.123f) * 4f)

  # draw the rest of the donut
  # by default we only draw where the stencil buffer != 0
  setColor(7)
  circfill(64,64,16.float32 + sin(time() / 2f) * 4f)

  if debugStencil:
    # draw blue everywhere where the stencil buffer == 0
    setColor(12)
    boxfill(0,0,screenWidth,screenHeight)

  setColor(10)
  print("stencil buffering with -1 color", 1, 1)

# initialization
nico.init("nico", "test")

# we want a fixed sized screen with perfect square pixels
fixedSize(true)
integerScale(true)
# create the window
nico.createWindow("nico",128,128,4)

# start, say which functions to use for init, update and draw
nico.run(gameInit, gameUpdate, gameDraw)
