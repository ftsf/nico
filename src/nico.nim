import basic2d
import sdl2
import sdl2.joystick
import sdl2.gamecontroller
import ringbuffer
import math
import algorithm
import strutils
import sequtils
export math.sin
import random
import nicocontroller
import unsigned
import os
import streams

export NicoController
export NicoControllerKind
export NicoAxis
export NicoButton
export btn
export btnp
export axis
export axisp

export KeyboardEventPtr
export Scancode

const deadzone* = int16.high div 2

var controllers: seq[NicoController]

var mapWidth* = 128
var mapHeight* = 128
var mapData = newSeq[uint8](mapWidth * mapHeight)

var spriteFlags: array[128, uint8]

type
  IntPoint2d* = object
    x*,y*: int

proc `-`*(a,b: IntPoint2d): IntPoint2d =
  result.x = a.x - b.x
  result.y = a.y - b.y

proc `+=`*(a: var IntPoint2d, b: IntPoint2d) =
  a.x += b.x
  a.y += b.y


type
  PhysicalInputType* = enum
    Key
    JButton
    JAxis
    JHat
  PhysicalInput* = object
    kind*: PhysicalInputType
    index*: int
    value*: int
  VirtualButton = object
    inputs: seq[PhysicalInput]

var virtualButtons*: array[2,array[10,seq[PhysicalInput]]] = [
  [
    @[
      PhysicalInput(kind: Key, index: SDL_SCANCODE_LEFT.int),
      PhysicalInput(kind: JHat, index: 0, value: SDL_HAT_LEFT.int),
      PhysicalInput(kind: JAxis, index: 0, value: -1),
    ],
    @[
      PhysicalInput(kind: Key, index: SDL_SCANCODE_RIGHT.int),
      PhysicalInput(kind: JHat, index: 0, value: SDL_HAT_RIGHT.int),
      PhysicalInput(kind: JAxis, index: 0, value: 1),
    ],
    @[
      PhysicalInput(kind: Key, index: SDL_SCANCODE_UP.int),
      PhysicalInput(kind: JHat, index: 0, value: SDL_HAT_UP.int),
    ],
    @[
      PhysicalInput(kind: Key, index: SDL_SCANCODE_DOWN.int),
      PhysicalInput(kind: JHat, index: 0, value: SDL_HAT_DOWN.int),
    ],
    @[
      # accel
      PhysicalInput(kind: Key, index: SDL_SCANCODE_Z.int),
      PhysicalInput(kind: JButton, index: 2, value: 1),
      PhysicalInput(kind: JButton, index: 7, value: 1),
    ],
    @[
      # brake
      PhysicalInput(kind: Key, index: SDL_SCANCODE_X.int),
      PhysicalInput(kind: JButton, index: 3, value: 1),
      PhysicalInput(kind: JButton, index: 6, value: 1),
    ],
    @[
      # boost
      PhysicalInput(kind: Key, index: SDL_SCANCODE_A.int),
      PhysicalInput(kind: JButton, index: 1, value: 1),
      PhysicalInput(kind: JButton, index: 4, value: 1),
    ],
    @[
      # shoot
      PhysicalInput(kind: Key, index: SDL_SCANCODE_S.int),
      PhysicalInput(kind: JButton, index: 0, value: 1),
    ],
    @[
      # start
      PhysicalInput(kind: Key, index: SDL_SCANCODE_P.int),
      PhysicalInput(kind: JButton, index: 9, value: 1),
    ],
    @[
      # back
      PhysicalInput(kind: Key, index: SDL_SCANCODE_ESCAPE.int),
      PhysicalInput(kind: JButton, index: 8, value: 1),
    ],
  ],
  [
    @[
      PhysicalInput(kind: Key, index: SDL_SCANCODE_LEFT.int),
    ],
    @[
      PhysicalInput(kind: Key, index: SDL_SCANCODE_RIGHT.int),
    ],
    @[
      PhysicalInput(kind: Key, index: SDL_SCANCODE_UP.int),
    ],
    @[
      PhysicalInput(kind: Key, index: SDL_SCANCODE_DOWN.int),
    ],
    @[
      PhysicalInput(kind: Key, index: SDL_SCANCODE_Z.int),
    ],
    @[
      PhysicalInput(kind: Key, index: SDL_SCANCODE_X.int),
    ],
    @[
      PhysicalInput(kind: Key, index: SDL_SCANCODE_LSHIFT.int),
    ],
    @[
      PhysicalInput(kind: Key, index: SDL_SCANCODE_SPACE.int),
    ],
    @[
      PhysicalInput(kind: Key, index: SDL_SCANCODE_RETURN.int),
    ],
    @[
      PhysicalInput(kind: Key, index: SDL_SCANCODE_ESCAPE.int),
    ],
  ],
]

var setControlMode = (-1,-1)

var frameRate* = 60
var timeStep* = 1/frameRate
var frameMult = 1

var basePath*: string

proc fps*(fps: int) =
  frameRate = fps
  timeStep = 1.0 / fps.float

proc fps*(): int =
  return frameRate

proc speed*(speed: int) =
  frameMult = speed

proc sgn*[T](x: T): T =
  if x < 0:
    return -1
  elif x > 0:
    return 1
  else:
    return 0

proc setControlInput*(pid, btn: int) =
  # after calling this, next input will be assigned to control
  setControlMode = (pid,btn)

proc setControl*(pid, btn: int, kind: PhysicalInputType, index: int, value: int = 0) =
  var phys = PhysicalInput(kind: kind, index: index, value: value)
  if not (phys in virtualButtons[pid][btn]):
    virtualButtons[pid][btn].add(phys)

proc setControl*(pid, btn: int, phys: PhysicalInput) =
  if not (phys in virtualButtons[pid][btn]):
    virtualButtons[pid][btn].add(phys)

proc parsePhysName*(physName: string): PhysicalInput =
  if physName.startsWith("jbutton"):
    var btnId = physName[7..physName.high].parseInt() - 1
    return PhysicalInput(kind: JButton, index: btnId)

  elif physName.startsWith("jhat"):
    var hatId = physName[4..4].parseInt() - 1
    var value = 0
    var valueName = physName[5..physName.high]
    if valueName == "left":
      value = SDL_HAT_LEFT.int
    elif valueName == "right":
      value = SDL_HAT_RIGHT.int
    elif valueName == "up":
      value = SDL_HAT_UP.int
    elif valueName == "down":
      value = SDL_HAT_DOWN.int
    else:
      raise newException(ValueError, "Invalid Hat Direction")
    return PhysicalInput(kind: JHat, index: hatId, value: value)

  elif physName.startsWith("jaxis"):
    var axisId = physName[5..5].parseInt() - 1
    var value = 1
    if physName[physName.high..physName.high] == "-":
      value = -1
    elif physName[physName.high..physName.high] == "+":
      value = 1
    return PhysicalInput(kind: JAxis, index: axisId, value: value)

  else:
    var scancode = getScancodeFromName(physName)
    if scancode != SDL_SCANCODE_UNKNOWN:
      return PhysicalInput(kind: Key, index: scancode.int, value: 0)
    else:
      raise newException(Exception, "unknown input name: " & physName)

proc setControl*(pid, btn: int, physName: string) =
  # convert physName into a Physical Input
  setControl(pid,btn,parsePhysName(physName))

proc clearControl*(pid, btn: int) =
  virtualButtons[pid][btn] = @[]

proc unsetControl*(pid, btn: int) =
  discard virtualButtons[pid][btn].pop()

