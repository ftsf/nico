import nico.backends.common

when defined(js):
  import nico.backends.js as backend
else:
  import nico.backends.sdl2 as backend

when defined(sdlmixer):
  export initMixer

import nico.controller
export NicoController
export NicoControllerKind
export NicoAxis
export NicoButton

export btn
export btnp
export btnpr
export axis
export axisp

import nico.ringbuffer
import math
import algorithm
import strutils
import json
import sequtils
export math.sin
import random
import times
import strscans

## Public API

export timeStep

export Pint
export toPint
export SfxId
export MusicId

export sfx
export music
export loadSfx
export loadMusic
export sfxVol
export musicVol

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
proc btn*(b: NicoButton): bool
proc btnp*(b: NicoButton): bool
proc btnpr*(b: NicoButton, repeat = 48): bool
proc jaxis*(axis: NicoAxis): float

proc btn*(b: NicoButton, player: range[0..maxPlayers]): bool
proc btnp*(b: NicoButton, player: range[0..maxPlayers]): bool
proc btnpr*(b: NicoButton, player: range[0..maxPlayers], repeat = 48): bool
proc jaxis*(axis: NicoAxis, player: range[0..maxPlayers]): float
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

# sprites
proc spr*(spr: range[0..255], x,y: Pint, w,h: Pint = 1, hflip, vflip: bool = false)
proc sprs*(spr: range[0..255], x,y: Pint, w,h: Pint = 1, dw,dh: Pint = 1, hflip, vflip: bool = false)
proc sspr*(sx,sy, sw,sh, dx,dy: Pint, dw,dh: Pint = -1, hflip, vflip: bool = false)

# misc
proc copy*(sx,sy,dx,dy,w,h: Pint) # copy one area of the screen to another

## System functions
proc shutdown*()
#proc createWindow*(title: string, w,h: Pint, scale: Pint = 2, fullscreen: bool = false)
proc init*(org: string, app: string)

# Tilemap functions
proc mset*(tx,ty: Pint, t: uint8)
proc mget*(tx,ty: Pint): uint8
proc mapDraw*(tx,ty, tw,th, dx,dy: Pint)
proc loadMap*(filename: string)
proc newMap*(w,h: Pint)

#proc saveMap*(filename: string)

export toPint
export screenWidth
export screenHeight

# Maths functions
proc flr*(x: float): float
proc ceil*(x: float): float =
  -flr(-x)
proc lerp*[T](a,b: T, t: float): T

proc rnd*[T: Ordinal](x: T): T
proc rnd*[T](a: openarray[T]): T
proc rnd*(x: float): float

## Internal functions

proc psetRaw*(x,y: int, c: ColorId) {.inline.}

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

proc loadPaletteFromGPL*(filename: string) =
  var data = backend.readFile(assetPath & filename)
  var i = 0
  for line in data.splitLines():
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
      colors[i-1] = RGB(r,g,b)
      if i > 15:
        break
      i += 1
    else:
      echo "not matched: ", line


proc loadPaletteCGA*() =
  colors[0]  = RGB(0,0,0)
  colors[1]  = RGB(85,255,255)
  colors[2]  = RGB(255,85,255)
  colors[3]  = RGB(255,255,255)
  colors[4]  = RGB(0,0,0)
  colors[5]  = RGB(0,0,0)
  colors[6]  = RGB(0,0,0)
  colors[7]  = RGB(0,0,0)
  colors[8]  = RGB(0,0,0)
  colors[9]  = RGB(0,0,0)
  colors[10] = RGB(0,0,0)
  colors[11] = RGB(0,0,0)
  colors[12] = RGB(0,0,0)
  colors[13] = RGB(0,0,0)
  colors[14] = RGB(0,0,0)
  colors[15] = RGB(0,0,0)

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

proc jaxis*(axis: NicoAxis): float =
  for c in controllers:
    let v = c.axis(axis)
    if abs(v) > c.deadzone:
      return v
  return 0.0

proc jaxis*(axis: NicoAxis, player: range[0..maxPlayers]): float =
  if player > controllers.high:
    return 0.0
  return controllers[player].axis(axis)

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

