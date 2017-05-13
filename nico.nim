import sdl2 except rect
import sdl2.joystick
import sdl2.gamecontroller
import sdl2.haptic
import nico.ringbuffer
import math
import algorithm
import strutils
import json
import sequtils
export math.sin
import random
import nico.controller
import os
import times
import streams
import gifenc
import strscans
import parseCfg

when not defined(emscripten):
  import sdl2.audio
  import sdl2.mixer

import nico.stb_image
import nico.stb_image_write

import osproc

export NicoController
export NicoControllerKind
export NicoAxis
export NicoButton

export btn
export btnp
export btnpr
export axis
export axisp

export KeyboardEventPtr
export Scancode

## TYPES

type
  Pint* = int32
  ColorId* = range[0..15]
  Font = object
    rects: array[256, Rect]
    pixels: seq[uint8]
    width,height: int
  FontId* = range[0..3]
  MusicId* = range[-1..63]
  SfxId* = range[-1..63]
  Frame = seq[uint8]

type
  LineIterator = iterator(): (Pint,Pint)
  Edge = tuple[xint, xfrac, dxint, dxfrac, dy, life: int]

## CONSTANTS

const deadzone* = int16.high div 2
const gifScale = 2
const maxPlayers* = 4
const recordingEnabled = true

## CONVERTERS

converter toPint*(x: float): Pint {.inline.} =
  return x.Pint

converter toPint*(x: float32): Pint {.inline.} =
  return x.Pint

converter toPint*(x: int): Pint {.inline.} =
  return x.Pint



## GLOBALS
##

var focused = true
var recordSeconds = 30
var fullSpeedGif = true

var controllers: seq[NicoController]

var mapWidth* = 128
var mapHeight* = 128
var mapData = newSeq[uint8](mapWidth * mapHeight)

var spriteFlags: array[128, uint8]
var mixerChannels = 0


var frameRate* = 60
var timeStep* = 1/frameRate
var frameMult = 1

var basePath*: string # should be the current dir with the app
var writePath*: string # should be a writable dir

var screenScale = 4.0
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

var fonts: array[FontId, Font]
var font: ptr Font

var render: RendererPtr
var hwCanvas: TexturePtr
var swCanvas: SurfacePtr
var swCanvas32: SurfacePtr

var targetScreenWidth = 128
var targetScreenHeight = 128

var fixedScreenSize = true
var integerScreenScale = false

var screenWidth* = 128
var screenHeight* = 128

var screenPaddingX = 0
var screenPaddingY = 0

var srcRect = sdl2.rect(0,0,screenWidth,screenHeight)
var dstRect = sdl2.rect(screenPaddingX,screenPaddingY,screenWidth,screenHeight)

var frame* = 0

var colors: array[16, Color]

var recordFrame: Frame
var recordFrames: RingBuffer[Frame]

var cameraX: Pint = 0
var cameraY: Pint = 0

var paletteSize: range[0..16] = 16

var paletteMapDraw: array[256, ColorId]
var paletteMapDisplay: array[256, ColorId]
var paletteTransparent: array[256, bool]

for i in 0..<paletteSize.int:
  paletteMapDraw[i] = i
  paletteMapDisplay[i] = i
  paletteTransparent[i] = if i == 0: true else: false

var currentColor: ColorId = 0

var mouseButtonState: int
var mouseButtonPState: int
var mouseWheelState: int

var keepRunning = true
var mute = false

var current_time = sdl2.getTicks()
var acc = 0.0
var next_time: uint32

var config: Config

var currentMusicId: int = -1
var currentFontId: int = 0

var clipMinX, clipMaxX, clipMinY, clipMaxY: int
var clippingRect: Rect


## Public API

# Fonts
proc getFont*(): FontId
proc setFont*(fontId: FontId)

# Printing text
proc glyph*(c: char, x,y: Pint, scale: Pint = 1): Pint {.discardable, inline.}

proc print*(text: string, x,y: Pint, scale: Pint = 1)
proc printc*(text: string, x,y: Pint, scale: Pint = 1) # centered
proc printr*(text: string, x,y: Pint, scale: Pint = 1) # right aligned

proc textWidth*(text: string, scale: Pint = 1): Pint
proc glyphWidth*(c: char, scale: Pint = 1): Pint

# Colors
proc setColor*(colId: ColorId)
proc getColor*(): ColorId
proc loadPaletteFromGPL*(filename: string)
proc loadPalettePico8*()

proc pal*(a,b: ColorId) # maps one color to another
proc pal*() # resets palette
proc palt*(a: ColorId, trans: bool) # sets transparency for color
proc palt*() # resets transparency

# Clipping
proc clip*(x,y,w,h: Pint)
proc clip*()

# Camera
proc setCamera*(x,y: Pint = 0)
proc getCamera*(): (Pint,Pint)

# Input
proc btn*(b: NicoButton, player: range[0..maxPlayers] = 0): bool
proc btnp*(b: NicoButton, player: range[0..maxPlayers] = 0): bool
proc btnpr*(b: NicoButton, player: range[0..maxPlayers] = 0, repeat = 48): bool
proc jaxis*(axis: NicoAxis, player: range[0..maxPlayers] = 0): float
proc mouse*(): (Pint,Pint)
proc mousebtn*(filter: range[0..2]): bool
proc mousebtnp*(filter: range[0..2]): bool

## Drawing API

# pixels
proc pset*(x,y: Pint)
proc pget*(x,y: Pint): ColorId
proc sset*(x,y: Pint, c: int = -1)
proc sget*(x,y: Pint): ColorId

# rectangles
proc rectfill*(x1,y1,x2,y2: Pint)
proc rect*(x1,y1,x2,y2: Pint)

# line drawing
proc line*(x0,y0,x1,y1: Pint)
proc hline*(x0,y,x1: Pint)
proc vline*(x,y0,y1: Pint)

