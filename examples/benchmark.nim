import nico
import times
import strformat
import nico/utils

type BenchmarkMode = enum
  bmPoints
  bmLines
  bmHVLines
  bmRect
  bmRectfill
  bmCirc
  bmCircfill
  bmSprite
  bmSpriteIntScaled
  bmSpriteScaled
  bmSpriteRot
  bmSpriteShearRot
  bmTrifill
  bmTTrifill

var mode = bmPoints
var autoAdjust = false
var lastMs: float32

var useClip = false
var vsync = true

var toDraw: array[BenchmarkMode, int]
toDraw[bmPoints] = 50000
toDraw[bmLines] = 1000
toDraw[bmHVLines] = 2000
toDraw[bmRect] = 2000
toDraw[bmRectfill] = 2000
toDraw[bmCirc] = 2000
toDraw[bmCircfill] = 2000
toDraw[bmSprite] = 1000
toDraw[bmSpriteIntScaled] = 1000
toDraw[bmSpriteScaled] = 1000
toDraw[bmSpriteRot] = 1000
toDraw[bmSpriteShearRot] = 1000
toDraw[bmTrifill] = 1000
toDraw[bmTTrifill] = 1000

var avgMs = 0f

var time = 0f

var cx = 0
var cy = 0

var secondTimer = 0f
var framesRendered = 0
var framesRenderedLastSecond = 0

proc gameInit() =
  loadSpriteSheet(0, "spritesheet.png")
  vsync = getVSync()

proc gameUpdate(dt: float32) =
  time += dt

  secondTimer += getRealDt()
  if secondTimer >= 1f:
    secondTimer = 0f
    framesRenderedLastSecond = framesRendered
    framesRendered = 0

  cx = (sin(time / 5f) * 32f).int
  cy = (sin(time / 3f) * 32f).int

  if keyp(K_c):
    useClip = not useClip

  if keyp(K_v):
    vsync = not vsync
    setVSync(vsync)

  if btn(pcLeft) and toDraw[mode] > 0:
    toDraw[mode] -= 10
  if btn(pcRight):
    toDraw[mode] += 10
  if btnpr(pcDown) and toDraw[mode] > 1000:
    toDraw[mode] -= 1000
  if btnpr(pcUp):
    toDraw[mode] += 1000
  if btnp(pcA):
    mode.incWrap()
  if btnp(pcB):
    autoAdjust = not autoAdjust

  if autoAdjust:
    if lastMs < 15.0'f:
      toDraw[mode] += 100
    elif lastMs > 16.0'f:
      if toDraw[mode] > 100:
        toDraw[mode] -= 100

proc gameDraw() =
  cls()
  let tstart = getPerformanceCounter()
  var count = 0

  let toDraw = toDraw[mode]

  setCamera(cx,cy)

  if useClip:
    clip(10,10,screenWidth-1-20,screenHeight-1-20)

  case mode:
  of bmPoints:
    for i in 0..<toDraw:
      setColor(8+rnd(8))
      pset(rnd(screenWidth),rnd(screenHeight))
      count += 1
  of bmLines:
    for i in 0..<toDraw:
      setColor(8+rnd(8))
      line(rnd(screenWidth),rnd(screenHeight),rnd(screenWidth),rnd(screenHeight))
      count += 1
  of bmHVLines:
    for i in 0..<toDraw:
      setColor(8+rnd(8))
      if rnd(2) == 0:
        hline(rnd(screenWidth),rnd(screenHeight),rnd(screenWidth))
      else:
        vline(rnd(screenWidth),rnd(screenHeight),rnd(screenHeight))
      count += 1
  of bmRect:
    for i in 0..<toDraw:
      setColor(8+rnd(8))
      rect(rnd(screenWidth),rnd(screenHeight),rnd(screenWidth),rnd(screenHeight))
      count += 1
  of bmRectfill:
    for i in 0..<toDraw:
      setColor(8+rnd(8))
      rectfill(rnd(screenWidth),rnd(screenHeight),rnd(screenWidth),rnd(screenHeight))
      count += 1
  of bmCirc:
    for i in 0..<toDraw:
      setColor(8+rnd(8))
      circ(rnd(screenWidth),rnd(screenHeight),rnd(32))
      count += 1
  of bmCircfill:
    for i in 0..<toDraw:
      setColor(8+rnd(8))
      circfill(rnd(screenWidth),rnd(screenHeight),rnd(32))
      count += 1
  of bmSprite:
    for i in 0..<toDraw:
      spr(16+rnd(8), rnd(screenWidth),rnd(screenHeight))
      count += 1
  of bmSpriteIntScaled:
    for i in 0..<toDraw:
      sprs(16+rnd(8), rnd(screenWidth),rnd(screenHeight), 1, 1, 2, 2)
      count += 1
  of bmSpriteScaled:
    for i in 0..<toDraw:
      sprss(16+rnd(8), rnd(screenWidth),rnd(screenHeight), 1, 1, 4+rnd(32), 4+rnd(32))
      count += 1
  of bmSpriteRot:
    for i in 0..<toDraw:
      sprRot(16+rnd(8), rnd(screenWidth),rnd(screenHeight), rnd(TAU))
      count += 1
  of bmSpriteShearRot:
    for i in 0..<toDraw:
      sprShearRot(16+rnd(8), rnd(screenWidth),rnd(screenHeight), rnd(TAU))
      count += 1
  of bmTrifill:
    for i in 0..<toDraw:
      setColor(8+rnd(8))
      trifill(rnd(screenWidth),rnd(screenHeight),rnd(screenWidth),rnd(screenHeight),rnd(screenWidth),rnd(screenHeight))
      count += 1
  of bmTTrifill:
    for i in 0..<toDraw:
      let au = 0
      let av = 8
      let bu = 8
      let bv = 16
      let cu = 0
      let cv = 16
      ttrifill(rnd(screenWidth),rnd(screenHeight),au,av, rnd(screenWidth),rnd(screenHeight),bu,bv, rnd(screenWidth),rnd(screenHeight),cu,cv)
      count += 1

  let tend = getPerformanceCounter()
  let ms = ((tend - tstart)*1000).float / getPerformanceFrequency().float

  clip()
  setCamera()
  setColor(1)
  box(-cx,-cy,screenWidth, screenHeight)
  if useClip:
    setColor(8)
    box(10,10,screenWidth-20, screenHeight-20)


  let str = &"{mode}  x {toDraw} : {avgMs:0.2f}  ms"
  setColor(7)
  printOutline(str, 4, 4)
  if vsync:
    printOutline("vsync", 4, 14)
  else:
    printOutline("delay", 4, 14)


  lastMs = ms.float32

  avgMs = lerp(avgMs, lastMs, 0.25f)

  printOutline("fps: " & $framesRenderedLastSecond, 4, 24)
  framesRendered += 1

nico.init("nico","benchmark")
nico.createWindow("nico benchmark", 128, 128, 4, false)
nico.run(gameInit, gameUpdate, gameDraw)