proc getControlName*(pid, btn: int): string =
  var bits = newSeq[string]()
  for phys in virtualButtons[pid][btn]:
    if phys.kind == Key:
      bits.add(
        ($getKeyName(getKeyFromScancode(phys.index.Scancode))).toLower()
      )
    elif phys.kind == JButton:
      bits.add("jbutton" & $(phys.index + 1))
    elif phys.kind == JHat:
      var hatDir: string
      case phys.value.uint8:
      of SDL_HAT_LEFT:
         hatDir = "left"
      of SDL_HAT_RIGHT:
         hatDir = "right"
      of SDL_HAT_UP:
         hatDir = "up"
      of SDL_HAT_DOWN:
         hatDir = "down"
      else:
        hatDir = "?"
      bits.add("jhat" & $(phys.index + 1) & hatDir)
    elif phys.kind == JAxis:
      bits.add("jaxis" & $(phys.index + 1) & (if phys.value < 0: "-" else: "+"))
  return bits.join(",")


proc getControlPretty*(pid, btn: int): string =
  var bits = newSeq[string]()
  for phys in virtualButtons[pid][btn]:
    if phys.kind == Key:
      bits.add(
        "[" & ($getKeyName(getKeyFromScancode(phys.index.Scancode))).toLower() & "]"
      )
    elif phys.kind == JButton:
      bits.add("(B" & $(phys.index + 1) & ")")
    elif phys.kind == JHat:
      var hatDir: string
      case phys.value.uint8:
      of SDL_HAT_LEFT:
         hatDir = "left"
      of SDL_HAT_RIGHT:
         hatDir = "right"
      of SDL_HAT_UP:
         hatDir = "up"
      of SDL_HAT_DOWN:
         hatDir = "down"
      else:
        hatDir = "?"
      bits.add("(HAT" & $(phys.index + 1) & ":" & hatDir & ")")
    elif phys.kind == JAxis:
      bits.add("(" & (if phys.value < 0: "-" else: "+") & "AXIS" & $(phys.index + 1) & ")")
  return bits.join(", ")

proc intPoint2d*(x,y: int): IntPoint2d =
  result.x = x
  result.y = y

proc `+`*(a,b: IntPoint2d): IntPoint2d =
  result.x = a.x + b.x
  result.y = a.y + b.y

converter toIntPoint2d*(p: Point2d): IntPoint2d =
  result.x = p.x.int
  result.y = p.y.int

converter toPoint2d*(p: IntPoint2d): Point2d =
  result.x = p.x.float
  result.y = p.y.float

converter toBool32(x: bool): Bool32 =
  return Bool32(x)

converter toCint*(x: int): cint =
  return cint(x)

converter toCint*(x: float): cint =
  return cint(x)

when defined(opengl):
  import opengl

when not defined(emscripten):
  import sdl2.audio
  import sdl2.mixer

import math
import stb_image_write
import stb_image

var screenScale* = 4

var window: WindowPtr
var spriteSheets: array[16,SurfacePtr]
var spriteSheet: ptr SurfacePtr

var initFunc: proc()
var updateFunc: proc(dt:float)
var drawFunc: proc()
var keyFunc: proc(key: KeyboardEventPtr, down: bool): bool
var eventFunc: proc(event: Event): bool
var textFunc: proc(text: string): bool

var controllerAddedFunc: proc(controller: NicoController)
var controllerRemovedFunc: proc(controller: NicoController)

type
  Font* = ref object
    rects: array[256, Rect]
    surface: SurfacePtr

var font: Font

var render: RendererPtr
var hwCanvas: TexturePtr
var swCanvas: SurfacePtr
var swCanvas32: SurfacePtr

#var targetScreenWidth = 480
#var targetScreenHeight = 272
var targetScreenWidth = 240
var targetScreenHeight = 136

var screenWidth* = 480
var screenHeight* = 272

var screenPaddingX = 0
var screenPaddingY = 0

var srcRect = rect(0,0,screenWidth,screenHeight)
var dstRect = rect(screenPaddingX,screenPaddingY,screenWidth,screenHeight)

var frame* = 0

const maxPlayers* = 4

type
  ColorId* = range[0..15]

proc makeColor(r,g,b,a: int): Color =
  return (uint8(r),uint8(g),uint8(b),uint8(a))

var colors: array[16, Color] = [
  makeColor(0,0,0,255),
  makeColor(29,43,83,255),
  makeColor(126,37,83,255),
  makeColor(0,135,81,255),
  makeColor(171,82,54,255),
  makeColor(95,87,79,255),
  makeColor(194,195,199,255),
  makeColor(255,241,232,255),
  makeColor(255,0,77,255),
  makeColor(255,163,0,255),
  makeColor(255,240,36,255),
  makeColor(0,231,86,255),
  makeColor(41,173,255,255),
  makeColor(131,118,156,255),
  makeColor(255,119,168,255),
  makeColor(255,204,170,255),
]

var clipMinX, clipMaxX, clipMinY, clipMaxY: int
clipMaxX = screenWidth-1
clipMaxY = screenHeight-1
var clippingRect: Rect

proc clip*(x,y,w,h: int = 0) =
  if w == 0:
    # reset clip
    clipMinX = 0
    clipMaxX = screenWidth-1
    clipMinY = 0
    clipMaxY = screenHeight-1
    clippingRect.x = 0
    clippingRect.y = 0
    clippingrect.w = screenWidth - 1
    clippingrect.h = screenHeight - 1
  else:
    clipMinX = max(x, 0)
    clipMaxX = min(x+w-1, screenWidth-1)
    clipMinY = max(y, 0)
    clipMaxY = min(y+h-1, screenHeight-1)
    clippingRect.x = max(x, 0)
    clippingRect.y = max(y, 0)
    clippingrect.w = min(w, screenWidth - x)
    clippingrect.h = min(h, screenHeight - y)


proc btn*(b: NicoButton, player: range[0..7] = 0): bool =
  if player > controllers.high:
    return false
  return controllers[player].btn(b)

proc btnp*(b: NicoButton, player: range[0..7] = 0): bool =
  if player > controllers.high:
    return false
  return controllers[player].btnp(b)

proc jaxis*(axis: NicoAxis, player: range[0..7] = 0): float =
  if player > controllers.high:
    return 0.0
  return controllers[player].axis(axis)

proc keyState*(key: Scancode): bool =
  let keyState = sdl2.getKeyboardState(nil)

  return keyState[int(key)] != 0

const recordSeconds = 15

type Frame = seq[uint8]

var recordFrames: RingBuffer[Frame]

var cameraX = 0
var cameraY = 0

var paletteMapDraw: array[16, ColorId]
var paletteMapDisplay: array[16, ColorId]
var paletteTransparent: array[16, bool]
for i in 0..15:
  paletteMapDraw[i] = i
  paletteMapDisplay[i] = i
  paletteTransparent[i] = if i == 0: true else: false

proc pal*(a,b: ColorId) =
  paletteMapDraw[a] = b

proc pal*() =
  for i in 0..15:
    paletteMapDraw[i] = i

proc palt*(a: ColorId, trans: bool) =
  paletteTransparent[a] = trans

proc palt*() =
  for i in 0..15:
    paletteTransparent[i] = if i == 0: true else: false

proc convertToRGBA(indexPixels, rgbaPixels: pointer, spitch, dpitch, w,h: cint) =
  var indexPixels = cast[ptr array[int.high, uint8]](indexPixels)
  var rgbaPixels = cast[ptr array[int.high, uint8]](rgbaPixels)
  for y in 0..h-1:
    for x in 0..w-1:
      let c = colors[paletteMapDisplay[indexPixels[y*spitch+x]]]
      rgbaPixels[y*dpitch+(x*4)+3] = c.r
      rgbaPixels[y*dpitch+(x*4)+2] = c.g
      rgbaPixels[y*dpitch+(x*4)+1] = c.b
      rgbaPixels[y*dpitch+(x*4)] = c.a