# triangles
proc trifill*(x1,y1,x2,y2,x3,y3: Pint)

# circles
proc circfill*(cx,cy: Pint, r: Pint)
proc circ*(cx,cy: Pint, r: Pint)

# sprites
proc spr*(spr: range[0..255], x,y: Pint, w,h: Pint = 1, hflip, vflip: bool = false)
proc sprs*(spr: range[0..255], x,y: Pint, w,h: Pint = 1, dw,dh: Pint = 1, hflip, vflip: bool = false)
proc sspr*(sx,sy, sw,sh, dx,dy: Pint, dw,dh: Pint = -1, hflip, vflip: bool = false)

# misc
proc copy*(sx,sy,dx,dy,w,h: Pint) # copy one area of the screen to another

## System functions
proc shutdown*()
proc createWindow*(title: string, w,h: Pint, scale: Pint = 2, fullscreen: bool = false)
proc initMixer*(channels: Pint)
proc init*(org: string, app: string)

# Tilemap functions
proc mset*(tx,ty: Pint, t: uint8)
proc mget*(tx,ty: Pint): uint8
proc mapDraw*(tx,ty, tw,th, dx,dy: Pint)
proc loadMap*(filename: string)
proc saveMap*(filename: string)

# Sound functions
proc loadSfx*(sfxId: SfxId, filename: string)
proc sfx*(sfxId: SfxId, channel: range[-1..15] = -1, loop = 0)
proc sfxVol*(value: int)

proc loadMusic*(musicId: MusicId, filename: string)
proc music*(musicId: MusicId)
proc musicVol*(value: int)

# Maths functions
proc flr*(x: float): float
proc lerp*[T](a,b: T, t: float): T

proc rnd*[T: Ordinal](x: T): T
proc rnd*[T](a: openarray[T]): T
proc rnd*(x: float): float

## Internal functions

proc flipQuick()
proc checkInput()
proc setRecordSeconds*(seconds: int)
proc setFullSpeedGif*(enabled: bool)
proc createRecordBuffer()

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



proc makeColor(r,g,b,a: int): Color =
  return (uint8(r),uint8(g),uint8(b),uint8(a))

proc loadPaletteFromGPL*(filename: string) =
  var fp = open(filename, fmRead)
  var i = 0
  for line in fp.lines():
    if i == 0:
      if scanf(line, "GIMP Palette"):
        i += 1
        continue
    if line[0] == '#':
      continue
    if line.len == 0:
      continue
    var r,g,b: int
    if scanf(line, "$s$i $s$i $s$i", r,g,b):
      echo "matched ", i-1, ":", r,",",g,",",b
      colors[i-1] = makeColor(r,g,b,255)
      if i > 15:
        break
      i += 1
    else:
      echo "not matched: ", line


proc loadPalettePico8*() =
  colors[0]  = makeColor(0,0,0,255)
  colors[1]  = makeColor(29,43,83,255)
  colors[2]  = makeColor(126,37,83,255)
  colors[3]  = makeColor(0,135,81,255)
  colors[4]  = makeColor(171,82,54,255)
  colors[5]  = makeColor(95,87,79,255)
  colors[6]  = makeColor(194,195,199,255)
  colors[7]  = makeColor(255,241,232,255)
  colors[8]  = makeColor(255,0,77,255)
  colors[9]  = makeColor(255,163,0,255)
  colors[10] = makeColor(255,240,36,255)
  colors[11] = makeColor(0,231,86,255)
  colors[12] = makeColor(41,173,255,255)
  colors[13] = makeColor(131,118,156,255)
  colors[14] = makeColor(255,119,168,255)
  colors[15] = makeColor(255,204,170,255)

clipMaxX = screenWidth-1
clipMaxY = screenHeight-1

proc clip*() =
  clipMinX = 0
  clipMaxX = screenWidth-1
  clipMinY = 0
  clipMaxY = screenHeight-1
  clippingRect.x = 0
  clippingRect.y = 0
  clippingRect.w = screenWidth - 1
  clippingRect.h = screenHeight - 1

proc clip*(x,y,w,h: Pint) =
  clipMinX = max(x, 0)
  clipMaxX = min(x+w-1, screenWidth-1)
  clipMinY = max(y, 0)
  clipMaxY = min(y+h-1, screenHeight-1)
  clippingRect.x = max(x, 0)
  clippingRect.y = max(y, 0)
  clippingRect.w = min(w, screenWidth - x)
  clippingRect.h = min(h, screenHeight - y)


proc btn*(b: NicoButton, player: range[0..maxPlayers] = 0): bool =
  if player > controllers.high:
    return false
  return controllers[player].btn(b)

proc btnp*(b: NicoButton, player: range[0..maxPlayers] = 0): bool =
  if player > controllers.high:
    return false
  return controllers[player].btnp(b)

proc btnpr*(b: NicoButton, player: range[0..maxPlayers] = 0, repeat = 48): bool =
  if player > controllers.high:
    return false
  return controllers[player].btnpr(b, repeat)

proc jaxis*(axis: NicoAxis, player: range[0..maxPlayers] = 0): float =
  if player > controllers.high:
    return 0.0
  return controllers[player].axis(axis)

proc keyState*(key: Scancode): bool =
  let keyState = sdl2.getKeyboardState(nil)

  return keyState[int(key)] != 0

proc pal*(a,b: ColorId) =
  paletteMapDraw[a] = b

proc pal*() =
  for i in 0..<paletteSize.int:
    paletteMapDraw[i] = i

proc palt*(a: ColorId, trans: bool) =
  paletteTransparent[a] = trans

proc palt*() =
  for i in 0..<paletteSize.int:
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

  when recordingEnabled:
    if recordSeconds > 0:
      if fullSpeedGif or frame mod 2 == 0:
        if recordFrame != nil:
          copyMem(recordFrame[0].addr, swCanvas.pixels, swCanvas.pitch * swCanvas.h)
          recordFrames.add([recordFrame])

  sdl2.delay(0)

