import std/[strformat, times]
import nico

const ScreenW = 256
const ScreenH = 256

type
  Bunny = object
    x, y, dx, dy: float

const BunnyW = 8
const BunnyH = 8
const BunnyDxMax = 4f
const Gravity = 0.1f
const BunnyRandomBounce = 2f
const BunnyAddPerClick = 100
var gameFrame = 0

proc init(T: type Bunny): Bunny = Bunny(dx: rnd(BunnyDxMax), dy: rnd(-5f, 5f))

proc update(b: var Bunny) =
  b.x += b.dx
  b.y += b.dy
  b.dy += Gravity
  if b.x < 0:
    b.dx = -b.dx
    b.x = 0
  elif b.x > ScreenW - BunnyW:
    b.dx = -b.dx
    b.x = ScreenW - BunnyW

  if b.y > ScreenH - BunnyH:
    b.dy = -0.85f * b.dy
    b.y = ScreenH - BunnyH
    if rnd(2) == 1:
      b.dy -= rnd(BunnyRandomBounce)
  elif b.y < 0:
    b.dy = 0
    b.y = 0

proc draw(b: Bunny, frame: int) =
  var row = 0
  if abs(b.dy) > abs(b.dx) * 2:
    if b.dy > 0:
      row = 3
    else:
      row = 2
  else:
    if b.dx > 0:
      row = 1
    else:
      row = 0
  spr(row * 4 + frame, b.x, b.y)

const InitialBunnies = 1000

var bunnies = newSeq[var Bunny]()

var lastTime = cpuTime()
var lastFPS = 0f
const FPSSmoothing = 0.95f

proc addBun() =
  bunnies.add(Bunny.init())

proc gameInit() =
  srand()
  loadSpriteSheet(0, "bunny.png", BunnyW, BunnyH)
  for i in 0..<InitialBunnies:
    addBun()
  for b in bunnies.mitems:
    b.dx = rnd(BunnyDxMax)
    b.dy = rnd(-5f, 5f)

proc gameUpdate(dt: float32) =
  if mousebtn(0):
    for i in 0..<BunnyAddPerClick:
      addBun()
  for b in bunnies.mitems:
    b.update

proc gameDraw() =
  cls(1)

  let bunnyFrame = (gameFrame div 10) mod 4
  gameFrame.inc
  for b in bunnies:
    b.draw(bunnyFrame)

  setColor(5)
  rectfill(0, 0, 47, 16)
  setColor(12)
  let currTime = cpuTime()
  let dt = currTime - lastTime
  lastTime = currTime
  let fps = lastFPS * FPSSmoothing + 1f / dt * (1 - FPSSmoothing)
  lastFPS = fps
  print(&"FPS: {fps:.2f}", 2, 2)
  print(&"Buns: {bunnies.len}", 2, 9)

  setColor(1)
  rectfill(ScreenW - 72, ScreenH - 16, ScreenW, ScreenH)
  setColor(7)
  printr("Nico Bunnymark", ScreenW - 2, ScreenH - 8)
  printr("Click to add buns", ScreenW - 2, ScreenH - 15)

nico.init("nico", "bunnymark")
nico.createWindow("nico bunnymark", ScreenW, ScreenH, 2, false)
nico.run(gameInit, gameUpdate, gameDraw)