proc convertToABGR(indexPixels, abgrPixels: pointer, spitch, dpitch, w,h: cint) =
  var indexPixels = cast[ptr array[int.high, uint8]](indexPixels)
  var abgrPixels = cast[ptr array[int.high, uint8]](abgrPixels)
  for y in 0..h-1:
    for x in 0..w-1:
      let c = colors[paletteMapDisplay[indexPixels[y*spitch+x]]]
      abgrPixels[y*dpitch+(x*4)+3] = c.a
      abgrPixels[y*dpitch+(x*4)+2] = c.b
      abgrPixels[y*dpitch+(x*4)+1] = c.g
      abgrPixels[y*dpitch+(x*4)] = c.r

proc flipQuick() =
  render.setRenderTarget(nil)
  # copy swCanvas to hwCanvas

  convertToRGBA(swCanvas.pixels, swCanvas32.pixels, swCanvas.pitch, swCanvas32.pitch, screenWidth, screenHeight)
  updateTexture(hwCanvas, nil, swCanvas32.pixels, swCanvas32.pitch)

  # copy hwCanvas to screen
  render.setDrawColor(5,5,10,255)
  render.clear()
  render.copy(hwCanvas,addr(srcRect),addr(dstRect))
  render.present()


proc flip*() =
  flipQuick()

  when true:
    if frame mod 2 == 0:
      var frame = newSeq[uint8](screenWidth*screenHeight)
      if frame != nil:
        copyMem(frame[0].addr, swCanvas.pixels, swCanvas.pitch * swCanvas.h)
        recordFrames.add([frame])

  sdl2.delay(0)

import strutils

proc saveRecording() =
  var i = 0
  echo "saveRecording"
  for j in 0..recordFrames.size:
    var frame = recordFrames[j]
    var abgr = newSeq[uint8](screenWidth*screenHeight*4)
    # convert RGBA to BGRA
    echo "converting frame: ", j
    convertToABGR(frame[0].addr, abgr[0].addr, swCanvas.pitch, screenWidth*4, screenWidth, screenHeight)
    discard write_png("screenshot-$1.png".format(($i).align(4,'0')).cstring, screenWidth, screenHeight, RgbAlpha, abgr[0].addr, screenWidth*4)
    i += 1

proc cls*() =
  var rect = rect(clipMinX,clipMinY,clipMaxX-clipMinX+1,clipMaxY-clipMinY+1)
  swCanvas.fillRect(addr(rect),0)

proc setCamera*(c: IntPoint2d) =
  cameraX = c.x
  cameraY = c.y

proc setCamera*(x,y: cint = 0) =
  cameraX = x
  cameraY = y

proc getCamera*(): Point2d =
  return point2d(cameraX.float,cameraY.float)

var currentColor: ColorId = 0

proc setColor*(colId: ColorId) =
  currentColor = colId

proc getColor*(): ColorId =
  return currentColor

proc getPixels(surface: SurfacePtr): ptr array[int.high, uint8] =
  return cast[ptr array[int.high, uint8]](surface.pixels)

{.push checks: off, optimization: speed.}
proc pset*(x,y: cint, c: int = -1) =
  let c = if c == -1: currentColor else: c
  var pixels = swCanvas.getPixels()
  let x = x-cameraX
  let y = y-cameraY
  if x < clipMinX or y < clipMinY or x > clipMaxX or y > clipMaxY:
    return
  pixels[y*swCanvas.pitch+x] = paletteMapDraw[c]

proc psetInner*(x,y: int, c: ColorId) =
  var pixels = swCanvas.getPixels()
  if x < clipMinX or y < clipMinY or x > clipMaxX or y > clipMaxY:
    return
  pixels[y*swCanvas.pitch+x] = c
{.pop.}

proc sset*(x,y: cint, c: int = -1) =
  let c = if c == -1: currentColor else: c
  var pixels = spriteSheet[].getPixels()
  if x < 0 or y < 0 or x > spriteSheet.w-1 or y > spriteSheet.h-1:
    raise newException(RangeError, "sset ($1,$2) out of bounds".format(x,y))
  pixels[y*spriteSheet.pitch+x] = paletteMapDraw[c]

proc sget*(x,y: cint): ColorId =
  if x > spriteSheet.w-1 or x < 0 or y > spriteSheet.h-1 or y < 0:
    return 0
  var pixels = spriteSheet[].getPixels()
  let color = pixels[y*spriteSheet.pitch+x]
  return color

proc pget*(x,y: cint): ColorId =
  if x > swCanvas.w-1 or x < 0 or y > swCanvas.h-1 or y < 0:
    return 0
  var pixels = swCanvas.getPixels()
  return pixels[y*swCanvas.pitch+x]

proc pset*(p: Point2d) =
  pset(p.x.int,p.y.int)

proc rectfill*(x1,y1,x2,y2: cint) =
  let minx = min(x1,x2)
  let maxx = max(x1,x2)
  let miny = min(y1,y2)
  let maxy = max(y1,y2)
  for y in miny..maxy:
    for x in minx..maxx:
      pset(x,y)

proc innerLine(x0,y0,x1,y1: cint) =
  var x = x0
  var y = y0
  var dx: cint = abs(x1-x0)
  var sx: cint = if x0 < x1: 1 else: -1
  var dy: cint = abs(y1-y0)
  var sy: cint = if y0 < y1: 1 else: -1
  var err: float = (if dx>dy: dx else: -dy).float/2.0
  var e2: float = 0

  while true:
    pset(x,y)
    if x == x1 and y == y1:
      break
    e2 = err
    if e2 > -dx:
      err -= dy.float
      x += sx
    if e2 < dy:
      err += dx.float
      y += sy

proc line*(x0,y0,x1,y1: cint) =
  if x0 == x1 and y0 == y1:
    pset(x0,y0)
  else:
    innerLine(x0,y0,x1,y1)

proc line*(a,b: IntPoint2d) =
  line(a.x,a.y,b.x,b.y)

proc hline(x0,y,x1: cint) =
  var x0 = x0
  var x1 = x1
  if x1<x0:
    swap(x1,x0)
  for x in x0..x1:
    pset(x,y)

proc rect*(x1,y1,x2,y2: int) =
  var r = sdl2.rect(
    x1,
    y1,
    (x2-x1)+1,
    (y2-y1)+1)

  let w = r.w-1
  let h = r.h-1
  let x = r.x
  let y = r.y
  # top
  line(x, y, x+w, y)
  # bottom
  line(x, y+h, x+w, y+h)
  # right
  line(x+w, y, x+w, y+h)
  # left
  line(x, y, x, y+h)

proc rect*(a,b: Point2d) =
  rect(a.x.int,a.y.int,b.x.int,b.y.int)

proc flr*(v: Point2d): Point2d =
  return point2d(v.x.floor(),v.y.floor())

proc flr*(v: float): float =
  return v.floor()

proc lerp[T](a, b: T, t: float): T =
  return a + (b - a) * t

type
  LineIterator = iterator(): (cint,cint)