proc saveScreenshot*() =
  createDir(writePath & "/screenshots")
  var frame = recordFrames[recordFrames.size-1]
  var abgr = newSeq[uint8](screenWidth*screenHeight*4)
  # convert RGBA to BGRA
  convertToABGR(frame[0].addr, abgr[0].addr, swCanvas.pitch, screenWidth*4, screenWidth, screenHeight)
  let filename = writePath & "/screenshots/screenshot-$1T$2.png".format(getDateStr(), getClockStr())
  discard write_png(filename.cstring, screenWidth, screenHeight, RgbAlpha, abgr[0].addr, screenWidth*4)
  echo "saved screenshot to: ", filename

proc saveRecording*() =
  # TODO: do this in another thread?
  echo "saveRecording"
  createDir(writePath & "/video")

  var palette: array[16,array[3,uint8]]
  for i in 0..15:
    palette[i] = [colors[i].r, colors[i].g, colors[i].b]

  let filename = writePath & "/video/video-$1T$2.gif".format(getDateStr(), getClockStr())

  var gif = newGIF(
    filename.cstring,
    (screenWidth*gifScale).uint16,
    (screenHeight*gifScale).uint16,
    palette[0][0].addr, 4, 0
  )

  echo "created gif"
  var pixels: ptr[array[int32.high, uint8]]

  let oldColor = getColor()

  for j in 0..recordFrames.size:
    var frame = recordFrames[j]
    if frame == nil:
      echo "empty frame. breaking."
      break

    pixels = cast[ptr array[int32.high, uint8]](gif.frame)

    if gifScale != 1:
      for y in 0..<screenHeight*gifScale:
        for x in 0..<screenWidth*gifScale:
          let sx = x div gifScale
          let sy = y div gifScale
          pixels[y*screenWidth*gifScale+x] = frame[sy*swCanvas.pitch+sx]
    else:
      copyMem(gif.frame, frame[0].addr, screenWidth*screenHeight)
    gif.add_frame(if fullSpeedGif: 2 else: 3)

    setColor(13)
    rectfill(0,screenHeight-7,screenWidth,screenHeight)
    setColor(7)
    printc("SAVING GIF $1%".format(((j.float / recordFrames.size.float)*100.0).int), screenWidth div 2, screenHeight - 6)
    flipQuick()

  gif.close()

  setColor(13)
  rectfill(0,screenHeight-7,screenWidth,screenHeight)
  setColor(7)
  printc("SAVED GIF. PRESS [F11] TO OPEN DIR.".format(filename), screenWidth div 2, screenHeight - 6)
  flipQuick()
  for i in 0..100:
    checkInput()
    sdl2.delay(10)

  setColor(oldColor)

proc cls*() =
  var rect = sdl2.rect(clipMinX,clipMinY,clipMaxX-clipMinX+1,clipMaxY-clipMinY+1)
  swCanvas.fillRect(addr(rect),0)

proc setCamera*(x,y: Pint = 0) =
  cameraX = x
  cameraY = y

proc getCamera*(): (Pint,Pint) =
  return (cameraX, cameraY)


proc setColor*(colId: ColorId) =
  currentColor = colId

proc getColor*(): ColorId =
  return currentColor

proc getPixels(surface: SurfacePtr): ptr array[int.high, uint8] {.inline.} =
  return cast[ptr array[int.high, uint8]](surface.pixels)

{.push checks: off, optimization: speed.}
proc pset*(x,y: Pint) =
  var pixels = swCanvas.getPixels()
  let x = x-cameraX
  let y = y-cameraY
  if x < clipMinX or y < clipMinY or x > clipMaxX or y > clipMaxY:
    return
  pixels[y*swCanvas.pitch+x] = paletteMapDraw[currentColor]

proc pset*(x,y: Pint, c: int) =
  var pixels = swCanvas.getPixels()
  let x = x-cameraX
  let y = y-cameraY
  if x < clipMinX or y < clipMinY or x > clipMaxX or y > clipMaxY:
    return
  pixels[y*swCanvas.pitch+x] = paletteMapDraw[c]

proc psetRaw*(x,y: int, c: ColorId) =
  var pixels = swCanvas.getPixels()
  let i = y*swCanvas.pitch+x
  if i >= 0 and i < swCanvas.pitch*swCanvas.h:
    pixels[i] = c
{.pop.}

proc sset*(x,y: Pint, c: int = -1) =
  let c = if c == -1: currentColor else: c
  var pixels = spriteSheet[].getPixels()
  if x < 0 or y < 0 or x > spriteSheet.w-1 or y > spriteSheet.h-1:
    raise newException(RangeError, "sset ($1,$2) out of bounds".format(x,y))
  pixels[y*spriteSheet.pitch+x] = paletteMapDraw[c]

proc sget*(x,y: Pint): ColorId =
  if x > spriteSheet.w-1 or x < 0 or y > spriteSheet.h-1 or y < 0:
    return 0
  var pixels = spriteSheet[].getPixels()
  let color = pixels[y*spriteSheet.pitch+x]
  return color

proc pget*(x,y: Pint): ColorId =
  if x > swCanvas.w-1 or x < 0 or y > swCanvas.h-1 or y < 0:
    return 0
  var pixels = swCanvas.getPixels()
  return pixels[y*swCanvas.pitch+x]

proc rectfill*(x1,y1,x2,y2: Pint) =
  let minx = min(x1,x2)
  let maxx = max(x1,x2)
  let miny = min(y1,y2)
  let maxy = max(y1,y2)
  for y in miny..maxy:
    for x in minx..maxx:
      pset(x,y)

