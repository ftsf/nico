import nico/backends/common

when defined(js):
  import ospaths
  import nico/backends/js as backend
  export convertToConsoleLoggable

  proc joinPath(a,b: string): string =
    if a[a.high] == '/':
      return a & b
    return a & "/" & b

  proc joinPath(parts: varargs[string]): string =
    result = parts[0]
    for i in 1..parts.high:
      result = joinPath(result, parts[i])
else:
  import nico/backends/sdl2 as backend
  import os

# Audio
export joinPath
export loadSfx
export loadMusic
export sfx
export music
export getMusic
export synth
export synthUpdate
export synthShape
export SynthShape
export arp
export vibrato
export glide
export wavData
export pitchbend
export pitch

export addKeyListener
export removeKeyListener

export debug
import nico/controller
export NicoController
export NicoControllerKind
export NicoAxis
export NicoButton
export ColorId

export btn
export btnp
export btnpr
export axis
export axisp

import nico/ringbuffer
import math
export pow
import algorithm
import json
import sequtils

export math.sin
export math.sqrt
export math.PI
export math.TAU

import random
import times
import strscans
import strutils

## Public API

export timeStep

export Pint
export toPint
export Pfloat
export toPfloat

export setKeyMap

export basePath
export assetPath
export writePath

export loadConfig
export saveConfig
export updateConfigValue
export getConfigValue

when not defined(js):
  export saveMap

# Fonts
proc getFont*(): FontId
proc setFont*(fontId: FontId)

# Printing text
proc glyph*(c: char, x,y: Pint, scale: Pint = 1): Pint {.discardable, inline.}

proc cursor*(x,y: Pint) # set cursor position
proc print*(text: string) # print at cursor
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
proc loadPaletteCGA*()

proc pal*(a,b: ColorId) # maps one color to another
proc pald*(a,b: ColorId) # maps one color to another on display output
proc pal*() # resets palette
proc pald*() # resets display palette
proc palt*(a: ColorId, trans: bool) # sets transparency for color
proc palt*() # resets transparency

proc palCol*(c: ColorId, r,g,b: uint8) =
  ## sets the palette color to rgb value
  colors[c] = RGB(r.int,g.int,b.int)

proc palSet*(cols: array[maxPaletteSize, tuple[r,g,b: uint8]]) =
  ## sets the entire color palette
  for i in 0..<maxPaletteSize:
    palCol(i, cols[i].r, cols[i].g, cols[i].b)

proc palGet*(): array[maxPaletteSize, tuple[r,g,b: uint8]] =
  for i in 0..<maxPaletteSize:
    result[i] = colors[i]

# Clipping
proc clip*(x,y,w,h: Pint)
proc clip*()

# Camera
proc setCamera*(x,y: Pint = 0)
proc getCamera*(): (Pint,Pint)

# Input
proc btn*(b: NicoButton): bool
proc btnp*(b: NicoButton): bool
proc btnpr*(b: NicoButton, repeat = 48): bool
proc jaxis*(axis: NicoAxis): Pfloat

proc btn*(b: NicoButton, player: range[0..maxPlayers]): bool
proc btnp*(b: NicoButton, player: range[0..maxPlayers]): bool
proc btnpr*(b: NicoButton, player: range[0..maxPlayers], repeat = 48): bool
proc jaxis*(axis: NicoAxis, player: range[0..maxPlayers]): Pfloat
proc mouse*(): (int,int)
proc mousebtn*(b: range[0..2]): bool
proc mousebtnp*(b: range[0..2]): bool
proc mousebtnpr*(b: range[0..2], r: Pint): bool

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
proc ellipsefill*(cx,cy: Pint, rx,ry: Pint)

# sprites
proc spr*(spr: Pint, x,y: Pint, w,h: Pint = 1, hflip, vflip: bool = false)
proc sprs*(spr: Pint, x,y: Pint, w,h: Pint = 1, dw,dh: Pint = 1, hflip, vflip: bool = false)
proc sspr*(sx,sy, sw,sh, dx,dy: Pint, dw,dh: Pint = -1, hflip, vflip: bool = false)

# misc
proc copy*(sx,sy,dx,dy,w,h: Pint) # copy one area of the screen to another


# math
export sin
export cos
export abs
export `mod`

proc clamp01*[T](a: T): T =
  clamp(a, 0, 1)

proc mid*[T](a,b,c: T): T =
  var a = a
  var b = b
  if a > b:
    swap(a,b)
  return max(a, min(b, c))

## System functions
proc shutdown*()
#proc createWindow*(title: string, w,h: Pint, scale: Pint = 2, fullscreen: bool = false)
proc init*(org: string, app: string)

when not defined(js):
  export setEventFunc
  export getKeyNamesForBtn
  export getUnmappedJoysticks
  export getFullSpeedGif
  export setFullSpeedGif
  export getRecordSeconds
  export setRecordSeconds
  export getKeyMap
  export getPerformanceCounter
  export getPerformanceFrequency

# Tilemap functions
proc mset*(tx,ty: Pint, t: uint8)
proc mget*(tx,ty: Pint): uint8
proc mapDraw*(tx,ty, tw,th, dx,dy: Pint)
proc loadMap*(filename: string)
proc newMap*(w,h: Pint, tw,th: Pint)
proc pixelToMap*(px,py: Pint): (Pint,Pint) # returns the tile coordinates at pixel position
proc mapToPixel*(tx,ty: Pint): (Pint,Pint) # returns the pixel position of the tile coordinates

#proc saveMap*(filename: string)

export toPint
export screenWidth
export screenHeight

# Maths functions
proc flr*(x: Pfloat): Pfloat
proc ceil*(x: Pfloat): Pfloat =
  -flr(-x)
proc lerp*[T](a,b: T, t: Pfloat): T

proc rnd*[T: Natural](x: T): T
proc rnd*[T](a: openarray[T]): T
proc rnd*(x: Pfloat): Pfloat

## Internal functions

proc psetRaw*(x,y: int, c: ColorId) {.inline.}

proc fps*(fps: int) =
  frameRate = fps
  timeStep = 1.0 / fps.float32

proc fps*(): int =
  return frameRate

proc speed*(speed: int) =
  frameMult = speed

proc loadPaletteFromGPL*(filename: string) =
  var data = backend.readFile(joinPath(assetPath,filename))
  var i = 0
  for line in data.splitLines():
    if line.len == 0:
      continue
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
      #debug "matched ", i-1, ":", r,",",g,",",b
      colors[i-1] = RGB(r,g,b)
      if i > maxPaletteSize:
        break
      i += 1
    else:
      debug "not matched: ", line
  paletteSize = i-1
  pal()
  pald()
  palt()
  debug "loaded palette", filename, paletteSize