proc lineDashed*(x0,y0,x1,y1: Pint, pattern: uint8 = 0b10101010) =
  var x = x0
  var y = y0
  var dx: int = abs(x1-x0)
  var sx: int = if x0 < x1: 1 else: -1
  var dy: int = abs(y1-y0)
  var sy: int = if y0 < y1: 1 else: -1
  var err: float = (if dx>dy: dx else: -dy).float/2.0
  var e2: float = 0

  var i = 0

  while true:
    if pattern shl ((i mod 8) + 1) != 0:
      pset(x,y)
    i += 1
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

proc flr*(x: float): float =
  return x.floor()

proc lerp[T](a, b: T, t: float): T =
  return a + (b - a) * t

{.push checks: off, optimization: speed.}
type Bresenham = object
  x,y: int
  x1,y1: int
  dx,sx: int
  dy,sy: int
  err: float
  e2: float
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
  result.err = (if result.dx > result.dy: result.dx else: -result.dy).float / 2.0
  result.e2 = 0.0
  result.finished = false

{.this:self.}
proc step(self: var Bresenham): (int,int) =
  if finished:
    return (x,y)
  while true:
    if x == x1 and y == y1:
      finished = true
      return (x,y)
    e2 = err
    if e2 > -dx:
      err -= dy.float
      x += sx
    if e2 < dy:
      err += dx.float
      y += sy
      return (x,y)

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


proc fontBlit(font: Font, srcRect, dstRect: Rect, color: ColorId) =
  var dx = dstRect.x.float
  var dy = dstRect.y.float
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
      if sx < 0 or sy < 0 or sx > font.w - 1 or sy > font.h - 1:
        continue
      if dx < clipMinX or dy < clipMinY or dx > clipMaxX or dy > clipMaxY:
        continue
      if font.data[sy * font.w + sx] == 1:
        swCanvas.data[dy * swCanvas.w + dx] = currentColor
      sx += 1.0 * (sw/dw)
      dx += 1.0
    sy += 1.0 * (sh/dh)
    dy += 1.0

proc overlap(a,b: Rect): bool =
  return not ( a.x > b.x + b.w or a.y > b.y + b.h or a.x + a.w < b.x or a.y + a.h < b.y )

proc blitFastRaw(src: Surface, sx,sy, dx,dy, w,h: Pint) =
  # used for tile drawing, no stretch or flipping
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
      let srcCol = src.data[syi * src.w + sxi]
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
      if not (dx < clipMinX or dy < clipMinY or dx > clipMaxX or dy > clipMaxY):
        let srcCol = src.data[sy * src.w + sx]
        if not paletteTransparent[srcCol]:
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

proc blitStretch(src: Surface, srcRect, dstRect: Rect, hflip, vflip: bool = false) =
  # if dstrect doesn't overlap clipping rect, skip it
  if not overlap(dstrect, clippingRect):
    return

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
      if not (dx < clipMinX or dy < clipMinY or dx > clipMaxX or dy > clipMaxY):
        let srcCol = src.data[sy * src.w + sx]
        if not paletteTransparent[srcCol]:
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

proc createFontFromSurface(surface: Surface, chars: string): Font =
  var font = new(Font)

  font.w = surface.w
  font.h = surface.h
  font.data = newSeq[uint8](font.w*font.h)

  for i in 0..<font.w*font.h:
    if surface.data[i*4+3] == 0:
      font.data[i] = 0
    elif surface.data[i*4+0] > 0.uint8:
      font.data[i] = 2
    else:
      font.data[i] = 1

  var highestChar: char
  for c in chars:
    if c > highestChar:
      highestChar = c
  font.rects = newSeq[Rect](highestChar.int+1)

  var newChar = false
  let blankColor = font.data[0]
  var currentRect: Rect = (0,0,0,0)
  var i = 0
  for x in 0..<font.w:
    let color = font.data[x]
    if color == blankColor:
      currentRect.w = x - currentRect.x
      if currentRect.w != 0:
        # go down until we find blank or h
        currentRect.h = font.h-1
        for y in 0..<font.h:
          let color = font.data[y*font.w+x]
          if color == blankColor:
            currentRect.h = y-2
        let charId = chars[i].int
        font.rects[charId] = currentRect
        i += 1
      newChar = true
      currentRect.x = x + 1

  return font