proc innerLine(x0,y0,x1,y1: Pint) =
  var x = x0
  var y = y0
  var dx: int = abs(x1-x0)
  var sx: int = if x0 < x1: 1 else: -1
  var dy: int = abs(y1-y0)
  var sy: int = if y0 < y1: 1 else: -1
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

iterator lineIterator*(x0,y0,x1,y1: Pint): (Pint,Pint) =
  var x = x0
  var y = y0
  var dx: Pint = abs(x1-x0)
  var sx: Pint = if x0 < x1: 1 else: -1
  var dy: Pint = abs(y1-y0)
  var sy: Pint = if y0 < y1: 1 else: -1
  var err: float = (if dx>dy: dx else: -dy).float/2.0
  var e2: float = 0

  while true:
    yield (x,y)
    if x == x1 and y == y1:
      break
    e2 = err
    if e2 > -dx:
      err -= dy.float
      x += sx
    if e2 < dy:
      err += dx.float
      y += sy

proc line*(x0,y0,x1,y1: Pint) =
  if x0 == x1 and y0 == y1:
    pset(x0,y0)
  else:
    innerLine(x0,y0,x1,y1)

proc hline*(x0,y,x1: Pint) =
  var x0 = x0
  var x1 = x1
  if x1<x0:
    swap(x1,x0)
  for x in x0..x1:
    pset(x,y)

proc vline*(x,y0,y1: Pint) =
  var y0 = y0
  var y1 = y1
  if y1<y0:
    swap(y1,y0)
  for y in y0..y1:
    pset(x,y)

proc rect*(x1,y1,x2,y2: Pint) =
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
  hline(x, y, x+w)
  # bottom
  hline(x, y+h, x+w)
  # right
  vline(x+w, y+1, y+h-1)
  # left
  vline(x, y+1, y+h-1)

proc flr*(x: float): float =
  return x.floor()

proc lerp[T](a, b: T, t: float): T =
  return a + (b - a) * t

{.push checks: off, optimization: speed.}
proc bresenham(x0,y0,x1,y1: Pint): LineIterator =
  iterator p1(): (Pint,Pint) =
    var x = x0
    var y = y0
    var dx: Pint = abs(x1-x0)
    var sx: Pint = if x0 < x1: 1 else: -1
    var dy: Pint = abs(y1-y0)
    var sy: Pint = if y0 < y1: 1 else: -1
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

proc trifill*(x1,y1,x2,y2,x3,y3: Pint) =
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


proc trifill2*(x1,y1,x2,y2,x3,y3: Pint) =
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

proc plot4pointsfill(cx,cy,x,y: Pint) =
  hline(cx - x, cy + y, cx + x)
  if x != 0 and y != 0:
    hline(cx - x, cy - y, cx + x)

proc circfill*(cx,cy,r: Pint) =
  if r == 1:
      pset(cx,cy)
      pset(cx-1,cy)
      pset(cx+1,cy)
      pset(cx,cy-1)
      pset(cx,cy+1)
      return

  var err = -r
  var x = r
  var y = Pint(0)

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

proc circ*(cx,cy,r: Pint) =
  if r == 1:
      pset(cx-1,cy)
      pset(cx+1,cy)
      pset(cx,cy-1)
      pset(cx,cy+1)
      return

  var err = -r
  var x = r
  var y = Pint(0)

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

proc arc*(cx,cy,r: Pint, startAngle, endAngle: float) =
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
  var y = Pint(0)

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


proc fontBlit(font: ptr Font, dst: SurfacePtr, srcRect, dstRect: Rect, color: ColorId) =
  let dPitch = dst.pitch
  var dx = dstRect.x.float
  var dy = dstRect.y.float
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
      if sx < 0 or sy < 0 or sx > font.width or sy > font.height:
        continue
      if dx < clipMinX or dy < clipMinY or dx > min(dst.w,clipMaxX) or dy > min(dst.h,clipMaxY):
        continue
      if font.pixels[sy * font.width + sx] == 1:
        dstPixels[dy * dPitch + dx] = currentColor
      sx += 1.0 * (sw/dw)
      dx += 1.0
    sy += 1.0 * (sh/dh)
    dy += 1.0

proc overlap(a,b: Rect): bool =
  return not ( a.x > b.x + b.w or a.y > b.y + b.h or a.x + a.w < b.x or a.y + a.h < b.y )

proc blitFastRaw(src, dst: SurfacePtr, sx,sy, dx,dy, w,h: Pint) =
  # used for tile drawing, no stretch or flipping
  var srcPixels = src.getPixels()
  var dstPixels = dst.getPixels()

  let sPitch = src.pitch
  let dPitch = dst.pitch

  var sxi = sx
  var syi = sy
  var dxi = dx
  var dyi = dy

  while dyi < dy + h:
    if syi < 0 or syi > src.h-1 or dyi < clipMinY or dyi > min(dst.h-1,clipMaxY):
      syi += 1
      dyi += 1
      sxi = sx
      dxi = dx
      continue
    while dxi < dx + w:
      if sxi < 0 or sxi > src.w-1 or dxi < clipMinX or dxi > min(dst.w-1,clipMaxX):
        # ignore if it goes outside the source size
        dxi += 1
        sxi += 1
        continue
      let srcCol = srcPixels[syi * sPitch + sxi]
      dstPixels[dyi * dPitch + dxi] = srcCol
      sxi += 1
      dxi += 1
    syi += 1
    dyi += 1
    sxi = sx
    dxi = dx