proc loadPaletteCGA*() =
  colors[0]  = RGB(0,0,0)
  colors[1]  = RGB(85,255,255)
  colors[2]  = RGB(255,85,255)
  colors[3]  = RGB(255,255,255)
  paletteSize = 4;
  pal()
  pald()
  palt()

proc loadPalettePico8*() =
  colors[0]  = RGB(0,0,0)
  colors[1]  = RGB(29,43,83)
  colors[2]  = RGB(126,37,83)
  colors[3]  = RGB(0,135,81)
  colors[4]  = RGB(171,82,54)
  colors[5]  = RGB(95,87,79)
  colors[6]  = RGB(194,195,199)
  colors[7]  = RGB(255,241,232)
  colors[8]  = RGB(255,0,77)
  colors[9]  = RGB(255,163,0)
  colors[10] = RGB(255,240,36)
  colors[11] = RGB(0,231,86)
  colors[12] = RGB(41,173,255)
  colors[13] = RGB(131,118,156)
  colors[14] = RGB(255,119,168)
  colors[15] = RGB(255,204,170)
  paletteSize = 16;
  pal()
  pald()
  palt()

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
  clipMaxX = min(x+w, screenWidth-1)
  clipMinY = max(y, 0)
  clipMaxY = min(y+h, screenHeight-1)
  clippingRect.x = max(x, 0)
  clippingRect.y = max(y, 0)
  clippingRect.w = min(w, screenWidth - x)
  clippingRect.h = min(h, screenHeight - y)

proc ditherPattern*(pattern: uint16 = 0b1111_1111_1111_1111) =
  # 0123
  # 4567
  # 89ab
  # cdef
  gDitherPattern = pattern

proc ditherPatternScanlines*() =
  gDitherPattern = 0b1111_0000_1111_0000

proc ditherPatternScanlines2*() =
  gDitherPattern = 0b0000_1111_0000_1111

proc ditherPatternCheckerboard*() =
  gDitherPattern = 0b1010_0101_1010_0101

proc ditherPatternCheckerboard2*() =
  gDitherPattern = 0b0101_1010_0101_1010

proc ditherPass(x,y: int): bool =
  let x4 = (x mod 4).uint16
  let y4 = (y mod 4).uint16
  let bit = (y4 * 4 + x4).uint16
  return (gDitherPattern and (1.uint16 shl bit)) != 0

proc btn*(b: NicoButton): bool =
  for c in controllers:
    if c.btn(b):
      return true
  return false

proc btn*(b: NicoButton, player: range[0..maxPlayers]): bool =
  if player > controllers.high:
    return false
  return controllers[player].btn(b)

proc btnp*(b: NicoButton): bool =
  for c in controllers:
    if c.btnp(b):
      return true
  return false

proc btnp*(b: NicoButton, player: range[0..maxPlayers]): bool =
  if player > controllers.high:
    return false
  return controllers[player].btnp(b)

proc btnpr*(b: NicoButton, repeat = 48): bool =
  for c in controllers:
    if c.btnpr(b, repeat):
      return true
  return false

proc btnpr*(b: NicoButton, player: range[0..maxPlayers], repeat = 48): bool =
  if player > controllers.high:
    return false
  return controllers[player].btnpr(b, repeat)

proc jaxis*(axis: NicoAxis): Pfloat =
  for c in controllers:
    let v = c.axis(axis)
    if abs(v) > c.deadzone:
      return v
  return 0.0

proc jaxis*(axis: NicoAxis, player: range[0..maxPlayers]): Pfloat =
  if player > controllers.high:
    return 0.0
  return controllers[player].axis(axis)

proc pal*(a,b: ColorId) =
  paletteMapDraw[a] = b

proc pal*() =
  for i in 0..<paletteSize.int:
    paletteMapDraw[i] = i

proc pald*(a,b: ColorId) =
  paletteMapDisplay[a] = b

proc pald*() =
  for i in 0..<paletteSize.int:
    paletteMapDisplay[i] = i

proc palt*(a: ColorId, trans: bool) =
  paletteTransparent[a] = trans

proc palt*() =
  for i in 0..<paletteSize.int:
    paletteTransparent[i] = if i == 0: true else: false

proc cls*() =
  for y in clipMinY..clipMaxY:
    for x in clipMinX..clipMaxX:
      psetRaw(x,y,0)

proc setCamera*(x,y: Pint = 0) =
  cameraX = x
  cameraY = y

proc getCamera*(): (Pint,Pint) =
  return (cameraX, cameraY)


proc setColor*(colId: ColorId) =
  currentColor = colId

proc getColor*(): ColorId =
  return currentColor

{.push checks: off, optimization: speed.}
proc pset*(x,y: Pint) =
  let x = x-cameraX
  let y = y-cameraY
  if x < clipMinX or y < clipMinY or x > clipMaxX or y > clipMaxY:
    return
  swCanvas.data[y*swCanvas.w+x] = paletteMapDraw[currentColor]

proc pset*(x,y: Pint, c: int) =
  let x = x-cameraX
  let y = y-cameraY
  if x < clipMinX or y < clipMinY or x > clipMaxX or y > clipMaxY:
    return
  swCanvas.data[y*swCanvas.w+x] = paletteMapDraw[c]

proc psetRaw*(x,y: int, c: ColorId) =
  swCanvas.data[y*swCanvas.w+x] = c
{.pop.}

proc sset*(x,y: Pint, c: int = -1) =
  let c = if c == -1: currentColor else: c
  if x < 0 or y < 0 or x > spriteSheet.w-1 or y > spriteSheet.h-1:
    raise newException(RangeError, "sset ($1,$2) out of bounds".format(x,y))
  spriteSheet[].data[y*spriteSheet[].w+x] = paletteMapDraw[c]

proc sget*(x,y: Pint): ColorId =
  if x > spriteSheet.w-1 or x < 0 or y > spriteSheet.h-1 or y < 0:
    return 0
  let color = spriteSheet[].data[y*spriteSheet.w+x]
  return color

