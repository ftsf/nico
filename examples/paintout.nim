import nico
import math

var frame = 0

# color
var t = 8.0

# paddle
var px = 64.0
var py = 120.0
var pxv = 0.0

# ball
var bx = 64.0
var by = 64.0
var bxv = 0.0
var byv = 0.0

var text: string
var splat = false
var clear = false

const textOptions = [
  "HELLO WORLD",
  "WELCOME TO NICO",
  "MEOW",
  "RIBBIT",
  "NIM IS FUN",
]

proc gameInit() =
  text = "HELLO WORLD"
  bxv = 0.5
  byv = 0.75

proc gameUpdate(dt: float) =
  frame += 1
  t += 0.1
  if t >= 16.0:
    t = 8.0

  # move paddle
  if btn(pcLeft):
    pxv -= 0.1
  if btn(pcRight):
    pxv += 0.1
  px += pxv
  pxv *= 0.95

  let tw = textWidth(text)
  if px - tw div 2 < 0:
    px = (tw div 2).float
  if px > screenWidth - tw div 2:
    px = (screenWidth - tw div 2).float

  # move ball
  bx += bxv
  by += byv
  byv += 0.1

  # hit the sides
  if bx > screenWidth - 4 or bx < 4:
    bxv = -bxv
    splat = true

  # hit paddle
  if by > screenHeight - 8 and bx > px - tw div 2 - 4 and bx < px + tw div 2 + 4:
    byv = -byv * 0.8 - 1.0
    bxv += pxv
    splat = true

  # restart
  if btnp(pcA) or by > screenHeight:
    bx = 64
    by = 64
    byv = -2.0
    bxv = rnd(2.0)-1.0
    clear = true

  if btnp(pcB):
    # switch text
    text = rnd(textOptions)

proc gameDraw() =
  # clear the at start and when we restart
  if frame == 1 or clear or btnp(pcA):
    setColor(1)
    rectfill(0,0,128,128)
    clear = false

  # draw the paddle
  setColor(t.int)
  printc(text, px, py)

  # drip effect
  for i in 0..<1000:
    let x = rnd(screenWidth)
    let y = rnd(screenHeight)
    let c = pget(x,y)
    if c != 1 or rnd(10) == 0:
      pset(x,y+1,c)

  # draw ball
  let d = sqrt(pow(bxv,2.0) + pow(byv,2.0))
  let ballSize = if d > 2.0: 2 elif d > 1.0: 3 elif d > 0.5: 4 else: 5 
  setColor(t.int)
  circfill(bx,by, ballSize)

  # some random dark splats
  if rnd(30) == 0:
    setColor(1)
    let x = rnd(128)
    let y = rnd(128)
    circfill(x,y,rnd(5)+3)
    for i in 0..rnd(30):
      circfill(x + rnd(30)-15, y + rnd(30)-15, rnd(2)+1)

  # splats at ball location during impact
  if splat:
    setColor(t.int)
    let x = bx + rnd(10)-5
    let y = by + rnd(10)-5
    circfill(x,y,rnd(10)+5)
    for i in 0..rnd(30):
      circfill(x + rnd(30)-15, y + rnd(30)-15, rnd(2)+1)
    splat = false


# initialization
nico.init("nico", "test")

# we want a fixed sized screen with perfect square pixels
fixedSize(true)
integerScale(true)

# create the window
nico.createWindow("nico",128,128,4)

# start, say which functions to use for init, update and draw
nico.run(gameInit, gameUpdate, gameDraw)
