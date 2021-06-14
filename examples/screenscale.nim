import nico
import strformat

nico.init("nico","screenscale")

var test: seq[int]

proc gameInit() =
  discard

proc gameUpdate(dt: float32) =
  if btnp(pcA):
    fixedSize(not fixedSize())
  if btnp(pcB):
    integerScale(not integerScale())

  for i in 0..<1000:
    test.add(i)

  test = @[]


proc gameDraw() =
  cls()

  setColor(1)
  for y in countup(0, screenHeight, 16):
    hline(0, y, screenWidth)

  for x in countup(0, screenWidth, 16):
    vline(x, 0, screenHeight)

  setColor(12)
  box(0, 0, screenWidth, screenHeight)

  setColor(7)
  var y = 4
  print(&"canvas : {screenWidth}x{screenHeight}", 4, y)
  y += 10
  print(&"scale  : {getScreenScale()}", 4, y)
  y += 10
  #print(&"display: {displayWidth}x{displayHeight}", 4, y)
  y += 10
  print(&"fixedSize: {fixedSize()}", 4, y)
  y += 10
  print(&"integerScale: {integerScale()}", 4, y)
  y += 10
  print(&"mem: {getOccupiedMem()} / {getTotalMem()}", 4, y)

fixedSize(false)
integerScale(true)

nico.createWindow("screenscale", 128, 128, 3)

addResizeFunc(proc(w,h: int) =
  echo &"resized to {w}x{h}"
)

nico.run(gameInit, gameUpdate, gameDraw)