proc pget*(x,y: Pint): ColorId =
  if x > swCanvas.w-1 or x < 0 or y > swCanvas.h-1 or y < 0:
    return 0
  return swCanvas.data[y*swCanvas.w+x]

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
  var err: float32 = (if dx>dy: dx else: -dy).float32/2.0
  var e2: float32 = 0

  while true:
    pset(x,y)
    if x == x1 and y == y1:
      break
    e2 = err
    if e2 > -dx:
      err -= dy.float32
      x += sx
    if e2 < dy:
      err += dx.float32
      y += sy

proc lineDashed*(x0,y0,x1,y1: Pint, pattern: uint8 = 0b10101010) =
  var x = x0
  var y = y0
  var dx: int = abs(x1-x0)
  var sx: int = if x0 < x1: 1 else: -1
  var dy: int = abs(y1-y0)
  var sy: int = if y0 < y1: 1 else: -1
  var err: float32 = (if dx>dy: dx else: -dy).float32/2.0
  var e2: float32 = 0

  var i = 0

  while true:
    if pattern shl ((i mod 8) + 1).uint8 != 0:
      pset(x,y)
    i += 1
    if x == x1 and y == y1:
      break
    e2 = err
    if e2 > -dx:
      err -= dy.float32
      x += sx
    if e2 < dy:
      err += dx.float32
      y += sy


iterator lineIterator*(x0,y0,x1,y1: Pint): (Pint,Pint) =
  var x = x0
  var y = y0
  var dx: Pint = abs(x1-x0)
  var sx: Pint = if x0 < x1: 1 else: -1
  var dy: Pint = abs(y1-y0)
  var sy: Pint = if y0 < y1: 1 else: -1
  var err: float32 = (if dx>dy: dx else: -dy).float32/2.0
  var e2: float32 = 0

  while true:
    yield (x,y)
    if x == x1 and y == y1:
      break
    e2 = err
    if e2 > -dx:
      err -= dy.float32
      x += sx
    if e2 < dy:
      err += dx.float32
      y += sy

proc line*(x0,y0,x1,y1: Pint) =
  if x0 == x1 and y0 == y1:
    pset(x0,y0)
  else:
    innerLine(x0,y0,x1,y1)

proc hlineFast(x0,y,x1: Pint, c: ColorId) =
  for x in x0..x1:
    psetRaw(x,y,c)

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
  let w = x2-x1
  let h = y2-y1
  let x = x1
  let y = y1
  # top
  hline(x, y, x+w)
  # bottom
  hline(x, y+h, x+w)
  # right
  vline(x+w, y+1, y+h-1)
  # left
  vline(x, y+1, y+h-1)

proc flr*(x: Pfloat): Pfloat =
  return x.floor()

proc lerp[T](a, b: T, t: Pfloat): T =
  return a + (b - a) * t

{.push checks: off, optimization: speed.}
type Bresenham = object
  x,y: int
  x1,y1: int
  dx,sx: int
  dy,sy: int
  err: float32
  e2: float32
  finished: bool

proc initBresenham(x0,y0,x1,y1: int): Bresenham =
  result.x = x0
  result.y = y0
  result.x1 = x1
  result.y1 = y1
  result.dx = abs(x1-x0)
  result.sx = if x0 < x1: 1 else: -1
  result.dy = abs(y1-y0)
  result.sy = if y0 < y1: 1 else: -1
  result.err = (if result.dx > result.dy: result.dx else: -result.dy).float32 / 2.0
  result.e2 = 0.0
  result.finished = false

proc step(self: var Bresenham): (int,int) =
  if self.finished:
    return (self.x,self.y)
  while true:
    if self.x == self.x1 and self.y == self.y1:
      self.finished = true
      return (self.x,self.y)
    self.e2 = self.err
    if self.e2 > -self.dx:
      self.err -= self.dy.float32
      self.x += self.sx
    if self.e2 < self.dy:
      self.err += self.dx.float32
      self.y += self.sy
      return (self.x,self.y)

proc trifill*(x1,y1,x2,y2,x3,y3: Pint) =
  var x1 = x1 - cameraX
  var x2 = x2 - cameraX
  var x3 = x3 - cameraX
  var y1 = y1 - cameraY
  var y2 = y2 - cameraY
  var y3 = y3 - cameraY

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

  let minx = min(x1,min(x2,x3))
  let maxx = max(x1,max(x2,x3))

  if maxx < clipMinX or minx > clipMaxX or y3 < clipMinY or y1 > clipMaxY:
    # if the tri is on screen skip it
    return

  var sx = x1
  var ex = x1
  var sy = y1
  var ey = y1

  # create the three lines of the triangle AC, AB, BC
  # A is the highest point
  # C is the lowest point
  var ab = initBresenham(x1,y1, x2,y2)
  var ac = initBresenham(x1,y1, x3,y3)
  var bc = initBresenham(x2,y2, x3,y3)

  let c = paletteMapDraw[currentColor]

  if sx >= clipMinX and sx <= clipMaxX and sy >= clipMinY and sy <= clipMaxY:
    psetRaw(sx,sy, c)

  if y1 != y2:
    # draw flat bottom tri
    while true:
      (sx,sy) = ab.step()
      (ex,ey) = ac.step()
      let ax = min(sx,ex)
      let bx = max(sx,ex)
      if not(ax > clipMaxX or bx < clipMinX or sy < clipMinY or sy > clipMaxY):
        hlineFast(clamp(ax,clipMinX,clipMaxX),sy,clamp(bx,clipMinX,clipMaxX), c)
      if sy == y2 or sy >= clipMaxY:
        break

  if sy >= clipMinY and sy <= clipMaxY:
    hlineFast(clamp(sx,clipMinX,clipMaxX),sy,clamp(x2,clipMinX,clipMaxX), c)

  if y2 != y3:
    # draw flat top tri
    while true:
      (sx,sy) = ac.step()
      (ex,ey) = bc.step()
      let ax = min(sx,ex)
      let bx = max(sx,ex)
      if not (ax > clipMaxX or bx < clipMinX or sy < clipMinY or sy > clipMaxY):
        hlineFast(clamp(ax,clipMinX,clipMaxX),sy,clamp(bx,clipMinX,clipMaxX), c)
      if sy == y3 or sy >= clipMaxY:
        break
{.pop.}

proc plot4pointsfill(cx,cy,x,y: Pint) =
  hline(cx - x, cy + y, cx + x)
  if x != 0 and y != 0:
    hline(cx - x, cy - y, cx + x)

template doWhile(a, b: untyped): untyped =
  b
  while a:
    b