{.push checks: off, optimization: speed.}
proc bresenham(x0,y0,x1,y1: cint): LineIterator =
  iterator p1(): (cint,cint) =
    var x = x0
    var y = y0
    var dx: cint = abs(x1-x0)
    var sx: cint = if x0 < x1: 1 else: -1
    var dy: cint = abs(y1-y0)
    var sy: cint = if y0 < y1: 1 else: -1
    var err: float = (if dx>dy: dx else: -dy).float/2.0
    var e2: float = 0

    while true:
      if x == x1 and y == y1:
        yield (x,y)
        break
      e2 = err
      if e2 > -dx:
        err -= dy.float
        x += sx
      if e2 < dy:
        err += dx.float
        y += sy
        yield (x,y)
  return p1

proc trifill*(x1,y1,x2,y2,x3,y3: cint) =
  var x1 = x1
  var x2 = x2
  var x3 = x3
  var y1 = y1
  var y2 = y2
  var y3 = y3

  if y2<y1:
    if y3<y2:
      swap(y1,y3)
      swap(x1,x3)
    else:
      swap(y1,y2)
      swap(x1,x2)
  else:
    if y3<y1:
      swap(y1,y3)
      swap(x1,x3)
  if y2>y3:
    swap(y3,y2)
    swap(x3,x2)

  var sx = x1
  var ex = x1
  var sy = y1
  var ey = y1

  var ac = bresenham(x1,y1,x3,y3)
  var ab = bresenham(x1,y1,x2,y2)
  var bc = bresenham(x2,y2,x3,y3)
  if y1 != y2:
    # draw flat bottom tri
    while true:
      (sx,sy) = ab()
      (ex,ey) = ac()
      hline(sx,sy,ex)
      if sy == y2:
        #discard bc()
        break

  hline(sx,sy,x2)

  if y2 != y3:
    # draw flat top tri
    while true:
      (sx,sy) = ac()
      (ex,ey) = bc()
      hline(sx,sy,ex)
      if sy == y3:
        break
{.pop.}


proc trifill2*(x1,y1,x2,y2,x3,y3: cint) =
  var x1 = x1
  var x2 = x2
  var x3 = x3
  var y1 = y1
  var y2 = y2
  var y3 = y3

  if y2<y1:
    if y3<y2:
      swap(y1,y3)
      swap(x1,x3)
    else:
      swap(y1,y2)
      swap(x1,x2)
  else:
    if y3<y1:
      swap(y1,y3)
      swap(x1,x3)
  if y2>y3:
    swap(y3,y2)
    swap(x3,x2)

  assert(y1<=y2)
  assert(y2<=y3)
  assert(y1<=y3)

  type Edge = tuple[xint, xfrac, dxint, dxfrac, dy, life: int]

  proc initEdge(px,py,qx,qy: int): Edge =
    var x: int
    var dx, dy: int

    var e: Edge

    dx = qx - px
    dy = qy - py

    e.life = dy
    dy += dy
    e.dy = dy

    if dy == 0:
      return e

    x = px * e.dy + dx

    e.xint = int(x / dy)
    e.xfrac = int(x mod dy)

    if e.xfrac < 0:
      e.xint -= 1
      e.xfrac += dy

    dx += dx
    e.dxint = int(dx / dy)
    e.dxfrac = int(dx mod dy)

    if e.dxfrac < 0:
      e.dxint -= 1
      e.dxfrac += dy
    return e

  proc advanceEdge(e: var Edge) =
    e.xint += e.dxint
    e.xfrac += e.dxfrac
    if e.xfrac >= e.dy:
      e.xfrac -= e.dy
      e.xint += 1
    e.life -= 1


  var longEdge  = initEdge(x1,y1,x3,y3)
  var shortEdge = initEdge(x1,y1,x2,y2)
  var line = y1

  while shortEdge.life > 0:
    hline(longEdge.xint, line, shortEdge.xint)
    line += 1
    advanceEdge(longEdge)
    advanceEdge(shortEdge)

  shortEdge = initEdge(x2,y2,x3,y3)
  while longEdge.life > 0:
    hline(longEdge.xint, line, shortEdge.xint)
    line += 1
    advanceEdge(longEdge)
    advanceEdge(shortEdge)

  line(x1,y1,x2,y2)
  line(x2,y2,x3,y3)
  line(x3,y3,x1,y1)

proc trifill*(a,b,c: IntPoint2d) =
  trifill(a.x,a.y,b.x,b.y,c.x,c.y)

proc plot4pointsfill(cx,cy,x,y: cint) =
  hline(cx - x, cy + y, cx + x)
  if x != 0 and y != 0:
    hline(cx - x, cy - y, cx + x)

proc circfill*(cx,cy,r: cint) =
  if r == 1:
      pset(cx,cy)
      pset(cx-1,cy)
      pset(cx+1,cy)
      pset(cx,cy-1)
      pset(cx,cy+1)
      return

  var err = -r
  var x = r
  var y = cint(0)

  while x >= y:
      var lasty = y
      err += y
      y += 1
      err += y

      plot4pointsfill(cx,cy,x,lasty)

      if err > 0:
        if x != lasty:
          plot4pointsfill(cx,cy,lasty,x)
        err -= x
        x -= 1
        err -= x

proc circ*(cx,cy,r: cint) =
  if r == 1:
      pset(cx-1,cy)
      pset(cx+1,cy)
      pset(cx,cy-1)
      pset(cx,cy+1)
      return

  var err = -r
  var x = r
  var y = cint(0)

  while x >= y:
    pset(cx + x, cy + y)
    pset(cx + y, cy + x)
    pset(cx - y, cy + x)
    pset(cx - x, cy + y)

    pset(cx - x, cy - y)
    pset(cx - y, cy - x)
    pset(cx + y, cy - x)
    pset(cx + x, cy - y)

    y += 1
    err += 1 + 2*y
    if 2*(err-x) + 1 > 0:
      x -= 1
      err += 1 - 2*x

proc arc*(cx,cy,r: cint, startAngle, endAngle: float) =
  let startX = cos(startAngle) * r
  let startY = sin(startAngle) * r
  let endX = cos(endAngle) * r
  let endY = sin(endAngle) * r

  if r == 1:
      pset(cx-1,cy)
      pset(cx+1,cy)
      pset(cx,cy-1)
      pset(cx,cy+1)
      return

  var err = -r
  var x = r
  var y = cint(0)

  while x >= y:
    if x >= startX and x < endX and y >= startY and y < endY:
      pset(cx + x, cy + y)
      pset(cx + y, cy + x)
      pset(cx - y, cy + x)
      pset(cx - x, cy + y)

      pset(cx - x, cy - y)
      pset(cx - y, cy - x)
      pset(cx + y, cy - x)
      pset(cx + x, cy - y)

    y += 1
    err += 1 + 2*y
    if 2*(err-x) + 1 > 0:
      x -= 1
      err += 1 - 2*x


proc fontBlit(src, dst: SurfacePtr, srcRect, dstRect: Rect, color: ColorId) =
  let sPitch = src.pitch
  let dPitch = dst.pitch
  var dx = dstRect.x.float
  var dy = dstRect.y.float
  var srcPixels = src.getPixels()
  var dstPixels = dst.getPixels()
  var sx = srcRect.x.float
  var sy = srcRect.y.float
  let dw = dstRect.w.float
  let dh = dstRect.h.float
  let sw = srcRect.w.float
  let sh = srcRect.h.float
  for y in 0..dstRect.h-1:
    dx = dstRect.x.float
    sx = srcRect.x.float
    for x in 0..dstRect.w-1:
      if sx < 0 or sy < 0 or sx > src.w or sy > src.h:
        continue
      if dx < clipMinX or dy < clipMinY or dx > min(dst.w,clipMaxX) or dy > min(dst.h,clipMaxY):
        continue
      let srcCol = srcPixels[sy * sPitch + sx]
      if srcCol == 9:
        dstPixels[dy * dPitch + dx] = currentColor
      sx += 1.0 * (sw/dw)
      dx += 1.0
    sy += 1.0 * (sh/dh)
    dy += 1.0

