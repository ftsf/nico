import nico
import math

proc gameInit() =
  discard

proc gameUpdate(dt: float32) =
  discard

proc gameDraw() =
  cls()
  stencilClear(0) # clear the stencil buffer to 0
  # draw background
  for i in 0..<100:
    setColor(rnd([5,6]))
    let w = rnd(screenWidth div 2)
    let h = rnd(screenHeight div 2)
    let x = rnd(screenWidth - w)
    let y = rnd(screenHeight - h)
    boxfill(x,y,w,h)

  # draw the hole of our donut onto the stencil buffer
  stencilMode(stencilAlways) # we want to ignore the value of the stencil buffer when drawing
  setStencilWrite(true) # we want to write to the stencil buffer (off by default)
  setStencilOnly(true) # we only want to write to the stencil buffer, not the screen
  setStencilRef(1) # 1 will be the stencil value we use to signify where we don't want to draw
  circfill(64 + sin(time() / 3f) * 4f,64 + sin(time() / 1.234f) * 4f,8)

  setStencilWrite(false) # done writing to stencil buffer, return to normal
  setStencilOnly(false)

  # draw the rest of the donut
  stencilMode(stencilNot) # now we want to only draw where the stencil buffer != 1 (stencil ref value)
  setColor(7)
  circfill(64,64,16.float32 + sin(time() / 3f) * 4f)

  # reset things for next frame
  stencilMode(stencilAlways)

# initialization
nico.init("nico", "test")

# we want a fixed sized screen with perfect square pixels
fixedSize(true)
integerScale(true)
# create the window
nico.createWindow("nico",128,128,4)

# start, say which functions to use for init, update and draw
nico.run(gameInit, gameUpdate, gameDraw)