proc ellipsefill*(cx,cy,rx,ry: Pint) =
  var x,y: int
  var dx,dy: int
  var err: int
  var stoppingX, stoppingY: int

  let twoASquare = 2 * rx * rx
  let twoBSquare = 2 * ry * ry

  x = rx
  y = 0
  dx = ry*ry * (1-2*rx)
  dy = rx*rx
  err = 0
  stoppingX = twoBSquare * rx
  stoppingY = 0

  while stoppingX >= stoppingY:
    plot4pointsfill(cx,cy,x,y)
    y+=1
    stoppingY += twoASquare
    err += dy
    dy += twoASquare
    if 2 * err + dx > 0:
      x -= 1
      stoppingX -= twoBSquare
      err += dx
      dx += twoBSquare

  x = 0
  y = ry
  dx = ry*ry
  dy = rx*rx*(1-2*ry)
  err = 0
  stoppingX = 0
  stoppingY = twoASquare*ry
  while stoppingX <= stoppingY:
    plot4pointsfill(cx,cy,x,y)
    x+=1
    stoppingX += twoBSquare
    err += dx
    dx += twoBSquare
    if 2 * err + dy > 0:
      y -= 1
      stoppingY -= twoASquare
      err += dy
      dy += twoASquare

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

proc arc*(cx,cy,r: Pint, startAngle, endAngle: Pfloat) =
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


proc fontBlit(font: Font, srcRect, dstRect: Rect, color: ColorId) =
  var dx = dstRect.x.float32
  var dy = dstRect.y.float32
  var sx = srcRect.x.float32
  var sy = srcRect.y.float32
  let dw = dstRect.w.float32
  let dh = dstRect.h.float32
  let sw = srcRect.w.float32
  let sh = srcRect.h.float32
  for y in 0..<dstRect.h:
    dx = dstRect.x.float32
    sx = srcRect.x.float32
    for x in 0..<dstRect.w:
      if sx < 0 or sy < 0 or sx > font.w - 1 or sy > font.h - 1:
        continue
      if dx < clipMinX or dy < clipMinY or dx > clipMaxX or dy > clipMaxY:
        continue
      if font.data[sy * font.w + sx] == 1 and ditherPass(dx.int,dy.int):
        swCanvas.data[dy * swCanvas.w + dx] = currentColor
      sx += 1.0 * (sw/dw)
      dx += 1.0
    sy += 1.0 * (sh/dh)
    dy += 1.0

proc overlap(a,b: Rect): bool =
  return not ( a.x > b.x + b.w or a.y > b.y + b.h or a.x + a.w < b.x or a.y + a.h < b.y )

proc blitFastRaw(src: Surface, sx,sy, dx,dy, w,h: Pint) =
  # used for tile drawing, no stretch or flipping or palette mapping
  var sxi = sx
  var syi = sy
  var dxi = dx
  var dyi = dy

  while dyi < dy + h:
    if syi < 0 or syi > src.h-1 or dyi < clipMinY or dyi > min(swCanvas.h-1,clipMaxY):
      syi += 1
      dyi += 1
      sxi = sx
      dxi = dx
      continue
    while dxi < dx + w:
      if sxi < 0 or sxi > src.w-1 or dxi < clipMinX or dxi > min(swCanvas.w-1,clipMaxX):
        # ignore if it goes outside the source size
        dxi += 1
        sxi += 1
        continue
      if ditherPass(dxi,dyi):
        let srcCol = src.data[syi * src.w + sxi]
        swCanvas.data[dyi * swCanvas.w + dxi] = srcCol
      sxi += 1
      dxi += 1
    syi += 1
    dyi += 1
    sxi = sx
    dxi = dx

proc blitFastRaw*(sx,sy, dx,dy, w,h: Pint) =
  # used for tile drawing, no stretch or flipping or palette mapping
  var sxi = sx
  var syi = sy
  var dxi = dx
  var dyi = dy

  let srcw = spriteSheet[].w
  let srch = spriteSheet[].w

  while dyi < dy + h:
    if syi < 0 or syi > srch-1 or dyi < clipMinY or dyi > min(swCanvas.h-1,clipMaxY):
      syi += 1
      dyi += 1
      sxi = sx
      dxi = dx
      continue
    while dxi < dx + w:
      if sxi < 0 or sxi > srcw-1 or dxi < clipMinX or dxi > min(swCanvas.w-1,clipMaxX):
        # ignore if it goes outside the source size
        dxi += 1
        sxi += 1
        continue
      if ditherPass(dxi,dyi):
        let srcCol = spriteSheet[].data[syi * srcw + sxi]
        swCanvas.data[dyi * swCanvas.w + dxi] = srcCol
      sxi += 1
      dxi += 1
    syi += 1
    dyi += 1
    sxi = sx
    dxi = dx

proc blitFast(src: Surface, sx,sy, dx,dy, w,h: Pint) =
  # used for tile drawing, no stretch or flipping
  var sxi = sx
  var syi = sy
  var dxi = dx
  var dyi = dy

  while dyi < dy + h:
    if syi < 0 or syi > src.h-1 or dyi < clipMinY or dyi > clipMaxY:
      syi += 1
      dyi += 1
      sxi = sx
      dxi = dx
      continue
    while dxi < dx + w:
      if sxi < 0 or sxi > src.w-1 or dxi < clipMinX or dxi > clipMaxX:
        # ignore if it goes outside the source size
        dxi += 1
        sxi += 1
        continue
      if ditherPass(dxi,dyi):
        let srcCol = src.data[syi * src.w + sxi]
        if not paletteTransparent[srcCol]:
          swCanvas.data[dyi * swCanvas.w + dxi] = paletteMapDraw[srcCol]
      sxi += 1
      dxi += 1
    syi += 1
    dyi += 1
    sxi = sx
    dxi = dx

proc blitFastFlip(src: Surface, sx,sy, dx,dy, w,h: Pint, hflip, vflip: bool) =
  # used for tile drawing, no stretch or flipping
  let startsx = sx + (if hflip: w - 1 else: 0)
  var sxi = startsx
  var syi = sy + (if vflip: h - 1 else: 0)
  var dxi = dx
  var dyi = dy

  let xi = if hflip: -1 else: 1
  let yi = if vflip: -1 else: 1

  while dyi < dy + h:
    if syi < 0 or syi > src.h-1 or dyi < clipMinY or dyi > clipMaxY:
      syi += yi
      dyi += 1
      sxi = startsx
      dxi = dx
      continue
    while dxi < dx + w:
      if sxi < 0 or sxi > src.w-1 or dxi < clipMinX or dxi > clipMaxX:
        # ignore if it goes outside the source size
        dxi += 1
        sxi += xi
        continue
      if ditherPass(dxi,dyi):
        let srcCol = src.data[syi * src.w + sxi]
        if not paletteTransparent[srcCol]:
          swCanvas.data[dyi * swCanvas.w + dxi] = paletteMapDraw[srcCol]
      sxi += xi
      dxi += 1
    syi += yi
    dyi += 1
    sxi = startsx
    dxi = dx