proc overlap(a,b: Rect): bool =
  return not ( a.x > b.x + b.w or a.y > b.y + b.h or a.x + a.w < b.x or a.y + a.h < b.y )

proc blit(src, dst: SurfacePtr, srcRect, dstRect: Rect, hflip, vflip: bool = false, raw: bool = false) =
  var srcPixels = src.getPixels()
  var dstPixels = dst.getPixels()

  let sPitch = src.pitch
  let dPitch = dst.pitch

  var dx = dstRect.x.float
  var dy = dstRect.y.float
  var dw = dstRect.w.float
  var dh = dstRect.h.float

  var sx = srcRect.x.float
  var sy = srcRect.y.float
  var sw = srcRect.w.float
  var sh = srcRect.h.float

  # if dstrect doesn't overlap clipping rect, skip it
  if not overlap(dstrect, clippingRect):
    return

  if vflip:
    dy = dy + (dstRect.h - 1).float
    sy = sy + (srcRect.h - 1).float

  for y in 0..dstRect.h-1:
    if hflip:
      sx = (srcRect.x + srcRect.w-1).float
      dx = (dstRect.x + dstRect.w-1).float
    else:
      sx = srcRect.x.float
      dx = dstRect.x.float
    for x in 0..dstRect.w-1:
      if sx < 0 or sy < 0 or sx > src.w-1 or sy > src.h-1:
        continue
      if not (dx < clipMinX or dy < clipMinY or dx > min(dst.w,clipMaxX) or dy > min(dst.h,clipMaxY)):
        let srcCol = srcPixels[sy * sPitch + sx]
        if raw:
          dstPixels[dy * dPitch + dx] = srcCol
        else:
          if not paletteTransparent[srcCol]:
            dstPixels[dy * dPitch + dx] = paletteMapDraw[srcCol]
      if hflip:
        sx -= 1.0 * (sw/dw)
        dx -= 1.0
      else:
        sx += 1.0 * (sw/dw)
        dx += 1.0
    if vflip:
      sy -= 1.0 * (sh/dh)
      dy -= 1.0
    else:
      sy += 1.0 * (sh/dh)
      dy += 1.0

proc mset*(tx,ty: int, t: uint8) =
  mapData[ty * mapWidth + tx] = t

proc mget*(tx,ty: int): uint8 =
  return mapData[ty * mapWidth + tx]

proc contains[T](flags: T, bit: T): bool =
  return (flags.int and 1 shl bit.int) != 0

proc set[T](flags: var T, bit: T) =
  flags = (flags.int or 1 shl bit.int).T

proc unset[T](flags: var T, bit: T) =
  flags = (flags.int and (not 1 shl bit.int)).T

proc fget*(s: uint8): uint8 =
  return spriteFlags[s]

proc fget*(s: uint8, f: range[0..7]): bool =
  return spriteFlags[s].contains(f)

proc fset*(s: uint8, f: range[0..7]) =
  spriteFlags[s] = f

proc fset*(s: uint8, f: range[0..7], v: bool) =
  if v:
    spriteFlags[s].set(f)
  else:
    spriteFlags[s].unset(f)

proc takeScreenshot*() =
  render.setRenderTarget(hwCanvas)
  var surface = sdl2.createRGBSurface(0, screenWidth, screenHeight, 32, 0,0,0,0)
  discard render.readPixels(srcrect, SDL_PIXELFORMAT_RGB888, surface[].pixels, cint(screenWidth*4))
  discard write_png("screenshot.png", screenWidth, screenHeight, Rgb, surface.pixels, screenWidth*screenHeight*ord(Rgb))
  echo "saved screenshot"
  freeSurface(surface)

proc setFont(filename: string, chars: string): Font =
  var font = new(Font)
  var w,h: cint
  var components: Components
  var raw_pixels = load(filename.cstring(), addr(w), addr(h), addr(components), RgbAlpha)
  if raw_pixels == nil:
    echo "error loading font: ", filename
    quit(1)
  var pixels = cast[ptr array[uint32.high, uint8]](raw_pixels)

  # load pixels into a texture
  var surface = createRGBSurfaceFrom(pixels, w, h, 32, w*4, 0xff000000'u32, 0x00ff0000'u32, 0x0000ff00'u32, 0x000000ff'u32)
  font.surface = convertSurface(surface, swCanvas.format, 0)
  if font.surface == nil:
    echo getError()
    quit(1)

  var newChar = false
  let blankColor: Color = (pixels[0],pixels[1],pixels[2],pixels[3])
  var currentRect: Rect = (cint(0),cint(0),cint(0),cint(0))
  var i = 0
  let stride = w*4
  for x in 0..w-1:
    let color: Color = (pixels[x*4],pixels[x*4+1],pixels[x*4+2],pixels[x*4+3])
    if color == blankColor:
      currentRect.w = x - currentRect.x
      if currentRect.w != 0:
        # go down until we find blank or h
        currentRect.h = h-1
        for y in 0..h-1:
          let color: Color = (pixels[y*stride+x*4],pixels[y*stride+x*4+1],pixels[y*stride+x*4+2],pixels[y*stride+x*4+3])
          if color == blankColor:
            currentRect.h = y-2
        font.rects[cast[uint](chars[i])] = currentRect
        i += 1
      newChar = true
      currentRect.x = x + 1
  return font

proc print*(text: string, x,y: cint, scale: cint = 1) =
  var x = x - cameraX
  let y = y - cameraY
  for c in text:
    var src: Rect = font.rects[cast[uint8](c)]
    var dst: Rect = (x.cint, y.cint, src.w*scale, src.h*scale)
    fontBlit(font.surface, swCanvas, src, dst, currentColor)
    x += dst.w + scale

proc printr*(text: string, x,y: cint, scale: cint = 1) =
  let width = text.len() * 4 * scale
  print(text, x-width, y, scale)

proc printc*(text: string, x,y: cint, scale: cint = 1) =
  let width = text.len() * 4 * scale
  print(text, x-int(width/2), y, scale)

proc copy*(x1,y1,x2,y2,x3,y3,x4,y4: int) =
  var src: Rect = (x:cint(x1),y:cint(y1),w:cint(x2-x1),h:cint(y2-y1))
  var dst: Rect = (x:cint(x3),y:cint(y3),w:cint(x4-x3),h:cint(y4-y3))
  blit(swCanvas, swCanvas, src, dst, false, false, true)

proc mouse*(): IntPoint2d =
  var x,y, w,h: cint
  sdl2.getMouseState(addr(x),addr(y))
  x -= screenPaddingX*2
  y -= screenPaddingY*2
  x = x / screenScale
  y = y / screenScale
  return intPoint2d(x,y)

var mouseButtonState: int
var mouseButtonPState: int
var mouseWheelState: int

proc mousebtn*(filter: range[0..2]): bool =
  return (mouseButtonState and (1 shl filter)) != 0

proc mousebtn*(): int =
  return mouseButtonState

proc mousewheel*(): int =
  # return the mousewheel status, 0 normal, -1 or 1
  return mouseWheelState

proc mousebtnp*(filter: range[0..2]): bool =
  return (mouseButtonPState and (1 shl filter)) != 0

proc mousebtnp*(): int =
  return mouseButtonPState

var keepRunning = true
var mute = false

proc shutdown*() =
  keepRunning = false

proc setFullscreen*(fullscreen: bool) =
  if fullscreen:
    discard window.setFullscreen(SDL_WINDOW_FULLSCREEN_DESKTOP)
  else:
    discard window.setFullscreen(0)

