import nico

proc gameInit() =
  discard

proc gameUpdate(dt: Pfloat) =
  discard

proc gameDraw() =
  cls()
  setColor(7)
  line(64,64,128,64)
  setColor(8)
  line(64,0,64,64)

# initialization
nico.init("nico", "test")

# we want a fixed sized screen with perfect square pixels
fixedSize(true)
integerScale(true)
# create the window
nico.createWindow("nico",128,128,4)

# start, say which functions to use for init, update and draw
nico.run(gameInit, gameUpdate, gameDraw)