proc loadFont*(filename: string, chars: string) =
  loadSurface(assetPath & filename) do(surface: Surface):
    fonts[currentFontId] = createFontFromSurface(surface, chars)
    debug("font created from ", filename)

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
    echo "index error glyph: ", c, " @ ", x, ",", y
    raise
  return src.w * scale + scale

proc print*(text: string, x,y: Pint, scale: Pint = 1) =
  var x = x - cameraX
  let y = y - cameraY
  for c in text:
    x += glyph(c, x, y, scale)

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
  if swCanvas.data != nil:
    cls()
    present()

proc resize() =
  backend.resize()
  clip()
  if swCanvas.data != nil:
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

proc loadSpriteSheet*(filename: string) =
  loadSurface(assetPath & filename) do(surface: Surface):
    spriteSheet[] = surface.convertToIndexed()

proc getSprRect(spr: range[0..255], w,h: Pint = 1): Rect {.inline.} =
  result.x = spr%%16 * 8
  result.y = spr div 16 * 8
  result.w = w * 8
  result.h = h * 8

proc spr*(spr: range[0..255], x,y: Pint, w,h: Pint = 1, hflip, vflip: bool = false) =
  # draw a sprite
  var src = getSprRect(spr, w, h)
  var dst: Rect = ((x-cameraX).int,(y-cameraY).int,src.w,src.h)
  if hflip or vflip:
    blitFastFlip(spriteSheet[], src.x, src.y, x-cameraX, y-cameraY, src.w, src.h, hflip, vflip)
  else:
    blitFast(spriteSheet[], src.x, src.y, x-cameraX, y-cameraY, src.w, src.h)

proc sprBlit*(spr: range[0..255], x,y: Pint, w,h: Pint = 1) =
  # draw a sprite
  let src = getSprRect(spr, w, h)
  let dst: Rect = ((x-cameraX).int,(y-cameraY).int,src.w,src.h)
  blit(spriteSheet[], src, dst)

proc sprBlitFast*(spr: range[0..255], x,y: Pint, w,h: Pint = 1) =
  # draw a sprite
  let src = getSprRect(spr, w, h)
  blitFast(spriteSheet[], src.x, src.y, x-cameraX, y-cameraY, src.w, src.h)

proc sprBlitFastRaw*(spr: range[0..255], x,y: Pint, w,h: Pint = 1) =
  # draw a sprite
  let src = getSprRect(spr, w, h)
  blitFastRaw(spriteSheet[], src.x, src.y, x-cameraX, y-cameraY, src.w, src.h)

proc sprBlitStretch*(spr: range[0..255], x,y: Pint, w,h: Pint = 1) =
  # draw a sprite
  let src = getSprRect(spr, w, h)
  let dst: Rect = ((x-cameraX).int,(y-cameraY).int,src.w,src.h)
  blitStretch(spriteSheet[], src, dst)

proc sprs*(spr: range[0..255], x,y: Pint, w,h: Pint = 1, dw,dh: Pint = 1, hflip, vflip: bool = false) =
  # draw an integer scaled sprite
  var src = getSprRect(spr, w, h)
  var dst: Rect = ((x-cameraX).int,(y-cameraY).int,(dw*8).int,(dh*8).int)
  blit(spriteSheet[], src, dst, hflip, vflip)

proc sprss*(spr: range[0..255], x,y: Pint, w,h: Pint = 1, dw,dh: Pint, hflip, vflip: bool = false) =
  # draw a scaled sprite
  var src = getSprRect(spr, w, h)
  var dst: Rect = ((x-cameraX).int,(y-cameraY).int,dw.int,dh.int)
  blit(spriteSheet[], src, dst, hflip, vflip)