proc blit(src: Surface, srcRect, dstRect: Rect, hflip, vflip: bool = false) =
  # if dstrect doesn't overlap clipping rect, skip it
  if not overlap(dstrect, clippingRect):
    return

  var dx = dstRect.x.float32
  var dy = dstRect.y.float32
  var dw = dstRect.w.float32
  var dh = dstRect.h.float32

  var sx = srcRect.x.float32
  var sy = srcRect.y.float32
  var sw = srcRect.w.float32
  var sh = srcRect.h.float32

  if vflip:
    dy = dy + (dstRect.h - 1).float32
    sy = sy + (srcRect.h - 1).float32

  for y in 0..dstRect.h-1:
    if hflip:
      sx = (srcRect.x + srcRect.w-1).float32
      dx = (dstRect.x + dstRect.w-1).float32
    else:
      sx = srcRect.x.float32
      dx = dstRect.x.float32
    for x in 0..dstRect.w-1:
      if sx < 0 or sy < 0 or sx > src.w-1 or sy > src.h-1:
        continue
      if not (dx < clipMinX or dy < clipMinY or dx > clipMaxX or dy > clipMaxY):
        if ditherPass(dx.int,dy.int):
          let srcCol = src.data[sy.int * src.w + sx.int]
          if not paletteTransparent[srcCol]:
            swCanvas.data[dy.int * swCanvas.w + dx.int] = paletteMapDraw[srcCol]
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

proc blitStretch(src: Surface, srcRect, dstRect: Rect, hflip, vflip: bool = false) =
  # if dstrect doesn't overlap clipping rect, skip it
  if not overlap(dstrect, clippingRect):
    return

  var dx = dstRect.x.float32
  var dy = dstRect.y.float32
  var dw = dstRect.w.float32
  var dh = dstRect.h.float32

  var sx = srcRect.x.float32
  var sy = srcRect.y.float32
  var sw = srcRect.w.float32
  var sh = srcRect.h.float32

  if vflip:
    dy = dy + (dstRect.h - 1).float32
    sy = sy + (srcRect.h - 1).float32

  for y in 0..dstRect.h-1:
    if hflip:
      sx = (srcRect.x + srcRect.w-1).float32
      dx = (dstRect.x + dstRect.w-1).float32
    else:
      sx = srcRect.x.float32
      dx = dstRect.x.float32
    for x in 0..dstRect.w-1:
      if sx < 0 or sy < 0 or sx > src.w-1 or sy > src.h-1:
        continue
      if not (dx < clipMinX or dy < clipMinY or dx > clipMaxX or dy > clipMaxY or sx < 0 or sy < 0 or sx >= src.w or sy >= src.h):
        let srcCol = src.data[sy.int * src.w + sx.int]
        if ditherPass(dx.int,dy.int) and not paletteTransparent[srcCol]:
          swCanvas.data[dy * swCanvas.w + dx] = paletteMapDraw[srcCol]
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
  if tx < 0 or tx > currentTilemap.w - 1 or ty < 0 or ty > currentTilemap.h - 1:
    return
  currentTilemap.data[ty * currentTilemap.w + tx] = t

proc mget*(tx,ty: Pint): uint8 =
  if tx < 0 or tx > currentTilemap.w - 1 or ty < 0 or ty > currentTilemap.h - 1:
    return 0.uint8
  return currentTilemap.data[ty * currentTilemap.w + tx]

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

proc masterVol*(newVol: int) =
  masterVolume = clamp(newVol.float / 255.0, 0, 1)

proc masterVol*(): int =
  return (masterVolume * 255.0).int

proc sfxVol*(newVol: int) =
  sfxVolume = clamp(newVol.float / 255.0, 0, 1)

proc sfxVol*(): int =
  return (sfxVolume * 255.0).int

proc musicVol*(newVol: int) =
  musicVolume = clamp(newVol.float / 255.0, 0, 1)

proc musicVol*(): int =
  return (musicVolume * 255.0).int

proc createFontFromSurface(surface: Surface, chars: string): Font =
  var font = new(Font)

  font.w = surface.w
  font.h = surface.h
  font.data = newSeq[uint8](font.w*font.h)

  let borderColor = 2.uint8
  let solidColor = 1.uint8
  let transparentColor = 0.uint8

  echo surface.channels

  if surface.channels == 4:
    let borderColorRGBA = (surface.data[0],surface.data[1],surface.data[2],surface.data[3])
    let transparentColorRGBA = (surface.data[4],surface.data[5],surface.data[6],surface.data[7])

    for i in 0..<font.w*font.h:
      var col = (
        surface.data[i*surface.channels+0],
        surface.data[i*surface.channels+1],
        surface.data[i*surface.channels+2],
        surface.data[i*surface.channels+3]
      )
      if col == borderColorRGBA:
        font.data[i] = borderColor
      elif col == transparentColorRGBA:
        font.data[i] = transparentColor
      else:
        font.data[i] = solidColor

  elif surface.channels == 1:
    for i in 0..<font.w*font.h:
      font.data[i] = surface.data[i]

  var highestChar: char
  for c in chars:
    if c > highestChar:
      highestChar = c
  font.rects = newSeq[Rect](highestChar.int+1)

  var newChar = false
  var currentRect: Rect = (0,0,0,0)
  var i = 0
  # scan across the top of the font image
  for x in 0..<font.w:
    let color = font.data[x]
    if color == borderColor:
      currentRect.w = x - currentRect.x
      if currentRect.w != 0:
        # go down until we find border or h
        currentRect.h = font.h-1
        for y in 0..font.h:
          let color = font.data[y*font.w+x]
          if color == borderColor:
            currentRect.h = y-2
        let charId = chars[i].int
        font.rects[charId] = currentRect
        i += 1
      newChar = true
      currentRect.x = x + 1

  echo "loaded ", font.rects.len, " characters"

  return font

proc loadFont*(index: int, filename: string, chars: string) =
  backend.loadSurfaceRGBA(joinPath(assetPath,filename)) do(surface: Surface):
    fonts[index] = createFontFromSurface(surface, chars)