proc blitFast(src, dst: SurfacePtr, sx,sy, dx,dy, w,h: Pint) =
  # used for tile drawing, no stretch or flipping
  var srcPixels = src.getPixels()
  var dstPixels = dst.getPixels()

  let sPitch = src.pitch
  let dPitch = dst.pitch

  var sxi = sx
  var syi = sy
  var dxi = dx
  var dyi = dy

  while dyi < dy + h:
    if syi < 0 or syi > src.h-1 or dyi < clipMinY or dyi > min(dst.h-1,clipMaxY):
      syi += 1
      dyi += 1
      sxi = sx
      dxi = dx
      continue
    while dxi < dx + w:
      if sxi < 0 or sxi > src.w-1 or dxi < clipMinX or dxi > min(dst.w-1,clipMaxX):
        # ignore if it goes outside the source size
        dxi += 1
        sxi += 1
        continue
      let srcCol = srcPixels[syi * sPitch + sxi]
      if not paletteTransparent[srcCol]:
        dstPixels[dyi * dPitch + dxi] = paletteMapDraw[srcCol]
      sxi += 1
      dxi += 1
    syi += 1
    dyi += 1
    sxi = sx
    dxi = dx

proc blit(src, dst: SurfacePtr, srcRect, dstRect: Rect, hflip, vflip: bool = false) =
  # if dstrect doesn't overlap clipping rect, skip it
  if not overlap(dstrect, clippingRect):
    return

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





proc blitStretch(src, dst: SurfacePtr, srcRect, dstRect: Rect, hflip, vflip: bool = false) =
  # if dstrect doesn't overlap clipping rect, skip it
  if not overlap(dstrect, clippingRect):
    return

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

proc mset*(tx,ty: Pint, t: uint8) =
  mapData[ty * mapWidth + tx] = t

proc mget*(tx,ty: Pint): uint8 =
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
  discard render.readPixels(srcrect.addr, SDL_PIXELFORMAT_RGB888.cint, surface[].pixels, cint(screenWidth*4))
  discard write_png("screenshot.png", screenWidth, screenHeight, Rgb, surface.pixels, screenWidth*screenHeight*ord(Rgb))
  echo "saved screenshot"
  freeSurface(surface)

proc loadFont*(filename: string, chars: string) =
  var w,h: cint
  var components: Components
  var raw_pixels = load(filename.cstring(), addr(w), addr(h), addr(components), RgbAlpha)
  if raw_pixels == nil:
    echo "error loading font: ", filename
    raise newException(IOError, "error loading font")
  var pixels = cast[ptr array[uint32.high, uint8]](raw_pixels)

  font[].pixels = newSeq[uint8](w*h)
  font[].width = w
  font[].height = h
  for i in 0..<w*h:
    let r = pixels[i*4]
    let g = pixels[i*4+1]
    let b = pixels[i*4+2]
    let a = pixels[i*4+3]
    if a == 0:
      font.pixels[i] = 0
    elif r > 0.uint8:
      font.pixels[i] = 2
    else:
      font.pixels[i] = 1
    echo i, ": ", font.pixels[i]

  var newChar = false
  let blankColor = font.pixels[0]
  var currentRect: Rect = (cint(0),cint(0),cint(0),cint(0))
  var i = 0
  for x in 0..w-1:
    let color = font.pixels[x]
    if color == blankColor:
      currentRect.w = x - currentRect.x
      if currentRect.w != 0:
        # go down until we find blank or h
        currentRect.h = h-1
        for y in 0..h-1:
          let color = font.pixels[y*w+x]
          if color == blankColor:
            currentRect.h = y-2
        font[].rects[cast[uint](chars[i])] = currentRect
        i += 1
      newChar = true
      currentRect.x = x + 1

proc glyph*(c: char, x,y: Pint, scale: Pint = 1): Pint =
  var src: Rect = font[].rects[cast[uint8](c)]
  var dst = sdl2.rect(x,y, src.w * scale, src.h * scale)
  fontBlit(font, swCanvas, src, dst, currentColor)
  return src.w * scale + scale

proc print*(text: string, x,y: Pint, scale: Pint = 1) =
  var x = x - cameraX
  let y = y - cameraY
  for c in text:
    x += glyph(c, x, y, scale)

proc glyphWidth*(c: char, scale: Pint = 1): Pint =
  var src: Rect = font[].rects[cast[uint8](c)]
  result += src.w*scale + scale

proc textWidth*(text: string, scale: Pint = 1): Pint =
  for c in text:
    var src: Rect = font[].rects[cast[uint8](c)]
    result += src.w*scale + scale

proc printr*(text: string, x,y: Pint, scale: Pint = 1) =
  let width = textWidth(text, scale)
  print(text, x-width, y, scale)

proc printc*(text: string, x,y: Pint, scale: Pint = 1) =
  let width = textWidth(text, scale)
  print(text, x-(width div 2), y, scale)

proc copy*(sx,sy,dx,dy,w,h: Pint) =
  blitFastRaw(swCanvas, swCanvas, sx, sy, dx, dy, w, h)

proc copyPixelsToMem*(sx,sy,n: Pint, buffer: pointer) =
  var pixels = swCanvas.getPixels()
  let offset = max(0,sy*swCanvas.pitch+sx)
  let endOffset = min(swCanvas.pitch * swCanvas.h, offset + n)
  copyMem(buffer, pixels[offset].addr, max(0,min(endOffset-offset,n)))

proc copyMemToScreen*(dx,dy,n: Pint, buffer: pointer) =
  var pixels = swCanvas.getPixels()
  let offset = max(0,dy*swCanvas.pitch+dx)
  let endOffset = min(swCanvas.pitch * swCanvas.h, offset + n)
  copyMem(pixels[offset].addr, buffer, max(0,min(endOffset-offset,n)))


proc mouse*(): (Pint,Pint) =
  var x,y: cint
  sdl2.getMouseState(addr(x),addr(y))
  #x -= screenPaddingX*2
  #y -= screenPaddingY*2
  x = x.float / screenScale
  y = y.float / screenScale
  return (x.Pint,y.Pint)

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

proc shutdown*() =
  keepRunning = false

proc setFullscreen*(fullscreen: bool) =
  if fullscreen:
    echo "setting fullscreen"
    discard window.setFullscreen(SDL_WINDOW_FULLSCREEN_DESKTOP)
  else:
    echo "setting windowed"
    discard window.setFullscreen(0)

