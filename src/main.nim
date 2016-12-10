import nico
import util

var t = 8.0

proc gameInit() =
  setWindowTitle("ldbase")
  setTargetSize(128,128)
  setScreenSize(256,256)

proc gameUpdate(dt: float) =
  t += 0.1
  if t >= 16.0:
    t = 8.0

proc gameDraw() =
  cls()
  setColor(1)
  rectfill(0,0,128,128)
  setColor(t.int)
  printc("hello world", screenWidth div 2, screenHeight div 2)

nico.init()
nico.run(gameInit, gameUpdate, gameDraw)