proc glyph*(c: char, x,y: Pint, scale: Pint = 1): Pint =
  let font = fonts[currentFontId]
  if font == nil:
    return 0
  if c.int > font.rects.high:
    return
  let src: Rect = font.rects[c.int]
  let dst: Rect = (x.int, y.int, src.w * scale, src.h * scale)
  try:
    fontBlit(font, src, dst, currentColor)
  except IndexError:
    debug "index error glyph: ", c, " @ ", x, ",", y
    raise
  return src.w * scale + scale

proc print*(text: string, x,y: Pint, scale: Pint = 1) =
  var x = x - cameraX
  var y = y - cameraY
  let ix = x
  for c in text:
    if c == '\n':
      y += fonts[currentFontId].h
      x = ix
      continue
    x += glyph(c, x, y, scale)

proc print*(text: string) =
  var x = cursorX - cameraX
  let y = cursorY - cameraY
  for c in text:
    x += glyph(c, x, y, 1)
  cursorY += 6

proc glyphWidth*(c: char, scale: Pint = 1): Pint =
  let font = fonts[currentFontId]
  if font == nil:
    return 0
  if c.int > font.rects.high:
    return 0
  result = font.rects[c.int].w*scale + scale

proc textWidth*(text: string, scale: Pint = 1): Pint =
  let font = fonts[currentFontId]
  if font == nil:
    return 0
  for c in text:
    if c.int < font.rects.len:
      result += font.rects[c.int].w*scale + scale

proc printr*(text: string, x,y: Pint, scale: Pint = 1) =
  let width = textWidth(text, scale)
  print(text, x-width, y, scale)

proc printc*(text: string, x,y: Pint, scale: Pint = 1) =
  let width = textWidth(text, scale)
  print(text, x-(width div 2), y, scale)

proc copy*(sx,sy,dx,dy,w,h: Pint) =
  blitFastRaw(swCanvas, sx, sy, dx, dy, w, h)

proc copyPixelsToMem*(sx,sy: Pint, buffer: var seq[uint8]) =
  let offset = sy*swCanvas.w+sx
  for i in 0..<buffer.len:
    if offset+i < 0:
      continue
    if offset+i > swCanvas.data.high:
      break
    buffer[i] = swCanvas.data[offset+i]

proc copyMemToScreen*(dx,dy: Pint, buffer: var seq[uint8]) =
  let offset = dy*swCanvas.w+dx
  for i in 0..<buffer.len:
    if offset+i < 0:
      continue
    if offset+i > swCanvas.data.high:
      break
    swCanvas.data[offset+i] = buffer[i]

proc hasMouse*(): bool =
  return mouseDetected

proc mouse*(): (int,int) =
  return (mouseX,mouseY)

proc mousebtn*(b: range[0..2]): bool =
  return mouseButtons[b] > 0

proc mousebtnp*(b: range[0..2]): bool =
  return mouseButtons[b] == 1

proc mousebtnpr*(b: range[0..2], r: Pint): bool =
  return mouseButtons[b] mod r == 1

proc mousewheel*(): int =
  # return the mousewheel status, 0 normal, -1 or 1
  return mouseWheelState

proc clearKeysForBtn*(btn: NicoButton) =
  keymap[btn] = @[]

proc addKeyForBtn*(btn: NicoButton, scancode: int) =
  if not (scancode in keymap[btn]):
    keymap[btn].add(scancode)

proc shutdown*() =
  keepRunning = false

proc resize(w,h: int) =
  backend.resize(w,h)
  clip()
  if swCanvas.data.len != 0:
    cls()
    present()

proc resize() =
  backend.resize()
  clip()
  if swCanvas.data.len != 0:
    cls()
    present()

proc setResizeFunc*(newResizeFunc: ResizeFunc) =
  resizeFunc = newResizeFunc

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

proc setSpritesheet*(bank: range[0..15] = 0) =
  spriteSheet = spriteSheets[bank].addr

proc loadSpriteSheet*(index: range[0..15], filename: string, w,h: Pint = 8) =
  backend.loadSurfaceIndexed(joinPath(assetPath,filename)) do(surface: Surface):
    spriteSheets[index] = surface
    spriteSheets[index].tw = w
    spriteSheets[index].th = h

proc getSprRect(spr: Pint, w,h: Pint = 1): Rect {.inline.} =
  let tilesX = spriteSheet.w div spriteSheet.tw
  result.x = spr mod tilesX * spriteSheet.tw
  result.y = spr div tilesX * spriteSheet.th
  result.w = w * spriteSheet.tw
  result.h = h * spriteSheet.th

proc spr*(spr: Pint, x,y: Pint, w,h: Pint = 1, hflip, vflip: bool = false) =
  if spriteSheet.tw == 0 or spriteSheet.th == 0:
    return
  # draw a sprite
  var src = getSprRect(spr, w, h)
  if hflip or vflip:
    blitFastFlip(spriteSheet[], src.x, src.y, x-cameraX, y-cameraY, src.w, src.h, hflip, vflip)
  else:
    blitFast(spriteSheet[], src.x, src.y, x-cameraX, y-cameraY, src.w, src.h)

proc sprBlit*(spr: Pint, x,y: Pint, w,h: Pint = 1) =
  # draw a sprite
  let src = getSprRect(spr, w, h)
  let dst: Rect = ((x-cameraX).int,(y-cameraY).int,src.w,src.h)
  blit(spriteSheet[], src, dst)

proc sprBlitFast*(spr: Pint, x,y: Pint, w,h: Pint = 1) =
  # draw a sprite
  let src = getSprRect(spr, w, h)
  blitFast(spriteSheet[], src.x, src.y, x-cameraX, y-cameraY, src.w, src.h)

proc sprBlitFastRaw*(spr: Pint, x,y: Pint, w,h: Pint = 1) =
  # draw a sprite
  let src = getSprRect(spr, w, h)
  blitFastRaw(spriteSheet[], src.x, src.y, x-cameraX, y-cameraY, src.w, src.h)

proc sprBlitStretch*(spr: Pint, x,y: Pint, w,h: Pint = 1) =
  # draw a sprite
  let src = getSprRect(spr, w, h)
  let dst: Rect = ((x-cameraX).int,(y-cameraY).int,src.w,src.h)
  blitStretch(spriteSheet[], src, dst)

proc sprs*(spr: Pint, x,y: Pint, w,h: Pint = 1, dw,dh: Pint = 1, hflip, vflip: bool = false) =
  # draw an integer scaled sprite
  var src = getSprRect(spr, w, h)
  var dst: Rect = ((x-cameraX).int,(y-cameraY).int,(dw*8).int,(dh*8).int)
  blitStretch(spriteSheet[], src, dst, hflip, vflip)