proc getFullscreen*(): bool =
  return (window.getFlags() and SDL_WINDOW_FULLSCREEN_DESKTOP) != 0

proc resize(w,h: int) =
  # calculate screenScale based on size

  if integerScreenScale:
    screenScale = max(1.0, min(
      (w.float / targetScreenWidth.float).floor,
      (h.float / targetScreenHeight.float).floor,
    ))
  else:
    screenScale = max(1.0, min(
      (w.float / targetScreenWidth.float),
      (h.float / targetScreenHeight.float),
    ))

  var displayW,displayH: int

  if fixedScreenSize:
    displayW = (targetScreenWidth.float * screenScale).int
    displayH = (targetScreenHeight.float * screenScale).int

    # add padding
    screenPaddingX = ((w - displayW)) div 2
    screenPaddingY = ((h - displayH)) div 2
  else:
    screenPaddingX = 0
    screenPaddingY = 0

    displayW = w
    displayH = h

    if integerScreenScale:
      screenWidth = displayW div screenScale
      screenHeight = displayH div screenScale
    else:
      screenWidth = (displayW.float / screenScale).int
      screenHeight = (displayH.float / screenScale).int


  echo "resize event: scale: ", screenScale, ": ", displayW, " x ", displayH, " ( ", screenWidth, " x ", screenHeight, " )"
  # resize the buffers
  srcRect = sdl2.rect(0,0,screenWidth,screenHeight)
  dstRect = sdl2.rect(screenPaddingX,screenPaddingY,displayW, displayH)

  hwCanvas = render.createTexture(SDL_PIXELFORMAT_RGBA8888, SDL_TEXTUREACCESS_STREAMING, screenWidth, screenHeight)
  swCanvas = createRGBSurface(0, screenWidth, screenHeight, 8, 0, 0, 0, 0)
  swCanvas.format.palette.setPaletteColors(addr(colors[0]), 0, 16)
  swCanvas32 = createRGBSurface(0, screenWidth, screenHeight, 32, 0x000000ff'u32, 0x0000ff00'u32, 0x00ff0000'u32, 0xff000000'u32)
  render.setRenderTarget(hwCanvas)

  clip()
  cls()
  flipQuick()

  # clear the replay buffer
  createRecordBuffer()

proc resize() =
  var windowW, windowH: cint
  window.getSize(windowW, windowH)
  resize(windowW,windowH)

proc setTargetSize*(w,h: int) =
  targetScreenWidth = w
  targetScreenHeight = h
  resize()

proc fixedSize*(): bool =
  return fixedScreenSize

proc fixedSize*(enabled: bool) =
  fixedScreenSize = enabled
  resize()

proc integerScale*(): bool =
  return integerScreenScale

proc integerScale*(enabled: bool) =
  integerScreenScale = enabled
  resize()


proc setScreenSize*(w,h: int) =
  window.setSize(w,h)
  resize()

proc appHandleEvent(evt: Event) =
  if evt.kind == QuitEvent:
    keepRunning = false

  elif evt.kind == MouseWheel:
    mouseWheelState = evt.wheel.y
  elif evt.kind == MouseButtonDown:
    discard captureMouse(True32)
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
    discard captureMouse(False32)
    if evt.button.button == BUTTON_LEFT:
      mouseButtonState = mouseButtonState and not 1
    elif evt.button.button == BUTTON_RIGHT:
      mouseButtonState = mouseButtonState and not 2
    elif evt.button.button == BUTTON_MIDDLE:
      mouseButtonState = mouseButtonState and not 4

  elif evt.kind == ControllerDeviceAdded:
    for v in controllers:
      if v.sdlControllerId == evt.cdevice.which:
        echo "controller already exists"
        return
    try:
      var controller = newNicoController(evt.cdevice.which)
      controllers.add(controller)
      echo "added controller"
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
    elif evt.window.event == WindowEvent_FocusLost:
      focused = false
    elif evt.window.event == WindowEvent_FocusGained:
      focused = true

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

    elif sym == K_f and not down and (int16(evt.key.keysym.modstate) and int16(KMOD_CTRL)) != 0:
      if getFullscreen():
        setFullscreen(false)
      else:
        setFullscreen(true)
      return

    elif sym == K_return and not down and (int16(evt.key.keysym.modstate) and int16(KMOD_ALT)) != 0:
      if getFullscreen():
        setFullscreen(false)
      else:
        setFullscreen(true)
      return

    elif sym == K_m and down:
      when not defined(emscripten):
        if (int16(evt.key.keysym.modstate) and int16(KMOD_CTRL)) != 0:
          mute = not mute
          if mute:
            for i in 0..<mixerChannels:
              discard mixer.volume(i, 0)
            discard mixer.volumeMusic(0)
          else:
            for i in 0..<mixerChannels:
              discard mixer.volume(i, 255)
            discard mixer.volumeMusic(255)

    elif sym == K_F8 and down:
      # restart recording from here
      createRecordBuffer()

    elif sym == K_F9 and down:
      saveRecording()

    elif sym == K_F10 and down:
      saveScreenshot()

    elif sym == K_F11 and down:
      when system.hostOS == "windows":
        discard startProcess("start", writePath, [writePath], nil, {poUsePath})
      elif system.hostOS == "macosx":
        discard startProcess("open", writePath, [writePath], nil, {poUsePath})
      elif system.hostOS == "linux":
        discard startProcess("xdg-open", writePath, [writePath], nil, {poUsePath})

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
        controllers[0].setButtonState(pcB, down)
      of SDL_SCANCODE_LSHIFT, SDL_SCANCODE_RSHIFT:
        controllers[0].setButtonState(pcX, down)
      of SDL_SCANCODE_C:
        controllers[0].setButtonState(pcY, down)
      of SDL_SCANCODE_RETURN:
        controllers[0].setButtonState(pcStart, down)
      of SDL_SCANCODE_BACKSPACE, SDL_SCANCODE_DELETE, SDL_SCANCODE_ESCAPE:
        controllers[0].setButtonState(pcBack, down)
      of SDL_SCANCODE_F:
        controllers[0].setButtonState(pcL1, down)
      of SDL_SCANCODE_V:
        controllers[0].setButtonState(pcR1, down)
      of SDL_SCANCODE_G:
        controllers[0].setButtonState(pcL2, down)
      of SDL_SCANCODE_B:
        controllers[0].setButtonState(pcR2, down)
      else:
        discard