proc drawTile(spr: range[0..255], x,y: Pint, tileSize = 8) =
  var src = getSprRect(spr)
  let x = x-cameraX
  let y = y-cameraY
  if overlap(clippingRect,(x.int,y.int,tileSize,tileSize)):
    blitFast(spriteSheet[], src.x, src.y, x, y, tileSize, tileSize)

proc sspr*(sx,sy, sw,sh, dx,dy: Pint, dw,dh: Pint = -1, hflip, vflip: bool = false) =
  var src: Rect = (sx.int,sy.int,sw.int,sh.int)
  let dw = if dw >= 0: dw else: sw
  let dh = if dh >= 0: dh else: sh
  var dst: Rect = ((dx-cameraX).int,(dy-cameraY).int,dw.int,dh.int)
  blitStretch(spriteSheet[], src, dst, hflip, vflip)

proc mapDraw*(tx,ty, tw,th, dx,dy: Pint) =
  if currentTilemap.data == nil:
    return
  # draw map tiles to the screen
  var xi = dx
  var yi = dy
  var increment = 8
  for y in ty..ty+th-1:
    if y >= 0 and y < currentTilemap.h:
      for x in tx..tx+tw-1:
        if x >= 0  and x < currentTilemap.w:
          let t = currentTilemap.data[y * currentTilemap.w + x]
          if t != 0:
            drawTile(t, xi, yi, increment)
        xi += increment
    yi += increment
    xi = dx

proc mapWidth*(): Pint =
  return currentTilemap.w

proc mapHeight*(): Pint =
  return currentTilemap.h

proc `%%/`[T](x,m: T): T =
  return (x mod m + m) mod m

proc loadMapFromJson(filename: string) =
  var tm: Tilemap
  # read tiled output format
  var data = readJsonFile(assetPath & "/maps/" & filename)
  tm.w = data["width"].getNum.int
  tm.h = data["height"].getNum.int
  # only look at first layer
  tm.data = newSeq[uint8](tm.w*tm.h)
  for i in 0..<(tm.w*tm.h):
    let t = data["layers"][0]["data"][i].getNum().uint8 - 1
    tm.data[i] = t.uint8

  currentTilemap = tm

proc loadMap*(filename: string) =
  if filename.endsWith(".json"):
    loadMapFromJson(filename)
  else:
    when not defined(js):
      loadMapBinary(filename)

proc newMap*(w,h: Pint) =
  currentTilemap.w = w
  currentTilemap.h = h
  currentTilemap.data = newSeq[uint8](w*h)

proc rnd*[T: Ordinal](x: T): T =
  if x == 0:
    return 0
  return random(x.int).T

proc rnd*(x: float): float =
  return random(x)

proc rnd*[T](a: openarray[T]): T =
  return random(a)

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

proc readFile*(filename: string): string =
  return backend.readFile(filename)

proc readJsonFile*(filename: string): JsonNode =
  return backend.readJsonFile(filename)

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

proc init*(org, app: string) =
  ## Initializes Nico ready to be used
  controllers = newSeq[NicoController]()

  backend.init(org, app)

  loadPalettePico8()
  setSpritesheet(0)

  initialized = true

  randomize()
  setFont(0)
  try:
    loadFont("font.png", " !\"#$%&'()*+,-./0123456789:;<=>?@abcdefghijklmnopqrstuvwxyz[\\]^_`ABCDEFGHIJKLMNOPQRSTUVWXYZ{:}~")
  except IOError:
    discard
  loadConfig()

  clip()

proc setInitFunc*(init: (proc())) =
  initFunc = init

proc setUpdateFunc*(update: (proc(dt:float))) =
  updateFunc = update

proc setDrawFunc*(draw: (proc())) =
  drawFunc = draw

proc setControllerAdded*(cadded: proc(controller: NicoController)) =
  controllerAddedFunc = cadded

proc setControllerRemoved*(cremoved: proc(controller: NicoController)) =
  controllerRemovedFunc = cremoved

proc run*(init: (proc()), update: (proc(dt:float)), draw: (proc())) =
  assert(update != nil)
  assert(draw != nil)

  initFunc = init
  updateFunc = update
  drawFunc = draw

  if initFunc != nil:
    initFunc()

  if not running:
    running = true
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