proc sprss*(spr: Pint, x,y: Pint, w,h: Pint = 1, dw,dh: Pint, hflip, vflip: bool = false) =
  # draw a scaled sprite
  var src = getSprRect(spr, w, h)
  var dst: Rect = ((x-cameraX).int,(y-cameraY).int,dw.int,dh.int)
  blit(spriteSheet[], src, dst, hflip, vflip)

proc drawTile(spr: uint8, x,y: Pint) =
  var src = getSprRect(spr.Pint)
  let x = x-cameraX
  let y = y-cameraY
  if overlap(clippingRect,(x.int,y.int, spriteSheet.tw, spriteSheet.th)):
    blitFast(spriteSheet[], src.x, src.y, x, y, spriteSheet.tw, spriteSheet.th)

proc sspr*(sx,sy, sw,sh, dx,dy: Pint, dw,dh: Pint = -1, hflip, vflip: bool = false) =
  var src: Rect = (sx.int,sy.int,sw.int,sh.int)
  let dw = if dw >= 0: dw else: sw
  let dh = if dh >= 0: dh else: sh
  var dst: Rect = ((dx-cameraX).int,(dy-cameraY).int,dw.int,dh.int)
  blitStretch(spriteSheet[], src, dst, hflip, vflip)

proc roundTo*(a: int, n: int): int =
  if a < 0:
    ((a - (n - 1)) div n * n)
  else:
    a div n * n

proc remainder*(a: int, n: int): int =
  if a < 0:
    let r = a mod n
    if r != 0:
      r + n
    else:
      r
  else:
    a mod n

proc mapDraw*(tx,ty, tw,th, dx,dy: Pint) =
  if currentTilemap.data.len == 0:
    debug "mapDraw with no tilemap"
    return
  # draw map tiles to the screen
  let yincrement = if currentTilemap.hex: currentTilemap.hexOffset else: currentTilemap.th
  let xincrement = currentTilemap.tw

  let drawWidth = clipMaxX - clipMinX
  let drawHeight = clipMaxY - clipMinY

  let hex = currentTilemap.hex
  let startCol = max(max((cameraX + clipMinX) div xincrement - (if hex: 1 else: 0) + tx, 0), tx)
  let startRow = max(max((cameraY + clipMinY) div yincrement - (if hex: 2 else: 0) + ty, 0), ty)
  let endCol = min(min(startCol + ((drawWidth + xincrement - 1) div xincrement) + (if hex: 2 else: 0), currentTilemap.w - 1), tx + tw - 1)
  let endRow = min(min(startRow + ((drawHeight + yincrement - 1) div yincrement) + (if hex: 2 else: 0), currentTilemap.h - 1), ty + th - 1)
  let offsetX = -(cameraX) + startCol * xincrement + dx
  let offsetY = -(cameraY) + startRow * yincrement + dy

  for y in startRow..endRow:
    for x in startCol..endCol:
      let t = currentTilemap.data[y * currentTilemap.w + x]
      let px = (x - startCol) * xincrement - (if currentTilemap.hex and y mod 2 == 0: xincrement div 2 else: 0) + offsetX
      let py = (y - startRow) * yincrement + offsetY
      if t != 0:
        drawTile(t, px + cameraX, py + cameraY)

proc mapWidth*(): Pint =
  return currentTilemap.w

proc mapHeight*(): Pint =
  return currentTilemap.h

proc `%%/`[T](x,m: T): T =
  return (x mod m + m) mod m

proc loadMapFromJson(filename: string) =
  var tm: Tilemap
  # read tiled output format
  var data = readJsonFile(joinPath(assetPath,"maps",filename))
  tm.w = data["width"].getBiggestInt.int
  tm.h = data["height"].getBiggestInt.int
  tm.hex = data["orientation"].getStr == "hexagonal"
  tm.tw = data["tilewidth"].getBiggestInt.int
  tm.th = data["tileheight"].getBiggestInt.int
  if tm.hex:
    let hsl = data["hexsidelength"].getBiggestInt.int
    tm.hexOffset = hsl + ((tm.th - hsl) div 2)
  # only look at first layer
  tm.data = newSeq[uint8](tm.w*tm.h)
  for i in 0..<(tm.w*tm.h):
    let t = data["layers"][0]["data"][i].getBiggestInt().uint8 - 1
    tm.data[i] = t.uint8

  currentTilemap = tm

proc pixelToMap*(px,py: Pint): (Pint,Pint) = # returns the tile coordinates at pixel position
  if currentTilemap.hex:
    # pretend they're rectangles
    let ty = py div currentTilemap.hexOffset
    let tx = (px.float32 / currentTilemap.tw.float32) + (if ty mod 2 == 0: 0.5 else: 0)
    return (tx.Pint, ty.Pint)
  else:
    return ((px div currentTilemap.tw).Pint, (py div currentTilemap.th).Pint)

proc mapToPixel*(tx,ty: Pint): (Pint,Pint) = # returns the pixel coordinates at map coord
  if currentTilemap.hex:
    # pretend they're rectangles
    let py = ty * currentTilemap.hexOffset
    let px = tx * currentTilemap.tw - (if ty mod 2 == 0: currentTilemap.tw div 2 else: 0)
    return (px.Pint, py.Pint)
  else:
    return ((ty * currentTilemap.tw).Pint, (ty * currentTilemap.th).Pint)

proc loadMap*(filename: string) =
  if filename.endsWith(".json"):
    loadMapFromJson(filename)
  else:
    when not defined(js):
      loadMapBinary(filename)

proc newMap*(w,h: Pint, tw,th: Pint) =
  currentTilemap.w = w
  currentTilemap.h = h
  currentTilemap.tw = tw
  currentTilemap.th = th
  currentTilemap.data = newSeq[uint8](w*h)

proc rnd*[T: Natural](x: T): T =
  assert x >= 1
  return rand(x.int).T

proc rnd*(x: Pfloat): Pfloat =
  return rand(x)

proc rndbi*(x: Pfloat): Pfloat =
  return rand(x) - rand(x)

proc rnd*[T](a: openarray[T]): T =
  return rand(a)

proc srand*(seed: int) =
  randomize(seed+1)

proc getControllers*(): seq[NicoController] =
  return controllers

proc setFont*(fontId: FontId) =
  # sets the active font to be used by future print calls
  if fontId > fonts.len:
    return
  currentFontId = fontId