proc getPerformanceCounter*(): uint64 {.inline.} =
  return sdl2.getPerformanceCounter()

proc getPerformanceFrequency*(): uint64 {.inline.} =
  return sdl2.getPerformanceFrequency()

when defined(emscripten):
  proc emscripten_set_main_loop(fun: proc() {.cdecl.}, fps,
    simulate_infinite_loop: cint) {.header: "<emscripten.h>".}
  proc emscripten_cancel_main_loop() {.header: "<emscripten.h>".}

proc checkInput() =
  var evt: Event
  zeroMem(addr(evt), sizeof(Event))
  while pollEvent(evt):
    appHandleEvent(evt)

proc step() {.cdecl.} =
  checkInput()

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
    sdl2.delay(if focused: 0 else: 10)

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

proc getSprRect(spr: range[0..255], w,h: Pint = 1): Rect {.inline.} =
  result.x = spr%%16 * 8
  result.y = spr div 16 * 8
  result.w = w * 8
  result.h = h * 8

proc spr*(spr: range[0..255], x,y: Pint, w,h: Pint = 1, hflip, vflip: bool = false) =
  # draw a sprite
  var src = getSprRect(spr, w, h)
  var dst: Rect = sdl2.rect(x-cameraX,y-cameraY,src.w,src.h)
  if hflip or vflip:
    blit(spriteSheet[], swCanvas, src, dst, hflip, vflip)
  else:
    blitFast(spriteSheet[], swCanvas, src.x, src.y, x-cameraX, y-cameraY, src.w, src.h)

proc sprBlit*(spr: range[0..255], x,y: Pint, w,h: Pint = 1) =
  # draw a sprite
  let src = getSprRect(spr, w, h)
  let dst: Rect = sdl2.rect(x-cameraX,y-cameraY,src.w,src.h)
  blit(spriteSheet[], swCanvas, src, dst)

proc sprBlitFast*(spr: range[0..255], x,y: Pint, w,h: Pint = 1) =
  # draw a sprite
  let src = getSprRect(spr, w, h)
  blitFast(spriteSheet[], swCanvas, src.x, src.y, x-cameraX, y-cameraY, src.w, src.h)

proc sprBlitFastRaw*(spr: range[0..255], x,y: Pint, w,h: Pint = 1) =
  # draw a sprite
  let src = getSprRect(spr, w, h)
  blitFastRaw(spriteSheet[], swCanvas, src.x, src.y, x-cameraX, y-cameraY, src.w, src.h)

proc sprBlitStretch*(spr: range[0..255], x,y: Pint, w,h: Pint = 1) =
  # draw a sprite
  let src = getSprRect(spr, w, h)
  let dst: Rect = sdl2.rect(x-cameraX,y-cameraY,src.w,src.h)
  blitStretch(spriteSheet[], swCanvas, src, dst)

proc sprs*(spr: range[0..255], x,y: Pint, w,h: Pint = 1, dw,dh: Pint = 1, hflip, vflip: bool = false) =
  # draw an integer scaled sprite
  var src = getSprRect(spr, w, h)
  var dst: Rect = sdl2.rect(x-cameraX,y-cameraY,dw*8,dh*8)
  blit(spriteSheet[], swCanvas, src, dst, hflip, vflip)

proc drawTile(spr: range[0..255], x,y: Pint, tileSize = 8) =
  var src = getSprRect(spr)
  blitFast(spriteSheet[], swCanvas, src.x, src.y, x-cameraX, y-cameraY, tileSize, tileSize)

proc sspr*(sx,sy, sw,sh, dx,dy: Pint, dw,dh: Pint = -1, hflip, vflip: bool = false) =
  var src: Rect = sdl2.rect(sx,sy,sw,sh)
  let dw = if dw >= 0: dw else: sw
  let dh = if dh >= 0: dh else: sh
  var dst: Rect = sdl2.rect(dx-cameraX,dy-cameraY,dw,dh)
  blitStretch(spriteSheet[], swCanvas, src, dst, hflip, vflip)

proc mapDraw*(tx,ty, tw,th, dx,dy: Pint) =
  # draw map tiles to the screen
  var xi = dx
  var yi = dy
  var increment = 8
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
  createDir(writePath & "/maps")
  var fs = newFileStream(writePath & "/maps/" & filename, fmWrite)
  fs.write(mapWidth.int32)
  fs.write(mapHeight.int32)
  for y in 0..mapHeight-1:
    for x in 0..mapWidth-1:
      let t = mget(x,y)
      fs.write(t.uint8)
  fs.close()
  echo "saved map: " & $mapWidth & " x " & $mapHeight & " to: " & filename

proc loadMap*(filename: string) =
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

proc loadMapFromJson*(filename: string) =
  # read tiled output format
  var fp = newFileStream(basePath & "assets/maps/" & filename, fmRead)
  if fp == nil:
    raise newException(IOError, "Unable to open " & filename & " for reading")

  var data = parseJson(fp, filename)
  mapWidth = data["width"].getNum.int
  mapHeight = data["height"].getNum.int
  # only look at first layer
  mapData = newSeq[uint8](mapWidth*mapHeight)
  for i in 0..<(mapWidth*mapHeight):
    let t = data["layers"][0]["data"][i].getNum().uint8 - 1
    let x = i mod mapWidth
    let y = i div mapWidth
    mset(x,y,t)