proc resize(w,h: int) =
  # calculate screenScale based on size
  screenScale = max(1, min(
    (w.float / targetScreenWidth.float).ceil.int,
    (h.float / targetScreenHeight.float).ceil.int,
  ))

  let ratio = w.float / h.float
  let targetRatio = targetScreenWidth.float / targetScreenHeight.float

  screenWidth = targetScreenWidth
  screenHeight = (screenWidth.float * targetRatio).int

  echo "w: ", (screenWidth * screenScale), " of ", w
  screenPaddingX = (w - screenWidth * screenScale) div 2
  screenPaddingY = (h - screenHeight * screenScale) div 2

  echo "padding: ", screenPaddingX, " x ", screenPaddingY

  echo "resize event: scale: ", screenScale, ": ", w, " x ", h, " ( ", screenWidth, " x ", screenHeight, " )"
  # resize the buffers
  srcRect = sdl2.rect(0,0,screenWidth,screenHeight)
  dstRect = sdl2.rect(0,0,screenWidth,screenHeight)

  hwCanvas = render.createTexture(SDL_PIXELFORMAT_RGBA8888, SDL_TEXTUREACCESS_STREAMING, screenWidth, screenHeight)
  swCanvas = createRGBSurface(0, screenWidth, screenHeight, 8, 0, 0, 0, 0)
  swCanvas.format.palette.setPaletteColors(addr(colors[0]), 0, 16)
  swCanvas32 = createRGBSurface(0, screenWidth, screenHeight, 32, 0x000000ff'u32, 0x0000ff00'u32, 0x00ff0000'u32, 0xff000000'u32)
  discard render.setLogicalSize(screenWidth, screenHeight)
  render.setRenderTarget(hwCanvas)
  clip()
  cls()
  flipQuick()

  # clear the replay buffer
  recordFrames = newRingBuffer[Frame](recordSeconds * int(frameRate / 2))

proc setTargetSize*(w,h: int) =
  targetScreenWidth = w
  targetScreenHeight = h
  resize(screenWidth, screenHeight)

proc setScreenSize*(w,h: int) =
  window.setSize(w,h)
  resize(w,h)

proc appHandleEvent(evt: Event) =
  if evt.kind == QuitEvent:
    keepRunning = false

  elif evt.kind == MouseWheel:
    mouseWheelState = evt.wheel.y
  elif evt.kind == MouseButtonDown:
    discard captureMouse(true)
    if evt.button.button == BUTTON_LEFT:
      mouseButtonState = mouseButtonState or 1
      mouseButtonPState = mouseButtonPState or 1
    elif evt.button.button == BUTTON_RIGHT:
      mouseButtonState = mouseButtonState or 2
      mouseButtonPState = mouseButtonPState or 2
    elif evt.button.button == BUTTON_MIDDLE:
      mouseButtonState = mouseButtonState or 4
      mouseButtonPState = mouseButtonPState or 4

  elif evt.kind == MouseButtonUp:
    discard captureMouse(false)
    if evt.button.button == BUTTON_LEFT:
      mouseButtonState = mouseButtonState and not 1
    elif evt.button.button == BUTTON_RIGHT:
      mouseButtonState = mouseButtonState and not 2
    elif evt.button.button == BUTTON_MIDDLE:
      mouseButtonState = mouseButtonState and not 4

  elif evt.kind == ControllerDeviceAdded:
    for v in controllers:
      if v.sdlControllerId == evt.cdevice.which:
        return
    try:
      var controller = newNicoController(evt.cdevice.which)
      controllers.add(newNicoController(evt.cdevice.which))
      if controllerAddedFunc != nil:
        controllerAddedFunc(controller)
    except:
      discard

  elif evt.kind == ControllerDeviceRemoved:
    var indexToRemove = -1
    for i,v in mpairs(controllers):
      if v.sdlControllerId == evt.cdevice.which:
        if v.sdlController != nil:
          v.sdlController.close()
        indexToRemove = i
        break
    if indexToRemove > -1:
      if controllerRemovedFunc != nil:
        controllerRemovedFunc(controllers[indexToRemove])
      controllers.del(indexToRemove)


  elif evt.kind == ControllerButtonDown or evt.kind == ControllerButtonUp:
    let down = evt.kind == ControllerButtonDown
    for controller in mitems(controllers):
      if controller.sdlControllerId == evt.cbutton.which:
        case evt.cbutton.button.GameControllerButton:
        of SDL_CONTROLLER_BUTTON_A:
          controller.setButtonState(pcA, down)
        of SDL_CONTROLLER_BUTTON_B:
          controller.setButtonState(pcB, down)
        of SDL_CONTROLLER_BUTTON_X:
          controller.setButtonState(pcX, down)
        of SDL_CONTROLLER_BUTTON_Y:
          controller.setButtonState(pcY, down)
        of SDL_CONTROLLER_BUTTON_START:
          controller.setButtonState(pcStart, down)
        of SDL_CONTROLLER_BUTTON_BACK:
          controller.setButtonState(pcBack, down)
        of SDL_CONTROLLER_BUTTON_LEFTSHOULDER:
          controller.setButtonState(pcL1, down)
        of SDL_CONTROLLER_BUTTON_RIGHTSHOULDER:
          controller.setButtonState(pcR1, down)
        of SDL_CONTROLLER_BUTTON_DPAD_UP:
          controller.setButtonState(pcUp, down)
        of SDL_CONTROLLER_BUTTON_DPAD_DOWN:
          controller.setButtonState(pcDown, down)
        of SDL_CONTROLLER_BUTTON_DPAD_LEFT:
          controller.setButtonState(pcLeft, down)
        of SDL_CONTROLLER_BUTTON_DPAD_RIGHT:
          controller.setButtonState(pcRight, down)
        else:
          discard
        break

  elif evt.kind == ControllerAxisMotion:
    for controller in mitems(controllers):
      if controller.sdlControllerId == evt.caxis.which:
        let value = evt.caxis.value.float / int16.high.float
        case evt.caxis.axis.GameControllerAxis:
        of SDL_CONTROLLER_AXIS_LEFTX:
          controller.setAxisValue(pcXAxis, value)
        of SDL_CONTROLLER_AXIS_LEFTY:
          controller.setAxisValue(pcYAxis, value)
        of SDL_CONTROLLER_AXIS_TRIGGERLEFT:
          controller.setAxisValue(pcLTrigger, value)
        of SDL_CONTROLLER_AXIS_TRIGGERRIGHT:
          controller.setAxisValue(pcRTrigger, value)
        else:
          discard
        break

  elif evt.kind == WindowEvent:
    if evt.window.event == WindowEvent_Resized or evt.window.event == WindowEvent_Size_Changed:
      resize(evt.window.data1, evt.window.data2)

    render.setRenderTarget(nil)
    render.setDrawColor(0,0,0,255)
    render.clear()

  elif evt.kind == KeyDown or evt.kind == KeyUp:
    let sym = evt.key.keysym.sym
    let scancode = evt.key.keysym.scancode
    let down = evt.kind == Keydown
    if keyFunc != nil:
      if keyFunc(evt.key, down):
        return
    if sym == K_q and down and (int16(evt.key.keysym.modstate) and int16(KMOD_CTRL)) != 0:
      # ctrl+q to quit
      keepRunning = false

    elif sym == K_f and down and (int16(evt.key.keysym.modstate) and int16(KMOD_CTRL)) != 0:
      let flags = window.getFlags()
      if (flags and SDL_WINDOW_FULLSCREEN_DESKTOP) != 0:
        discard window.setFullscreen(0)
      else:
        discard window.setFullscreen(SDL_WINDOW_FULLSCREEN_DESKTOP)

    elif sym == K_m and down:
      when not defined(emscripten):
        if (int16(evt.key.keysym.modstate) and int16(KMOD_CTRL)) != 0:
          mute = not mute
          if mute:
            discard mixer.volume(0, 0)
            discard mixer.volume(1, 0)
            discard mixer.volume(2, 0)
            discard mixer.volume(3, 0)
            discard mixer.volumeMusic(0)
          else:
            discard mixer.volume(0, 255)
            discard mixer.volume(1, 255)
            discard mixer.volume(2, 255)
            discard mixer.volume(3, 255)
            discard mixer.volumeMusic(255)
    elif sym == K_F9 and down:
      saveRecording()

    if not evt.key.repeat:
      case scancode:
      of SDL_SCANCODE_UP:
        controllers[0].setButtonState(pcUp, down)
      of SDL_SCANCODE_DOWN:
        controllers[0].setButtonState(pcDown, down)
      of SDL_SCANCODE_LEFT:
        controllers[0].setButtonState(pcLeft, down)
      of SDL_SCANCODE_RIGHT:
        controllers[0].setButtonState(pcRight, down)

      of SDL_SCANCODE_Z:
        controllers[0].setButtonState(pcA, down)
      of SDL_SCANCODE_X:
        controllers[0].setButtonState(pcX, down)
      of SDL_SCANCODE_LSHIFT:
        controllers[0].setButtonState(pcB, down)
      of SDL_SCANCODE_C:
        controllers[0].setButtonState(pcY, down)
      of SDL_SCANCODE_RETURN:
        controllers[0].setButtonState(pcStart, down)
      of SDL_SCANCODE_BACKSPACE, SDL_SCANCODE_DELETE:
        controllers[0].setButtonState(pcBack, down)
      else:
        discard