proc getFont*(): FontId =
  return currentFontId

proc createWindow*(title: string, w,h: int, scale: int = 2, fullscreen: bool = false) =
  backend.createWindow(title, w, h, scale, fullscreen)
  clip()

proc readFile*(filename: string): string =
  return backend.readFile(filename)

proc readJsonFile*(filename: string): JsonNode =
  return backend.readJsonFile(filename)

when not defined(js):
  proc saveJsonFile*(filename: string, data: JsonNode) =
    backend.saveJsonFile(filename, data)

proc flip*() {.inline.} =
  backend.flip()

proc setFullscreen*(fullscreen: bool) =
  backend.setFullscreen(fullscreen)

proc getFullscreen*(): bool =
  return backend.getFullscreen()

proc setScreenSize*(w,h: int) =
  backend.setScreenSize(w,h)

proc setWindowTitle*(title: string) =
  backend.setWindowTitle(title)

proc cursor*(x,y: Pint) =
  cursorX = x
  cursorY = y

proc noteToNoteStr(value: int): string =
  let oct = value div 12 - 1
  case value mod 12:
  of 0:
    return "C-" & $oct
  of 1:
    return "C#" & $oct
  of 2:
    return "D-" & $oct
  of 3:
    return "D#" & $oct
  of 4:
    return "E-" & $oct
  of 5:
    return "F-" & $oct
  of 6:
    return "F#" & $oct
  of 7:
    return "G-" & $oct
  of 8:
    return "G#" & $oct
  of 9:
    return "A-" & $oct
  of 10:
    return "A#" & $oct
  of 11:
    return "B-" & $oct
  else:
    return "???"

proc noteStrToNote(s: string): int =
  let noteChar = s[0]
  let note = case noteChar
    of 'C': 0
    of 'D': 2
    of 'E': 4
    of 'F': 5
    of 'G': 7
    of 'A': 9
    of 'B': 11
    else: 0
  let sharp = s[1] == '#'
  let octave = parseInt($s[2])
  return 12 * octave + note + (if sharp: 1 else: 0)

proc note*(n: int): Pfloat =
  # takes a note integer and converts it to a frequency float32
  # synth(0, sin, note(48))
  return pow(2.0, ((n.float32 - 69.0) / 12.0)) * 440.0

proc note*(n: string): Pfloat =
  return note(noteStrToNote(n))



proc init*(org, app: string) =
  ## Initializes Nico ready to be used
  controllers = newSeq[NicoController]()

  backend.init(org, app)

  loadPalettePico8()
  setSpritesheet(0)

  initialized = true

  randomize(epochTime().int64)
  loadConfig()

  clip()

proc setInitFunc*(init: (proc())) =
  initFunc = init

proc setUpdateFunc*(update: (proc(dt:float32))) =
  updateFunc = update

proc setDrawFunc*(draw: (proc())) =
  drawFunc = draw

proc setControllerAdded*(cadded: proc(controller: NicoController)) =
  controllerAddedFunc = cadded

proc setControllerRemoved*(cremoved: proc(controller: NicoController)) =
  controllerRemovedFunc = cremoved

proc run*(init: (proc()), update: (proc(dt:float32)), draw: (proc())) =
  debug "run"
  assert(update != nil)
  assert(draw != nil)

  initFunc = init
  updateFunc = update
  drawFunc = draw

  if initFunc != nil:
    initFunc()

  if not common.running:
    common.running = true
    backend.run()

proc setBasePath*(path: string) =
  if path.endswith("/"):
    basePath = path
  else:
    basePath = path & "/"

proc setWritePath*(path: string) =
  if path.endswith("/"):
    writePath = path
  else:
    writePath = path & "/"

proc setAssetPath*(path: string) =
  if path.endswith("/"):
    assetPath = path
  else:
    assetPath = path & "/"

proc bpm*(newBpm: Natural) =
  currentBpm = newBpm

proc tpb*(newTpb: Natural) =
  currentTpb = newTpb

proc setTickFunc*(f: proc()) =
  tickFunc = f

proc addKeyListener*(p: KeyListener) =
  keyListeners.add(p)

proc removeKeyListener*(p: KeyListener) =
  for i,v in keyListeners:
    if v == p:
      keyListeners.del(i)
      break

proc sgn*(x: Pint): Pint =
  if x < 0:
    return -1
  if x >= 0:
    return 1
  else:
    return 0

const DEG2RAD* = PI / 180.0
const RAD2DEG* = 180.0 / PI

proc deg2rad*[T](x: T): T =
  x * DEG2RAD

proc rad2deg*[T](x: T): T =
  x * RAD2DEG

converter toPint*(x: uint8): Pint =
  x.Pint

iterator all*[T](a: var openarray[T]): T {.inline.} =
  let len = a.len
  for i in 0..<len:
    yield a[i]

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

when defined(test):
  import unittest

  suite "nico":
    test "roundTo":
      check(roundTo(16, 16) == 16)
      check(roundTo(0, 16) == 0)
      check(roundTo(8, 16) == 0)
      check(roundTo(17, 16) == 16)
      check(roundTo(32, 16) == 32)
      check(roundTo(31, 16) == 16)
      check(roundTo(-1, 16) == -16)
      check(roundTo(-16, 16) == -16)
      check(roundTo(-17, 16) == -32)

    test "remainder":
      check(remainder(16, 16) == 0)
      check(remainder(8, 16) == 8)
      check(remainder(17, 16) == 1)
      check(remainder(32, 16) == 0)
      check(remainder(31, 16) == 15)
      check(remainder(-16, 16) == 0)
      check(remainder(-15, 16) == 1)
      check(remainder(-4, 4) == 0)
      check(remainder(-3, 4) == 1)
      check(remainder(-2, 4) == 2)
      check(remainder(-1, 4) == 3)
      check(remainder(0, 4) == 0)
      check(remainder(1, 4) == 1)
      check(remainder(2, 4) == 2)
      check(remainder(3, 4) == 3)
      check(remainder(4, 4) == 0)

    test "mid":
      check(mid(0, 1, 10) == 1)
      check(mid(10, 1, -1) == 1)
      check(mid(1, 10, -1) == 1)
      check(mid(-10, 10, 100) == 10)
      check(mid(-100, -10, 100) == -10)

    test "ceil":
      check(ceil(0.5) == 1)
      check(ceil(0.1) == 1)
      check(ceil(0) == 0)
      check(ceil(-0.1) == 0)