proc rnd*[T: Ordinal](x: T): T =
  if x == 0:
    return 0
  return random(x.int).T

proc rnd*(x: float): float =
  return random(x)

proc rnd*[T](a: openarray[T]): T =
  return random(a)

proc getControllers*(): seq[NicoController] =
  return controllers

# Configuration

proc loadConfig*() =
  # TODO check for config file in user config directioy, use that first
  try:
    config = loadConfig(writePath & "/config.ini")
    echo "loaded config from " & writePath & "/config.ini"
  except IOError:
    try:
      config = loadConfig(basePath & "/config.ini")
      echo "loaded config from " & basePath & "/config.ini"
    except IOError:
      echo "no config file loaded"

proc saveConfig*() =
  # TODO write config file in user config directioy
  config.writeConfig(writePath & "/config.ini")
  echo "saved config to " & writePath & "/config.ini"

proc updateConfigValue*(section, key, value: string) =
  config.setSectionKey(section, key, value)

proc getConfigValue*(section, key: string): string =
  result = config.getSectionValue(section, key)

proc setFont*(fontId: FontId) =
  # sets the active font to be used by future print calls
  if fontId > fonts.len:
    return
  font = fonts[fontId].addr

proc getFont*(): FontId =
  for i, f in mpairs(fonts):
    if font == f.addr:
      return i
  return 0

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
      else:
        echo "Warning: playing invalid sfx: " & $sfxId

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


proc createWindow*(title: string, w,h: Pint, scale: Pint = 2, fullscreen: bool = false) =
  window = createWindow(title, SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, w * scale, h * scale, SDL_WINDOW_RESIZABLE or (if fullscreen: SDL_WINDOW_FULLSCREEN_DESKTOP else: 0))
  render = createRenderer(window, -1, Renderer_Accelerated or Renderer_PresentVsync or Renderer_TargetTexture)

  targetScreenWidth = w
  targetScreenHeight = h

  screenWidth = w
  screenHeight = h

  swCanvas = createRGBSurface(0, screenWidth, screenHeight, 8, 0, 0, 0, 0)
  swCanvas.format.palette.setPaletteColors(addr(colors[0]), 0, 16)
  swCanvas32 = createRGBSurface(0, screenWidth, screenHeight, 32, 0x000000ff'u32, 0x0000ff00'u32, 0x00ff0000'u32, 0xff000000'u32)

  var displayW, displayH: cint
  window.getSize(displayW, displayH)
  resize(displayW,displayH)

  spriteSheet = spriteSheets[0].addr
  spriteSheet[] = createRGBSurface(0, 128, 128, 8, 0, 0, 0, 0)
  spriteSheet.format.palette.setPaletteColors(addr(colors[0]), 0, 16)

  discard sdl2.setHint("SDL_HINT_RENDER_VSYNC", "1")
  discard sdl2.setHint("SDL_RENDER_SCALE_QUALITY", "0")
  sdl2.showCursor(false)
  render.setRenderTarget(hwCanvas)


proc initMixer*(channels: Pint) =
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
      discard mixer.allocateChannels(channels)
      mixerChannels = channels

proc init*(org: string, app: string) =
  ## Initializes Nico ready to be used
  discard sdl2.setHint("SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS", "1")

  if sdl2.init(INIT_EVERYTHING) != SDL_Return(0):
    echo getError()
    quit(1)

  addQuitProc(proc() {.noconv.} =
    echo "sdl2 quit"
    sdl2.quit()
  )

  loadPalettePico8()

  basePath = $sdl2.getBasePath()
  echo "basePath: ", basePath

  writePath = $sdl2.getPrefPath(org,app)
  echo "writePath: ", writePath

  setFont(0)
  try:
    loadFont(basePath & "/assets/font.png", " !\"#$%&'()*+,-./0123456789:;<=>?@abcdefghijklmnopqrstuvwxyz[\\]^_`ABCDEFGHIJKLMNOPQRSTUVWXYZ{:}~")
  except IOError:
    echo "no font loaded"

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

  loadConfig()

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

proc createRecordBuffer() =
  if window == nil:
    # this can happen later
    return
  recordFrame = newSeq[uint8](swCanvas.pitch*screenHeight)
  if recordSeconds <= 0:
    recordFrames = newRingBuffer[Frame](1)
  else:
    recordFrames = newRingBuffer[Frame](if fullSpeedGif: recordSeconds * frameRate.int else: recordSeconds * int(frameRate / 2))

proc setFullSpeedGif*(enabled: bool) =
  fullSpeedGif = enabled
  createRecordBuffer()

proc getFullSpeedGif*(): bool =
  return fullSpeedGif

proc setRecordSeconds*(seconds: int) =
  recordSeconds = seconds
  createRecordBuffer()

proc getRecordSeconds*(): int =
  return recordSeconds

proc run*(init: (proc()), update: (proc(dt:float)), draw: (proc())) =
  assert(update != nil)
  assert(draw != nil)

  initFunc = init
  updateFunc = update
  drawFunc = draw

  if initFunc != nil:
    initFunc()

  when defined(emscripten):
    emscripten_set_main_loop(step, cint(frameRate), cint(1))
  else:
    while keepRunning:
      step()

  when not defined(emscripten):
    mixer.closeAudio()
  sdl2.quit()

when defined(android):
  {.emit: """
  #include <SDL_main.h>

  extern int cmdCount;
  extern char** cmdLine;
  extern char** gEnv;

  N_CDECL(void, NimMain)(void);

  int main(int argc, char** args) {
      cmdLine = args;
      cmdCount = argc;
      gEnv = NULL;
      NimMain();
      return nim_program_result;
  }

  """.}