var current_time = sdl2.getTicks()
var acc = 0.0
var next_time: uint32

when defined(emscripten):
  proc emscripten_set_main_loop(fun: proc() {.cdecl.}, fps,
    simulate_infinite_loop: cint) {.header: "<emscripten.h>".}
  proc emscripten_cancel_main_loop() {.header: "<emscripten.h>".}

proc step() {.cdecl.} =
  var evt: Event
  zeroMem(addr(evt), sizeof(Event))

  while pollEvent(evt):
    appHandleEvent(evt)

  next_time = getTicks()
  var diff = float(next_time - current_time)/1000.0 * frameMult.float
  if diff > timeStep * 2.0:
    diff = timeStep
  acc += diff
  current_time = next_time

  while acc > timeStep:

    for controller in mitems(controllers):
      controller.update()

    updateFunc(timeStep)

    for controller in mitems(controllers):
      controller.postUpdate()

    frame += 1
    if acc > timeStep and acc < timeStep+timeStep:
      drawFunc()
      flip()

    mouseButtonPState = 0
    mouseWheelState = 0
    acc -= timeStep
    #delay(0)

proc setWindowTitle*(title: string) =
  window.setTitle(title)

proc setSpritesheet*(bank: range[0..15] = 0) =
  spriteSheet = spriteSheets[bank].addr

proc loadSpriteSheet*(filename: string) =
  var w,h: cint
  var components: Components
  var raw_pixels = load((basePath & "/assets/" & filename).cstring(), addr(w), addr(h), addr(components), RgbAlpha)
  if raw_pixels == nil:
    echo "error loading spriteSheet: ", filename
    quit(1)
  var pixels = cast[ptr array[uint32.high, uint8]](raw_pixels)

  spriteSheet[] = createRGBSurface(128, 128, 8)
  spriteSheet.format.palette.setPaletteColors(addr(colors[0]), 0, 16)
  if spriteSheet == nil:
    echo getError()
    quit(1)

  var ipixels = spriteSheet[].getPixels()
  for y in 0..h-1:
    for x in 0..w-1:
      let r = pixels[(y*w*4)+(x*4)]
      let g = pixels[(y*w*4)+(x*4)+1]
      let b = pixels[(y*w*4)+(x*4)+2]
      let c = mapRGB(spriteSheet.format, r,g,b)
      ipixels[y*spriteSheet.pitch+x] = c.uint8

proc getSprRect(spr: range[0..255], w,h: cint = 1): Rect {.inline.} =
  result.x = spr%%16 * 8
  result.y = spr div 16 * 8
  result.w = w * 8
  result.h = h * 8

proc spr*(spr: range[0..255], x,y: cint, w,h: cint = 1, hflip, vflip: bool = false) =
  var src = getSprRect(spr, w, h)
  var dst: Rect = sdl2.rect(x-cameraX,y-cameraY,8*w,8*h)
  let flip = (if hflip: SDL_FLIP_HORIZONTAL else: 0) or (if vflip: SDL_FLIP_VERTICAL else: 0)
  blit(spriteSheet[], swCanvas, src, dst)

proc sprs*(spr: range[0..255], x,y: cint, w,h: cint = 1, dw,dh: cint = 1, hflip, vflip: bool = false) =
  var src = getSprRect(spr, w, h)
  var dst: Rect = sdl2.rect(x-cameraX,y-cameraY,dw*8,dh*8)
  let flip = (if hflip: SDL_FLIP_HORIZONTAL else: 0) or (if vflip: SDL_FLIP_VERTICAL else: 0)
  blit(spriteSheet[], swCanvas, src, dst)

proc drawTile(spr: range[0..255], x,y: cint, tileSize = 8) =
  var src = getSprRect(spr)
  var dst: Rect = sdl2.rect(x-cameraX,y-cameraY,tileSize,tileSize)
  blit(spriteSheet[], swCanvas, src, dst)

proc sspr*(sx,sy: int, sw,sh: int, dx,dy: int, dw,dh: int = -1, hflip, vflip: bool = false) =
  var src: Rect = sdl2.rect(sx,sy,sw,sh)
  let dw = if dw >= 0: dw else: sw
  let dh = if dh >= 0: dh else: sh
  var dst: Rect = sdl2.rect(dx-cameraX,dy-cameraY,dw,dh)
  let flip = (if hflip: SDL_FLIP_HORIZONTAL else: 0) or (if vflip: SDL_FLIP_VERTICAL else: 0)
  blit(spriteSheet[], swCanvas, src, dst)

proc mapDraw*(tx,ty, tw,th, dx,dy: int, scale: float = 1.0) =
  # draw map tiles to the screen
  var xi = dx
  var yi = dy
  var increment = (8.0 * scale).int
  for y in ty..ty+th-1:
    if y >= 0 and y < mapHeight:
      for x in tx..tx+tw-1:
        if x >= 0  and x < mapWidth:
          let t = mapData[y * mapWidth + x]
          if t != 0:
            drawTile(t, xi, yi, increment)
        xi += increment
    yi += increment
    xi = dx

proc `%%/`[T](x,m: T): T =
  return (x mod m + m) mod m

proc saveMap*(filename: string) =
  createDir(basePath & "assets/maps")
  var fs = newFileStream(basePath & "assets/maps/" & filename, fmWrite)
  fs.write(mapWidth.int32)
  fs.write(mapHeight.int32)
  for y in 0..mapHeight-1:
    for x in 0..mapWidth-1:
      let t = mget(x,y)
      fs.write(t.uint8)
  fs.close()
  echo "saved map: " & $mapWidth & " x " & $mapHeight & " to: " & filename

proc loadMap*(filename: string) =
  createDir(basePath & "assets/maps")
  var fs = newFileStream(basePath & "assets/maps/" & filename, fmRead)
  mapWidth = fs.readInt32()
  mapHeight = fs.readInt32()
  mapData = newSeq[uint8](mapWidth*mapHeight)
  for y in 0..mapHeight-1:
    for x in 0..mapWidth-1:
      let t = fs.readInt8().uint8
      mset(x,y,t)
  fs.close()
  echo "loaded map: " & $mapWidth & " x " & $mapHeight

proc rnd*(x: int): int =
  return random(x)

proc rnd*(x: float): float =
  return random(x)

proc rnd*[T](a: openarray[T]): T =
  return random(a)

proc getControllers*(): seq[NicoController] =
  return controllers

# Configuration

import parseCfg
var config: Config

proc loadConfig*() =
  # TODO check for config file in user config directioy, use that first
  config = loadConfig(basePath & "/config.ini")
  echo "loaded config from " & basePath & "/config.ini"

proc saveConfig*() =
  # TODO write config file in user config directioy
  config.writeConfig(basePath & "/config.ini")
  echo "saved config to " & basePath & "/config.ini"

proc updateConfigValue*(section, key, value: string) =
  config.setSectionKey(section, key, value)

proc getConfigValue*(section, key: string): string =
  result = config.getSectionValue(section, key)


type
  MusicId = range[-1..63]
  SfxId = range[-1..63]

var currentMusicId: int = -1

when not defined(emscripten):
  var musicLibrary: array[64,ptr Music]
  var sfxLibrary: array[64,ptr Chunk]

  proc loadMusic*(musicId: MusicId, filename: string) =
    var music = mixer.loadMUS(basePath & "/assets/" & filename)
    if music != nil:
      musicLibrary[musicId] = music
      echo "loaded music[" & $musicId & ": " & $filename
    else:
      echo "Warning: error loading ", filename


  proc music*(musicId: MusicId) =
    var music = musicLibrary[musicId]
    if music != nil:
      currentMusicId = musicId
      discard mixer.playMusic(music, -1)

  proc getMusic*(): MusicId =
    return currentMusicId

  proc loadSfx*(sfxId: SfxId, filename: string) =
    var sfx = mixer.loadWAV(basePath & "/assets/" & filename)
    if sfx != nil:
      sfxLibrary[sfxId] = sfx
    else:
      echo "Warning: error loading ", filename

  proc sfx*(sfxId: SfxId, channel: range[-1..15] = -1, loop = 0) =
    if sfxId == -1:
      discard haltChannel(channel)
    else:
      var sfx = sfxLibrary[sfxId]
      if sfx != nil:
        discard playChannel(channel, sfx, loop)

  proc musicVol*(value: int) =
    discard mixer.volumeMusic(value)

  proc musicVol*(): int =
    return mixer.volumeMusic(-1)

  proc sfxVol*(value: int) =
    discard mixer.volume(-1, value)

  proc sfxVol*(): int =
    return mixer.volume(-1, -1)

else:
  proc loadMusic*(musicId: MusicId, filename: string) =
    discard
  proc loadSfx*(sfxId: SfxId, filename: string) =
    discard
  proc music*(musicId: MusicId) =
    discard
  proc sfx*(sfxId: SfxId, channel: range[-1..3] = -1, loop = 0) =
    discard
  proc getMusic*(): MusicId =
    return 0
  proc sfxVol*(value: int) =
    discard
  proc sfxVol*(): int =
    return 0
  proc musicVol*(value: int) =
    discard
  proc musicVol*(): int =
    return 0

var context: GlContextPtr

proc init*() =

  discard sdl2.setHint("SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS", "1")

  if sdl2.init(INIT_EVERYTHING) != SDL_Return(0):
    echo getError()
    quit(1)

  basePath = $sdl2.getBasePath()
  echo "basePath: ", basePath

  addQuitProc(proc() {.noconv.} =
    echo "sdl2 quit"
    sdl2.quit()
  )

  controllers = newSeq[NicoController]()

  # add keyboard controller
  var keyboardController = newNicoController(-1)
  controllers.add(keyboardController)

  discard gameControllerAddMappingsFromFile(basePath & "/assets/gamecontrollerdb.txt")

  for i in 0..numJoysticks():
    if isGameController(i):
      try:
        var controller = newNicoController(i)
        controllers.add(controller)
      except:
        discard

  randomize()

  window = createWindow("nico", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, (screenWidth+screenPaddingX*2)*screenScale, (screenHeight+screenPaddingY*2)*screenScale, SDL_WINDOW_SHOWN or SDL_WINDOW_RESIZABLE)
  render = createRenderer(window, -1, Renderer_Accelerated or Renderer_PresentVsync or Renderer_TargetTexture)

  swCanvas = createRGBSurface(0, screenWidth, screenHeight, 8, 0, 0, 0, 0)
  swCanvas.format.palette.setPaletteColors(addr(colors[0]), 0, 16)
  swCanvas32 = createRGBSurface(0, screenWidth, screenHeight, 32, 0x000000ff'u32, 0x0000ff00'u32, 0x00ff0000'u32, 0xff000000'u32)

  resize((screenWidth+screenPaddingX*2)*screenScale, (screenHeight+screenPaddingY*2)*screenScale)

  spriteSheet = spriteSheets[0].addr
  spriteSheet[] = createRGBSurface(0, 128, 128, 8, 0, 0, 0, 0)
  spriteSheet.format.palette.setPaletteColors(addr(colors[0]), 0, 16)

  font = setFont(basePath & "/assets/font.png", " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{:}~")
  discard sdl2.setHint("SDL_HINT_RENDER_VSYNC", "1")
  discard sdl2.setHint("SDL_RENDER_SCALE_QUALITY", "0")
  sdl2.showCursor(false)
  render.setRenderTarget(hwCanvas)

  when not defined(emscripten):
    if mixer.init(MIX_INIT_OGG) == -1:
      echo getError()
    if mixer.openAudio(44100, AUDIO_S16, MIX_DEFAULT_CHANNELS, 1024) == -1:
      echo "Error initialising audio: " & $sdl2.getError()
    else:
      addQuitProc(proc() {.noconv.} =
        echo "closing audio"
        discard mixer.closeAudio
      )

proc setInitFunc*(init: (proc())) =
  initFunc = init

proc setUpdateFunc*(update: (proc(dt:float))) =
  updateFunc = update

proc setKeyFunc*(key: (proc(key: KeyboardEventPtr, down: bool): bool)) =
  keyFunc = key

proc setEventFunc*(ef: proc(event: Event): bool) =
  eventFunc = ef

proc setTextFunc*(text: (proc(text: string): bool)) =
  if text == nil:
    stopTextInput()
  else:
    startTextInput()
  textFunc = text

proc hasTextFunc*(): bool =
  return textFunc != nil

proc setDrawFunc*(draw: (proc())) =
  drawFunc = draw

proc setControllerAdded*(cadded: proc(controller: NicoController)) =
  controllerAddedFunc = cadded

proc setControllerRemoved*(cremoved: proc(controller: NicoController)) =
  controllerRemovedFunc = cremoved

proc run*(init: (proc()), update: (proc(dt:float)), draw: (proc())) =
  assert(init != nil)
  assert(update != nil)
  assert(draw != nil)
  initFunc = init
  updateFunc = update
  drawFunc = draw

  initFunc()

  when defined(emscripten):
    emscripten_set_main_loop(step, cint(frameRate), cint(1))
  else:
    while keepRunning:
      step()

  when not defined(emscripten):
    mixer.closeAudio()
  sdl2.quit()
