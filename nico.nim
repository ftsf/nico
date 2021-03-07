import nico/backends/common
import tables
import unicode

import nico/keycodes
export keycodes

import nico/spritedraw
export spritedraw

when defined(js):
  import nico/backends/js as backend

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

export StencilMode

export EventListener

export SynthData
export SynthDataStep
export synthDataToString
export synthDataFromString
export synthIndex

export profileGetLastStats
export profileGetLastStatsPeak
export profileCollect
export profileBegin
export profileEnd
export ProfilerNode
export profileHistory

export errorPopup

export setClipboardText

# Audio
export joinPath
export loadSfx
export loadMusic
export sfx
export music
export getMusic
export synth
export SfxId

when not defined(js):
  export setAudioCallback
  export setAudioBufferSize
  export audioInSample
  export audioOut

export synthUpdate
export synthShape
export SynthShape
export vibrato
export glide
export wavData
export pitchbend
export pitch

# shader stuff
export setShaderBool
export setShaderFloat
export setLinearFilter

export clipMinX,clipMinY,clipMaxX,clipMaxY
export currentColor
export cameraX,cameraY

export debug
import nico/controller
export NicoController
export NicoControllerKind
export NicoAxis
export NicoButton
export ColorId

when not defined(js):
  export startTextInput
  export stopTextInput
  export isTextInput

export btn
export btnp
export btnpr
export btnup
export axis
export axisp

export TouchState
export Touch

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
export shuffle

import times
import strscans
import strutils

## Public API

export Event
export EventKind

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

# Fonts
proc getFont*(): FontId
proc setFont*(fontId: FontId)

# Printing text
proc glyph*(c: Rune, x,y: Pint, scale: Pint = 1): Pint {.discardable, inline.}
proc glyph*(c: char, x,y: Pint, scale: Pint = 1): Pint {.discardable, inline.}

proc cursor*(x,y: Pint) # set cursor position
proc print*(text: string) # print at cursor
proc print*(text: string, x,y: Pint, scale: Pint = 1)
proc printc*(text: string, x,y: Pint, scale: Pint = 1) # centered
proc printr*(text: string, x,y: Pint, scale: Pint = 1) # right aligned

proc textWidth*(text: string, scale: Pint = 1): Pint
proc glyphWidth*(c: Rune, scale: Pint = 1): Pint
proc glyphWidth*(c: char, scale: Pint = 1): Pint

# Colors
proc setColor*(colId: ColorId)
proc getColor*(): ColorId
proc loadPaletteFromGPL*(filename: string): Palette
proc loadPaletteFromImage*(filename: string): Palette
proc loadPalettePico8*(): Palette
proc loadPaletteCGA*(): Palette
proc loadPaletteGrayscale*(): Palette
proc palSize*(): Pint

proc pal*(a,b: ColorId) # maps one color to another
proc pal*(a: ColorId): ColorId # returns the color mapping for `a`
proc pald*(a,b: ColorId) # maps one color to another on display output
proc pald*(a: ColorId): ColorId # returns the display color mapping for `a`
proc pal*() # resets palette
proc pald*() # resets display palette
proc palt*(a: ColorId, trans: bool) # sets transparency for color
proc palt*() # resets transparency

proc palCol*(c: Pint, r,g,b: uint8) =
  ## sets the palette color to rgb value
  currentPalette.data[c.uint8] = (r,g,b)

proc palCol*(c: Pint): (uint8,uint8,uint8) =
  ## gets the palette color as rgb
  return currentPalette.data[c.uint8]

proc palIndex*(r,g,b: uint8): int =
  ## gets the closest color in the palette to given r,g,b
  var bestIndex = 0
  var smallestDiff = 99999
  for i,v in currentPalette.data:
    let rdiff = abs(v.r.int - r.int)
    let gdiff = abs(v.g.int - g.int)
    let bdiff = abs(v.b.int - b.int)
    let diff = rdiff + gdiff + bdiff
    if diff < smallestDiff:
      smallestDiff = diff
      bestIndex = i
  return bestIndex

# Clipping
proc clip*(x,y,w,h: Pint)
proc clip*()
proc getClip*(): (int,int,int,int)

# Bitops
proc contains[T](flags: T, bit: T): bool =
  return (flags.int and 1 shl bit.int) != 0

proc set[T](flags: var T, bit: T) =
  flags = (flags.int or 1 shl bit.int).T

proc unset[T](flags: var T, bit: T) =
  flags = (flags.int and (not 1 shl bit.int)).T



# Stencil
proc stencilSet*(x,y,v: Pint) =
  stencilBuffer.set(x,y,v.uint8)
proc stencilGet*(x,y: Pint): uint8 =
  return stencilBuffer.get(x,y)
proc setStencilRef*(v: Pint) =
  stencilRef = v.uint8
proc setStencilWrite*(on: bool) =
  stencilWrite = on
proc stencilMode*(mode: StencilMode) =
  common.stencilMode = mode
proc stencilClear*() =
  for i in 0..<screenWidth*screenHeight:
    stencilBuffer.data[i] = 0
proc stencilClear*(v: Pint) =
  for i in 0..<screenWidth*screenHeight:
    stencilBuffer.data[i] = v.uint8
proc stencilTest(x,y: int, nv: uint8): bool =
  if common.stencilMode == stencilAlways:
    return true
  let v = stencilBuffer.get(x,y)
  case common.stencilMode:
  of stencilAlways:
    return true
  of stencilEqual:
    return nv == v
  of stencilLess:
    return nv < v
  of stencilGreater:
    return nv > v
  of stencilLEqual:
    return nv <= v
  of stencilGEqual:
    return nv >= v
  of stencilNot:
    return nv != v

# Camera
proc setCamera*(x,y: Pint = 0)
proc getCamera*(): (Pint,Pint)

# Input Gamepad
proc btn*(b: NicoButton): bool
proc btnp*(b: NicoButton): bool
proc btnup*(b: NicoButton): bool
proc btnpr*(b: NicoButton, repeat = 48): bool
proc jaxis*(axis: NicoAxis): Pfloat

proc btn*(b: NicoButton, player: range[0..maxPlayers]): bool
proc btnp*(b: NicoButton, player: range[0..maxPlayers]): bool
proc btnup*(b: NicoButton, player: range[0..maxPlayers]): bool
proc btnpr*(b: NicoButton, player: range[0..maxPlayers], repeat = 48): bool
proc btnRaw*(b: NicoButton, player: range[0..maxPlayers]): int
proc jaxis*(axis: NicoAxis, player: range[0..maxPlayers]): Pfloat

# Input / Mouse
proc mouse*(): (int,int)
proc mouserel*(): (float32,float32)
proc mousebtn*(b: range[0..2]): bool
proc mousebtnup*(b: range[0..2]): bool
proc mousebtnp*(b: range[0..2]): bool
proc mousebtnpr*(b: range[0..2], r: Pint = 48): bool
proc mousewheel*(): int

# Input / Touch
proc getTouches*(): seq[Touch] =
  return touches
proc getTouchCount*(): int =
  return touches.len

export hideMouse
export showMouse

## Drawing API

# pixels
proc pset*(x,y: Pint)
proc pget*(x,y: Pint): ColorId
proc pgetRGB*(x,y: Pint): (uint8,uint8,uint8)
proc sset*(x,y: Pint, c: int = -1)
proc sget*(x,y: Pint): ColorId

# rectangles
proc rect*(x1,y1,x2,y2: Pint)
proc rectfill*(x1,y1,x2,y2: Pint)
proc rrect*(x1,y1,x2,y2: Pint, r: Pint = 1)
proc rrectfill*(x1,y1,x2,y2: Pint, r: Pint = 1)
proc rectCorner*(x1,y1,x2,y2: Pint)
proc rrectCorner*(x1,y1,x2,y2: Pint)
proc box*(x,y,w,h: Pint)
proc boxfill*(x,y,w,h: Pint)

# line drawing
proc line*(x0,y0,x1,y1: Pint)
proc hline*(x0,y,x1: Pint)
proc hlineFast(x0,y,x1: Pint)
proc vline*(x,y0,y1: Pint)

# triangles
proc trifill*(ax,ay,bx,by,cx,cy: Pint)
proc quadfill*(x1,y1,x2,y2,x3,y3,x4,y4: Pint)

# circles
proc circfill*(cx,cy: Pint, r: Pint)
proc circ*(cx,cy: Pint, r: Pint)
proc ellipsefill*(cx,cy: Pint, rx,ry: Pint)

# sprites
proc spr*(spr: Pint, x,y: Pint, w,h: Pint = 1, hflip, vflip: bool = false)
proc sprs*(spr: Pint, x,y: Pint, w,h: Pint = 1, dw,dh: Pint = 1, hflip, vflip: bool = false)
proc sspr*(sx,sy, sw,sh, dx,dy: Pint, dw,dh: Pint = -1, hflip, vflip: bool = false)
proc sprshift*(spr: Pint, x,y: Pint, w,h: Pint = 1, ox,oy: Pint = 0, hflip, vflip: bool = false)
proc sprRot*(spr: Pint, x,y: Pint, radians: float32, w,h: Pint = 1)
proc sprRot90*(spr: Pint, x,y: Pint, rotations: int, w,h: Pint = 1)
proc spr*(drawer: SpriteDraw)
proc spr*(drawer: SpriteDraw, x,y: Pint)
proc sprOverlap*(a, b: SpriteDraw): bool

# misc
proc copy*(sx,sy,dx,dy,w,h: Pint) # copy one area of the screen to another


# math
export sin
export cos
export abs
export `mod`

proc wrap*[T](x,m: T): T

proc clamp*[T](a: T): T =
  clamp(a, 0, 1)

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
proc mapDraw*(tx,ty, tw,th, dx,dy: Pint, dw,dh: Pint = -1, loop: bool = false, ox,oy: Pint = 0)
proc setMap*(index: int)
proc loadMap*(index: int, filename: string, layer: int = 0)
proc newMap*(index: int, w,h: Pint, tw,th: Pint = 8)
proc pixelToMap*(px,py: Pint): (Pint,Pint) # returns the tile coordinates at pixel position
proc mapToPixel*(tx,ty: Pint): (Pint,Pint) # returns the pixel position of the tile coordinates
proc saveMap*(index: int, filename: string)

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

proc psetRaw*(x,y: int, c: Pint) {.inline.}
proc psetRaw*(x,y: int) {.inline.}

proc fps*(fps: int) =
  frameRate = fps
  timeStep = 1.0 / fps.float32

proc fps*(): int =
  return frameRate

proc time*(): float =
  return epochTime()

proc speed*(speed: int) =
  frameMult = speed

proc loadPaletteFromImage*(filename: string): Palette =
  var loaded = false
  var palette: Palette
  backend.loadSurfaceRGBA(joinPath(assetPath,filename)) do(surface: Surface):
    if surface == nil:
      loaded = true
      raise newException(IOError, "Error loading palette image: " & filename)
    var nColors = 0
    for y in 0..<surface.h:
      for x in 0..<surface.w:
        let r = surface.data[y * surface.w * 4 + x * 4 + 0]
        let g = surface.data[y * surface.w * 4 + x * 4 + 1]
        let b = surface.data[y * surface.w * 4 + x * 4 + 2]
        palette.data[nColors] = RGB(r,g,b)
        nColors += 1
    palette.size = nColors
    loaded = true
  while not loaded:
    # force sync
    discard
  return palette

proc loadPaletteFromGPL*(filename: string): Palette =
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
      result.data[i-1] = RGB(r,g,b)
      result.size += 1
      if i > maxPaletteSize:
        break
      i += 1
    else:
      debug "not matched: ", line
  pal()
  pald()
  palt()

proc palSize*(): Pint =
  return currentPalette.size

proc setPalette*(p: Palette) =
  currentPalette = p

proc getPalette*(): Palette =
  return currentPalette

proc loadPaletteCGA*(): Palette =
  result.data[0] = RGB(0,0,0)
  result.data[1] = RGB(85,255,255)
  result.data[2] = RGB(255,85,255)
  result.data[3] = RGB(255,255,255)
  result.size = 4

proc loadPalettePico8*(): Palette =
  result.data[0]  = RGB(0,0,0)
  result.data[1]  = RGB(29,43,83)
  result.data[2]  = RGB(126,37,83)
  result.data[3]  = RGB(0,135,81)
  result.data[4]  = RGB(171,82,54)
  result.data[5]  = RGB(95,87,79)
  result.data[6]  = RGB(194,195,199)
  result.data[7]  = RGB(255,241,232)
  result.data[8]  = RGB(255,0,77)
  result.data[9]  = RGB(255,163,0)
  result.data[10] = RGB(255,240,36)
  result.data[11] = RGB(0,231,86)
  result.data[12] = RGB(41,173,255)
  result.data[13] = RGB(131,118,156)
  result.data[14] = RGB(255,119,168)
  result.data[15] = RGB(255,204,170)
  result.size = 16

proc loadPalettePico8Extra*(): Palette =
  result.data[0]  = RGB(0,0,0)
  result.data[1]  = RGB(29,43,83)
  result.data[2]  = RGB(126,37,83)
  result.data[3]  = RGB(0,135,81)
  result.data[4]  = RGB(171,82,54)
  result.data[5]  = RGB(95,87,79)
  result.data[6]  = RGB(194,195,199)
  result.data[7]  = RGB(255,241,232)
  result.data[8]  = RGB(255,0,77)
  result.data[9]  = RGB(255,163,0)
  result.data[10] = RGB(255,240,36)
  result.data[11] = RGB(0,231,86)
  result.data[12] = RGB(41,173,255)
  result.data[13] = RGB(131,118,156)
  result.data[14] = RGB(255,119,168)
  result.data[15] = RGB(255,204,170)
  result.data[16] = RGB(37, 25, 21)
  result.data[17] = RGB(22, 28, 51)
  result.data[18] = RGB(59, 34, 53)
  result.data[19] = RGB(48, 82, 88)
  result.data[20] = RGB(102, 51, 43)
  result.data[21] = RGB(68, 52, 59)
  result.data[22] = RGB(155, 137, 123)
  result.data[23] = RGB(240, 240, 140)
  result.data[24] = RGB(164, 41, 79)
  result.data[25] = RGB(225, 117, 54)
  result.data[26] = RGB(186, 230, 85)
  result.data[27] = RGB(99, 179, 83)
  result.data[28] = RGB(55, 88, 175)
  result.data[29] = RGB(106, 72, 99)
  result.data[30] = RGB(225, 119, 94)
  result.data[31] = RGB(232, 162, 133)
  result.size = 32

proc loadPaletteGrayscale*(): Palette =
  for i in 0..<256:
    result.data[i] = RGB(i,i,i)
  result.size = 256

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

proc getClip*(): (int,int,int,int) =
  return (clipMinX,clipMinY,clipMaxX-clipMinX,clipMaxY-clipMinY)

var ditherColor: int = -1

proc setDitherColor*(c: Pint = -1) =
  ditherColor = c

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

proc ditherPatternBigCheckerboard*() =
  gDitherPattern = 0b1100_1100_0011_0011

proc ditherPatternBigCheckerboard2*() =
  gDitherPattern = 0b0011_0011_1100_1100

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

proc btnup*(b: NicoButton): bool =
  for c in controllers:
    if c.btnup(b):
      return true
  return false

proc btn*(b: NicoButton, player: range[0..maxPlayers]): bool =
  if player > controllers.high:
    return false
  return controllers[player].btn(b)

proc btnup*(b: NicoButton, player: range[0..maxPlayers]): bool =
  if player > controllers.high:
    return false
  return controllers[player].btnup(b)

proc btnRaw*(b: NicoButton, player: range[0..maxPlayers]): int =
  if player > controllers.high:
    return 0
  return controllers[player].buttons[b]

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

proc key*(k: Keycode): bool =
  keysDown.hasKey(k) and keysDown[k] != 0

proc keyp*(k: Keycode): bool =
  keysDown.hasKey(k) and keysDown[k] == 1

proc keypr*(k: Keycode, repeat: int = 48): bool =
  keysDown.hasKey(k) and keysDown[k].int mod repeat == 1

proc anykeyp*(): bool =
  aKeyWasPressed

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

proc pal*(a: ColorId): ColorId =
  return paletteMapDraw[a]

proc pal*() =
  for i in 0..<maxPaletteSize:
    paletteMapDraw[i] = i

proc pald*(a,b: ColorId) =
  paletteMapDisplay[a] = b

proc pald*(a: ColorId): ColorId =
  return paletteMapDisplay[a]

proc pald*() =
  for i in 0..<maxPaletteSize:
    paletteMapDisplay[i] = i

proc palt*(a: ColorId, trans: bool) =
  paletteTransparent[a] = trans

proc palt*() =
  for i in 0..<maxPaletteSize:
    paletteTransparent[i] = if i == 0: true else: false

{.push checks:off, optimization: speed.}
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

proc pset*(x,y: Pint, c: ColorId) =
  let x = x-cameraX
  let y = y-cameraY
  if x < clipMinX or y < clipMinY or x > clipMaxX or y > clipMaxY:
    return
  if stencilTest(x,y,stencilRef):
    if ditherPass(x,y):
      swCanvas.set(x,y,paletteMapDraw[c].uint8)
    elif ditherColor >= 0:
      swCanvas.set(x,y,paletteMapDraw[ditherColor.ColorId].uint8)
    if stencilWrite:
      stencilBuffer.set(x,y,stencilRef)

proc pset*(x,y: Pint) =
  pset(x,y,currentColor)

proc psetRaw*(x,y: int, c: Pint) =
  # relies on you not going outside the buffer bounds
  if stencilTest(x,y,stencilRef):
    if ditherPass(x,y):
      swCanvas.set(x,y,c.uint8)
    elif ditherColor >= 0:
      swCanvas.set(x,y,ditherColor.uint8)
    if stencilWrite:
      stencilBuffer.set(x,y,stencilRef)

proc psetRaw*(x,y: int) =
  psetRaw(x,y,currentColor)

proc ssetSafe*(x,y: Pint, c: int = -1) =
  let c = if c == -1: currentColor else: c
  if x < 0 or y < 0 or x > spritesheet.w-1 or y > spritesheet.h-1:
    return
  spritesheet.data[y*spritesheet.w+x] = paletteMapDraw[c].uint8

proc sset*(x,y: Pint, c: int = -1) =
  let c = if c == -1: currentColor else: c
  if x < 0 or y < 0 or x > spritesheet.w-1 or y > spritesheet.h-1:
    raise newException(RangeError, "sset ($1,$2) out of bounds".format(x,y))
  spritesheet.data[y*spritesheet.w+x] = paletteMapDraw[c].uint8

proc sget*(x,y: Pint): ColorId =
  if x > spritesheet.w-1 or x < 0 or y > spritesheet.h-1 or y < 0:
    debug "sget invalid coord: ", x, y
    return 0
  let color = spritesheet.data[y*spritesheet.w+x].ColorId
  return color

proc pget*(x,y: Pint): ColorId =
  let x = x-cameraX
  let y = y-cameraY
  if x > swCanvas.w-1 or x < 0 or y > swCanvas.h-1 or y < 0:
    return 0
  return swCanvas.data[y*swCanvas.w+x].ColorId

proc pgetRGB*(x,y: Pint): (uint8,uint8,uint8) =
  if x > swCanvas.w-1 or x < 0 or y > swCanvas.h-1 or y < 0:
    return (0'u8,0'u8,0'u8)
  return palCol(swCanvas.data[y*swCanvas.w+x].ColorId)

proc rectfill*(x1,y1,x2,y2: Pint) =
  let minx = min(x1,x2)
  let maxx = max(x1,x2)
  let miny = min(y1,y2)
  let maxy = max(y1,y2)
  for y in miny..maxy:
    for x in minx..maxx:
      pset(x,y)

proc rrectfill*(x1,y1,x2,y2: Pint, r: Pint = 1) =
  let minx = min(x1,x2)
  let maxx = max(x1,x2)
  let miny = min(y1,y2)
  let maxy = max(y1,y2)

  circfill(minx + r, miny + r, r)
  circfill(maxx - r, miny + r, r)
  circfill(maxx - r, maxy - r, r)
  circfill(minx + r, maxy - r, r)

  rectfill(minx, miny + r, maxx, maxy - r)
  rectfill(minx + r, miny, maxx - r, miny + r)
  rectfill(minx + r, maxy - r, maxx - r, maxy)

proc box*(x,y,w,h: Pint) =
  hline(x,y,x+w-1)
  vline(x,y,y+h-1)
  vline(x+w-1,y,y+h-1)
  hline(x,y+h-1,x+w-1)

proc boxfill*(x,y,w,h: Pint) =
  if w == 0 or h == 0:
    return
  for y in y..<y+h:
    hline(x,y,x+w-1)

proc rbox*(x,y,w,h: Pint, r: Pint = 1) =
  rrect(x,y,x+w-1,y+h-1,r)

proc rboxfill*(x,y,w,h: Pint, r: Pint = 1) =
  rrectfill(x,y,x+w-1,y+h-1,r)

proc innerLineLow(x0,y0,x1,y1: int) =
  var dx = x1 - x0
  var dy = y1 - y0
  var yi = 1
  if dy < 0:
    yi = -1
    dy = -dy
  var D = 2*dy - dx
  var y = y0

  for x in x0..x1:
    pset(x,y)
    if D > 0:
      y = y + yi
      D = D - 2*dx
    D = D + 2*dy

proc innerLineHigh(x0,y0,x1,y1: int) =
  var dx = x1 - x0
  var dy = y1 - y0
  var xi = 1
  if dx < 0:
    xi = -1
    dx = -dx
  var D = 2*dx - dy
  var x = x0

  for y in y0..y1:
    pset(x,y)
    if D > 0:
      x = x + xi
      D = D - 2*dy
    D = D + 2*dx

proc innerLineClipped(x1,y1,x2,y2: int) =
  # TODO clipping
  # https://stackoverflow.com/questions/40884680/how-to-use-bresenhams-line-drawing-algorithm-with-clipping
  var x1 = x1
  var x2 = x2
  var y1 = y1
  var y2 = y2
  var signX = 1
  var signY = 1
  var clipMinX = clipMinX
  var clipMaxX = clipMaxX
  var clipMinY = clipMinY
  var clipMaxY = clipMaxY

  if x1 < x2:
    if x1 > clipMaxX or x2 < clipMinX:
      return
    signX = 1
  else:
    if x2 > clipMaxX or x1 < clipMinX:
      return
    signX = -1

    x1 = -x1
    x2 = -x2
    swap(clipMinX, clipMaxX)
    clipMinX = -clipMinX
    clipMaxX = -clipMaxX

  if y1 < y2:
    if y1 > clipMaxY or y2 < clipMinY:
      return
    signY = 1
  else:
    if y2 > clipMaxY or y1 < clipMinY:
      return
    signY = -1

    y1 = -y1
    y2 = -y2

    swap(clipMinY,clipMaxY)
    clipMinY = -clipMinY
    clipMaxY = -clipMaxY

  var delta_x = x2 - x1
  var delta_y = y2 - y1

  var delta_x_step = 2 * delta_x
  var delta_y_step = 2 * delta_y

  # Plotting values
  var x_pos = x1
  var y_pos = y1

  var set_exit = false

  var rem: int

  if delta_x >= delta_y:
    var error = delta_y_step - delta_x
    set_exit = false

    # Line starts below the clip window.
    if y1 < clipMinY:
      var temp = (2 * (clipMinY - y1) - 1) * delta_x
      var msd = temp div delta_y_step
      x_pos += msd

      # Line misses the clip window entirely.
      if x_pos > clipMaxX:
        return

      # Line starts.
      if x_pos >= clipMinX:
        rem = temp - msd * delta_y_step

        y_pos = clipMinY
        error -= rem + delta_x

        if rem > 0:
          x_pos += 1
          error += delta_y_step
        set_exit = true

        # Line starts left of the clip window.
        if not set_exit and x1 < clipMinX:
            temp = delta_y_step * (clipMinX - x1)
            msd = temp div delta_x_step
            y_pos += msd
            rem = temp mod delta_x_step

            # Line misses clip window entirely.
            if y_pos > clipMaxY or (y_pos == clipMaxY and rem >= delta_x):
                return

            x_pos = clipMinX
            error += rem

            if rem >= delta_x:
                y_pos += 1
                error -= delta_x_step

        var x_pos_end = x2

        if y2 > clipMaxY:
            temp = delta_x_step * (clipMaxY - y1) + delta_x
            msd = temp div delta_y_step
            x_pos_end = x1 + msd

            if (temp - msd * delta_y_step) == 0:
                x_pos_end -= 1

        x_pos_end = min(x_pos_end, clipMaxX) + 1
        if sign_y == -1:
            y_pos = -y_pos
        if sign_x == -1:
            x_pos = -x_pos
            x_pos_end = -x_pos_end
        delta_x_step -= delta_y_step

        while x_pos != x_pos_end:
            psetRaw(x_pos, y_pos)

            if error >= 0:
                y_pos += sign_y
                error -= delta_x_step
            else:
                error += delta_y_step

            x_pos += sign_x
    else:
        # Line is steep '/' (delta_x < delta_y).
        # Same as previous block of code with swapped x/y axis.

        error = delta_x_step - delta_y
        set_exit = false

        # Line starts left of the clip window.
        if x1 < clipMinX:
            var temp = (2 * (clipMinX - x1) - 1) * delta_y
            var msd = temp div delta_x_step
            y_pos += msd

            # Line misses the clip window entirely.
            if y_pos > clipMaxY:
                return

            # Line starts.
            if y_pos >= clipMinY:
                rem = temp - msd * delta_x_step

                x_pos = clipMinX
                error -= rem + delta_y

                if rem > 0:
                    y_pos += 1
                    error += delta_x_step
                set_exit = true

        # Line starts below the clip window.
        if not set_exit and y1 < clipMinY:
            var temp = delta_x_step * (clipMinY - y1)
            var msd = temp div delta_y_step
            x_pos += msd
            rem = temp mod delta_y_step

            # Line misses clip window entirely.
            if x_pos > clipMaxX or (x_pos == clipMaxX and rem >= delta_y):
                return

            y_pos = clipMinY
            error += rem

            if rem >= delta_y:
                x_pos += 1
                error -= delta_y_step

        var y_pos_end = y2

        if x2 > clipMaxX:
            var temp = delta_y_step * (clipMaxX - x1) + delta_y
            var msd = temp div delta_x_step
            y_pos_end = y1 + msd

            if (temp - msd * delta_x_step) == 0:
                y_pos_end -= 1

        y_pos_end = min(y_pos_end, clipMaxY) + 1
        if sign_x == -1:
            x_pos = -x_pos
        if sign_y == -1:
            y_pos = -y_pos
            y_pos_end = -y_pos_end
        delta_y_step -= delta_x_step

        while y_pos != y_pos_end:
            psetRaw(x_pos, y_pos)

            if error >= 0:
                x_pos += sign_x
                error -= delta_y_step
            else:
                error += delta_x_step

            y_pos += sign_y

proc innerLine*(x0,y0,x1,y1: Pint) =
  if abs(y1 - y0) < abs(x1 - x0):
    if x0 > x1:
      innerLineLow(x1,y1,x0,y0)
    else:
      innerLineLow(x0,y0,x1,y1)
  else:
    if y0 > y1:
      innerLineHigh(x1,y1,x0,y0)
    else:
      innerLineHigh(x0,y0,x1,y1)

proc line*(x0,y0,x1,y1: Pint) =
  if x0 == x1 and y0 == y1:
    pset(x0,y0)
  elif x0 == x1:
    vline(x0, y0, y1)
  elif y0 == y1:
    hline(x0, y0, x1)
  else:
    innerLine(x0,y0,x1,y1)

proc innerLineDashedLow(x0,y0,x1,y1: int, pattern: uint8) =
  var dx = x1 - x0
  var dy = y1 - y0
  var yi = 1
  if dy < 0:
    yi = -1
    dy = -dy
  var D = 2*dy - dx
  var y = y0

  var i = 0
  for x in x0..x1:
    if (pattern and (1 shl i).uint8) != 0:
      pset(x,y)
    i = (i + 1) mod 8
    if D > 0:
      y = y + yi
      D = D - 2*dx
    D = D + 2*dy

proc innerLineDashedHigh(x0,y0,x1,y1: int, pattern: uint8) =
  var dx = x1 - x0
  var dy = y1 - y0
  var xi = 1
  if dx < 0:
    xi = -1
    dx = -dx
  var D = 2*dx - dy
  var x = x0

  var i = 0
  for y in y0..y1:
    if (pattern and (1 shl i).uint8) != 0:
      pset(x,y)
    i = (i + 1) mod 8
    if D > 0:
      x = x + xi
      D = D - 2*dy
    D = D + 2*dx

proc innerLineDashed(x0,y0,x1,y1: int, pattern: uint8) =
  if abs(y1 - y0) < abs(x1 - x0):
    if x0 > x1:
      innerLineDashedLow(x1,y1,x0,y0,pattern)
    else:
      innerLineDashedLow(x0,y0,x1,y1,pattern)
  else:
    if y0 > y1:
      innerLineDashedHigh(x1,y1,x0,y0,pattern)
    else:
      innerLineDashedHigh(x0,y0,x1,y1,pattern)

proc hlineFast(x0,y,x1: Pint) =
  if y < clipMinY or y > clipMaxY:
    return
  for x in max(x0,clipMinX)..min(x1,clipMaxX):
    psetRaw(x,y,currentColor)

proc hline*(x0,y,x1: Pint) =
  let minX = clipMinX + cameraX
  let maxX = clipMaxX + cameraX
  if x0 < minX and x1 < minX:
    return
  if x0 > maxX and x1 > maxX:
    return
  var x0 = x0
  var x1 = x1
  if x1<x0:
    swap(x1,x0)
  x0 = max(x0, minX)
  x1 = min(x1, maxX)
  for x in x0..x1:
    pset(x,y)

proc vline*(x,y0,y1: Pint) =
  let minY = clipMinY + cameraY
  let maxY = clipMaxY + cameraY
  if y0 < minY and y1 < minY:
    return
  if y0 > maxY and y1 > maxY:
    return
  var y0 = y0
  var y1 = y1
  if y1<y0:
    swap(y1,y0)
  y0 = max(y0, minY)
  y1 = min(y1, maxY)
  for y in y0..y1:
    pset(x,y)

proc hlineDashed*(x0,y,x1: Pint, pattern: uint8 = 0b10101010) =
  var x0 = x0
  var x1 = x1
  var i = 0
  if x1<x0:
    swap(x1,x0)
  for x in x0..x1:
    if (pattern and (1 shl i).uint8) != 0:
      pset(x,y)
    i = (i + 1) mod 8

proc vlineDashed*(x,y0,y1: Pint, pattern: uint8 = 0b10101010) =
  var y0 = y0
  var y1 = y1
  var i = 0
  if y1<y0:
    swap(y1,y0)
  for y in y0..y1:
    if (pattern and (1 shl i).uint8) != 0:
      pset(x,y)
    i = (i + 1) mod 8

proc lineDashed*(x0,y0,x1,y1: Pint, pattern: uint8 = 0b10101010) =
  if x0 == x1 and y0 == y1:
    pset(x0,y0)
  elif x0 == x1:
    vlineDashed(x0, y0, y1, pattern)
  elif y0 == y1:
    hlineDashed(x0, y0, x1, pattern)
  else:
    innerLineDashed(x0,y0,x1,y1, pattern)

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

proc rrect*(x1,y1,x2,y2: Pint, r: Pint = 1) =
#  https://www.freebasic.net/forum/viewtopic.php?t=19874
#  Sub drawRoundedRectangle(x0 As Integer, y0 As Integer, x1 As Integer, y1 As Integer, radius As Integer, col As UInteger = RGB(255,255,255))
#   Dim f As Integer
#   Dim ddF_x As Integer
#   Dim ddF_y As Integer
#   Dim xx As Integer
#   Dim yy As Integer
#
#   f = 1 - radius
#   ddF_x = 1
#   ddF_y = -2 * radius
#   xx = 0
#   yy = radius
#
#   While xx < yy
#      If (f >= 0) Then
#         yy-=1
#         ddF_y += 2
#         f += ddF_y
#      EndIf
#      xx+=1
#      ddF_x += 2
#      f += ddF_x
#      PSet (x1 + xx - radius, y1 + yy - radius), col ''Bottom Right Corner
#      PSet (x1 + yy - radius, y1 + xx - radius), col ''^^^

#      PSet (x0 - xx + radius, y1 + yy - radius), col ''Bottom Left Corner
#      PSet (x0 - yy + radius, y1 + xx - radius), col ''^^^

#      PSet (x1 + xx - radius, y0 - yy + radius), col ''Top Right Corner
#      PSet (x1 + yy - radius, y0 - xx + radius), col ''^^^

#      PSet (x0 - xx + radius, y0 - yy + radius), col ''Top Left Corner
#      PSet (x0 - yy + radius, y0 - xx + radius), col ''^^^
#   Wend
#   Line (x0 + radius,        y0)-(x1 - radius,        y0), col ''top side
#   Line (x0 + radius,        y1)-(x1 - radius,        y1), col ''botom side
#   Line (x0         , y0+radius)-(x0         , y1-radius), col ''left side
#   Line (x1         , y0+radius)-(x1         , y1-radius), col ''right side
#End Sub
  let minx = min(x1,x2)
  let maxx = max(x1,x2)
  let miny = min(y1,y2)
  let maxy = max(y1,y2)

  var f = 1 - r
  var dfx = 1
  var dfy = -2 * r
  var xx = 0
  var yy = r

  while xx < yy:
    if f >= 0:
      yy -= 1
      dfy += 2
      f += dfy

    xx += 1
    dfx += 2
    f += dfx

    pset(maxx + xx - r, maxy + yy - r)
    pset(maxx + yy - r, maxy + xx - r)

    pset(minx - xx + r, maxy + yy - r)
    pset(minx - yy + r, maxy + xx - r)

    pset(maxx + xx - r, miny - yy + r)
    pset(maxx + yy - r, miny - xx + r)

    pset(minx - xx + r, miny - yy + r)
    pset(minx - yy + r, miny - xx + r)

  hline(minx + r, miny, maxx - r)
  hline(minx + r, maxy, maxx - r)

  vline(minx, miny + r, maxy - r)
  vline(maxx, miny + r, maxy - r)

proc rectCorner*(x1,y1,x2,y2: Pint) =
  let w = x2-x1
  let h = y2-y1
  let x = x1
  let y = y1
  # top left
  pset(x, y)
  pset(x+1, y)
  pset(x, y+1)
  # top right
  pset(x2, y)
  pset(x2-1, y)
  pset(x2, y+1)
  # bottom left
  pset(x1, y2)
  pset(x1+1, y2)
  pset(x1, y2-1)
  # bottom right
  pset(x2, y2)
  pset(x2-1, y2)
  pset(x2, y2-1)

proc rrectCorner*(x1,y1,x2,y2: Pint) =
  let w = x2-x1
  let h = y2-y1
  let x = x1
  let y = y1
  # top left
  pset(x+1, y)
  pset(x, y+1)
  # top right
  pset(x2-1, y)
  pset(x2, y+1)
  # bottom left
  pset(x1+1, y2)
  pset(x1, y2-1)
  # bottom right
  pset(x2-1, y2)
  pset(x2, y2-1)

proc flr*(x: Pfloat): Pfloat =
  return x.floor()

proc lerp[T](a, b: T, t: Pfloat): T =
  return a + (b - a) * t

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

proc orient2d(ax,ay,bx,by,cx,cy: Pint): int =
  return (bx - ax) * (cy - ay) - (by - ay) * (cx-ax)

proc trifill*(ax,ay,bx,by,cx,cy: Pint) =
  let ax = ax - cameraX
  let bx = bx - cameraX
  let cx = cx - cameraX
  let ay = ay - cameraY
  let by = by - cameraY
  let cy = cy - cameraY

  let minX = max(min(min(ax, bx), cx), clipMinX)
  let minY = max(min(min(ay, by), cy), clipMinY)
  let maxX = min(max(max(ax, bx), cx), clipMaxX)
  let maxY = min(max(max(ay, by), cy), clipMaxY)

  let
    A01 = ay - by
    B01 = bx - ax
    A12 = by - cy
    B12 = cx - bx
    A20 = cy - ay
    B20 = ax - cx

  var w0_row = orient2d(bx,by,cx,cy,minx,miny)
  var w1_row = orient2d(cx,cy,ax,ay,minx,miny)
  var w2_row = orient2d(ax,ay,bx,by,minx,miny)

  for py in minY..maxY:
    var w0 = w0_row
    var w1 = w1_row
    var w2 = w2_row

    for px in minX..maxX:
      if w0 >= 0 and w1 >= 0 and w2 >= 0:
        psetRaw(px,py)
      w0 += A12
      w1 += A20
      w2 += A01

    w0_row += B12
    w1_row += B20
    w2_row += B01

proc quadfill*(x1,y1,x2,y2,x3,y3,x4,y4: Pint) =
  trifill(x1,y1,x2,y2,x3,y3)
  trifill(x1,y1,x3,y3,x4,y4)

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
        swCanvas.data[dy * swCanvas.w + dx] = currentColor.uint8
      elif ditherColor >= 0:
        swCanvas.data[dy * swCanvas.w + dx] = ditherColor.uint8

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
      elif ditherColor >= 0:
        swCanvas.data[dyi * swCanvas.w + dxi] = ditherColor.uint8
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

  let srcw = spritesheet.w
  let srch = spritesheet.w

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
        let srcCol = spritesheet.data[syi * srcw + sxi]
        swCanvas.data[dyi * swCanvas.w + dxi] = srcCol
      elif ditherColor >= 0:
        swCanvas.data[dyi * swCanvas.w + dxi] = ditherColor.uint8

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
          swCanvas.data[dyi * swCanvas.w + dxi] = paletteMapDraw[srcCol].uint8
      elif ditherColor >= 0:
        swCanvas.data[dyi * swCanvas.w + dxi] = ditherColor.uint8

      sxi += 1
      dxi += 1
    syi += 1
    dyi += 1
    sxi = sx
    dxi = dx

proc blitFastRot(src: Surface, srcRect: Rect, centerX, centerY: Pint, radians: float32) =
  # no stretch or flipping, but allows rotation
  # uses RSamp algorithm, contributed by avahe-kellenberger
  # http://www.leptonica.org/rotation.html

  let cosRadians = cos(radians)
  let sinRadians = sin(radians)

  let srcCenterX = (srcRect.w - 1).float32 / 2f
  let srcCenterY = (srcRect.h - 1).float32 / 2f

  # calculate bounds
  let sminx = -srcCenterX
  let smaxx = srcCenterX
  let sminy = -srcCenterY
  let smaxy = srcCenterY

  let AX = cosRadians * sminx + sinRadians * sminy + srcCenterX
  let AY = cosRadians * sminy - sinRadians * sminx + srcCenterY

  let BX = cosRadians * smaxx + sinRadians * sminy + srcCenterX
  let BY = cosRadians * sminy - sinRadians * smaxx + srcCenterY

  let CX = cosRadians * smaxx + sinRadians * smaxy + srcCenterX
  let CY = cosRadians * smaxy - sinRadians * smaxx + srcCenterY

  let DX = cosRadians * sminx + sinRadians * smaxy + srcCenterX
  let DY = cosRadians * smaxy - sinRadians * sminx + srcCenterY

  let minx = min(AX,min(BX,min(CX,DX)))
  let miny = min(AY,min(BY,min(CY,DY)))
  let maxx = max(AX,max(BX,max(CX,DX)))
  let maxy = max(AY,max(BY,max(CY,DY)))

  let dstW = maxx - minx
  let dstH = maxy - miny

  let dstCenterX = (dstW - 1).float32 / 2f
  let dstCenterY = (dstH - 1).float32 / 2f

  for y in 0..<dstH:
    for x in 0..<dstW:
      let dx = (centerX - dstCenterX) + x - cameraX
      let dy = (centerY - dstCenterY) + y - cameraY

      # check dest pixel is in bounds
      if dx < clipMinX or dy < clipMinY or dx > clipMaxX or dy > clipMaxY:
        continue

      let dstIndex = dy * swCanvas.w + dx

      let
        rx = x.float32 - dstCenterX
        ry = y.float32 - dstCenterY
        rsx = round(cosRadians * rx + sinRadians * ry + srcCenterX).int
        rsy = round(cosRadians * ry - sinRadians * rx + srcCenterY).int
      # check source pixel is in bounds
      if rsx < 0 or rsy < 0 or rsx >= srcRect.w or rsy >= srcRect.h:
        continue

      let
        sx = srcRect.x + rsx
        sy = srcRect.y + rsy

      if ditherPass(dx,dy):
        let srcCol = src.data[sy * src.w + sx]
        if not paletteTransparent[srcCol]:
          swCanvas.data[dstIndex] = paletteMapDraw[srcCol].uint8
      elif ditherColor >= 0:
        swCanvas.data[dstIndex] = ditherColor.uint8

proc blitFastRot90(src: Surface, srcRect: Rect, dx, dy: Pint, rotations: int) =
  # no stretch or flipping, but allows 90,180,270 degree rotation
  # uses RSamp algorithm, contributed by avahe-kellenberger
  # http://www.leptonica.org/rotation.html

  let rotations: range[0..3] = floorMod(rotations, 4)

  let dstW = if rotations mod 2 == 0: srcRect.w else: srcRect.h
  let dstH = if rotations mod 2 == 0: srcRect.h else: srcRect.w

  for y in 0..<dstH:
    for x in 0..<dstW:

      let dxi = dx + x - cameraX
      let dyi = dy + y - cameraY

      # check dest pixel is in bounds
      if dxi < clipMinX or dyi < clipMinY or dxi > clipMaxX or dyi > clipMaxY:
        continue

      let dstIndex = dyi * swCanvas.w + dxi

      var sx: int
      var sy: int

      case rotations:
      of 0: # orig
        sx = x
        sy = y
      of 1: # 90 clockwise
        sx = y
        sy = dstW - 1 - x
      of 2: # 180 clockwise
        sx = dstW - 1 - x
        sy = dstH - 1 - y
      of 3: # 270 clockwise
        sx = dstH - 1 - y
        sy = x

      if ditherPass(dx,dy):
        let srcCol = src.data[(srcRect.y + sy) * src.w + (srcRect.x + sx)]
        if not paletteTransparent[srcCol]:
          swCanvas.data[dstIndex] = paletteMapDraw[srcCol].uint8
      elif ditherColor >= 0:
        swCanvas.data[dstIndex] = ditherColor.uint8

proc blitFastFlip(src: Surface, sx,sy, dx,dy, w,h: Pint, hflip, vflip: bool) =
  # used for tile drawing, no stretch
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
          swCanvas.data[dyi * swCanvas.w + dxi] = paletteMapDraw[srcCol].uint8
      elif ditherColor >= 0:
        swCanvas.data[dyi * swCanvas.w + dxi] = ditherColor.uint8

      sxi += xi
      dxi += 1
    syi += yi
    dyi += 1
    sxi = startsx
    dxi = dx

proc blitFastFlipShift(src: Surface, sx,sy, dx,dy, w,h: Pint, ox,oy: Pint, hflip, vflip: bool) =
  # used for tile drawing, no stretch, but with flipping and shifting
  let startsx = sx + (if hflip: w - 1 else: 0)
  var sxi = 0
  let startsy = sy + (if vflip: h - 1 else: 0)
  var syi = 0
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
        let srcCol = src.data[(startsy + wrap(syi + oy, h)) * src.w + (startsx + wrap(sxi + ox, w))]
        if not paletteTransparent[srcCol]:
          swCanvas.data[dyi * swCanvas.w + dxi] = paletteMapDraw[srcCol].uint8
      elif ditherColor >= 0:
        swCanvas.data[dyi * swCanvas.w + dxi] = ditherColor.uint8

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
            swCanvas.data[dy.int * swCanvas.w + dx.int] = paletteMapDraw[srcCol].uint8
        elif ditherColor >= 0:
          swCanvas.data[dy.int * swCanvas.w + dx.int] = paletteMapDraw[ditherColor.ColorId].uint8

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
          swCanvas.data[dy * swCanvas.w + dx] = paletteMapDraw[srcCol].uint8
        elif ditherColor >= 0:
          swCanvas.data[dy * swCanvas.w + dx] = paletteMapDraw[ditherColor.ColorId].uint8

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
{.pop.}

proc mset*(tx,ty: Pint, t: uint8) =
  if currentTilemap == nil:
    raise newException(Exception, "No map set")
  if tx < 0 or tx > currentTilemap.w - 1 or ty < 0 or ty > currentTilemap.h - 1:
    return
  currentTilemap[].data[ty * currentTilemap.w + tx] = t

proc mget*(tx,ty: Pint): uint8 =
  if currentTilemap == nil:
    raise newException(Exception, "No map set")
  if tx < 0 or tx > currentTilemap.w - 1 or ty < 0 or ty > currentTilemap.h - 1:
    return 0.uint8
  return currentTilemap[].data[ty * currentTilemap.w + tx]

iterator mapAdjacent*(tx,ty: Pint): (Pint,Pint) =
  for y in 0..<currentTilemap.h:
    for x in 0..<currentTilemap.w:
      if x > 0:
        yield ((x-1).Pint,y.Pint)
      if x < currentTilemap.w - 1:
        yield ((x+1).Pint,y.Pint)
      if y > 0:
        yield (x.Pint,(y-1).Pint)
      if y < currentTilemap.h - 1:
        yield (x.Pint,(y+1).Pint)

proc fget*(s: Pint): uint8 =
  return spritesheet.spriteFlags[s]

proc fget*(s: Pint, f: uint8): bool =
  return spritesheet.spriteFlags[s].contains(f)

proc fset*(s: Pint, f: uint8) =
  spritesheet.spriteFlags[s] = f

proc fset*(s: Pint, f: uint8, v: bool) =
  if v:
    spritesheet.spriteFlags[s].set(f)
  else:
    spritesheet.spriteFlags[s].unset(f)

proc masterVol*(newVol: int) =
  echo "setting masterVol: ", newVol
  masterVolume = clamp(newVol.float32 / 255.0'f, 0'f, 1'f)

proc masterVol*(): int =
  return (masterVolume * 255.0'f).int

proc sfxVol*(newVol: int) =
  sfxVolume = clamp(newVol.float32 / 255.0'f, 0'f, 1'f)

proc sfxVol*(): int =
  return (sfxVolume * 255.0'f).int

proc musicVol*(newVol: int) =
  musicVolume = clamp(newVol.float32 / 255.0'f, 0'f, 1'f)

proc musicVol*(): int =
  return (musicVolume * 255.0'f).int

proc createFontFromSurface(surface: Surface, chars: string): Font =
  var font = new(Font)

  font.w = surface.w
  font.h = surface.h
  font.data = newSeq[uint8](font.w*font.h)

  let borderColor = 2.uint8
  let solidColor = 1.uint8
  let transparentColor = 0.uint8

  if surface.channels == 4:
    debug "loading font from RGBA", surface.filename, "chars", chars.runeLen
    let borderColorRGBA = (surface.data[0],surface.data[1],surface.data[2],surface.data[3])
    let transparentColorRGBA = (surface.data[4],surface.data[5],surface.data[6],surface.data[7])

    for i in 0..<font.w*font.h:
      var col = (
        surface.data[i*surface.channels+0],
        surface.data[i*surface.channels+1],
        surface.data[i*surface.channels+2],
        surface.data[i*surface.channels+3]
      )
      if col[3] == 0:
        font.data[i] = transparentColor
      elif col[0] > 127:
        font.data[i] = borderColor
      else:
        font.data[i] = solidColor

  elif surface.channels == 1:
    debug "loading font from indexed", surface.filename
    for i in 0..<font.w*font.h:
      font.data[i] = surface.data[i]

  font.rects = initTable[Rune,Rect](128)

  var newChar = false
  var currentRect: Rect = (0,0,0,0)
  var i = 0
  var charPos = 0
  # scan across the top of the font image
  for x in 0..<font.w:
    let color = font.data[x]
    if color == borderColor:
      currentRect.w = x - currentRect.x
      if currentRect.w != 0:
        # go down until we find border or h
        currentRect.h = font.h-1
        for y in 0..<font.h:
          let color = font.data[y*font.w+x]
          if color == borderColor:
            currentRect.h = y
        var charId: Rune
        chars.fastRuneAt(charPos, charId, true)
        if font.rects.hasKey(charId):
          raise newException(Exception, "font already has character: " & $charId & " index: " & $i)
        font.rects[charId] = currentRect
        i += 1
      newChar = true
      currentRect.x = x + 1

  echo "loaded font with ", font.rects.len, " chars"

  if font.rects.len != chars.runeLen:
    raise newException(Exception, "didn't load all characters from font, loaded: " & $font.rects.len & " bitmaps of specified chars " & $chars.runeLen)

  return font

import nico/fontdata

proc loadDefaultFont*(index: int) =
  let shouldReplace = currentFont == fonts[index]
  fonts[index] = createFontFromSurface(defaultFontSurface, defaultFontChars)
  if shouldReplace:
    debug "updating current font ", index
    setFont(index)

proc loadFont*(index: int, filename: string) =
  let shouldReplace = currentFont == fonts[index]
  var chars: string
  var datPath: string
  try:
    datPath = joinPath(assetPath, filename & ".dat")
    chars = backend.readFile(datPath)
  except IOError:
    raise newException(Exception, "Missing " & datPath & " needed if not passing chars to loadFont")
  chars.removeSuffix()
  backend.loadSurfaceRGBA(joinPath(assetPath,filename)) do(surface: Surface):
    fonts[index] = createFontFromSurface(surface, chars)
    if shouldReplace:
      debug "updating current font ", index
      setFont(index)

proc loadFont*(index: int, filename: string, chars: string) =
  let shouldReplace = currentFont == fonts[index]
  backend.loadSurfaceRGBA(joinPath(assetPath,filename)) do(surface: Surface):
    fonts[index] = createFontFromSurface(surface, chars)
  if shouldReplace:
    setFont(index)

proc glyph*(c: Rune, x,y: Pint, scale: Pint = 1): Pint =
  if currentFont == nil:
    raise newException(Exception, "No font selected")
  if not currentFont.rects.hasKey(c):
    return
  let src: Rect = currentFont.rects[c]
  let dst: Rect = (x.int, y.int, src.w * scale, src.h * scale)
  try:
    fontBlit(currentFont, src, dst, currentColor)
  except IndexError:
    debug "index error glyph: ", c, " @ ", x, ",", y
    raise
  return src.w * scale + scale

proc glyph*(c: char, x,y: Pint, scale: Pint = 1): Pint =
  return glyph(c.Rune, x, y, scale)

proc fontHeight*(): Pint =
  if currentFont == nil:
    return 0
  return currentFont.rects[Rune(' ')].h

proc print*(text: string, x,y: Pint, scale: Pint = 1) =
  if currentFont == nil:
    raise newException(Exception, "No font selected")
  var x = x - cameraX
  var y = y - cameraY
  let ix = x
  for line in text.splitLines:
    for c in line.runes:
      x += glyph(c, x, y, scale)
    x = ix
    y += currentFont.h

proc print*(text: string) =
  if currentFont == nil:
    raise newException(Exception, "No font selected")
  var x = cursorX - cameraX
  let y = cursorY - cameraY
  for c in text.runes:
    x += glyph(c, x, y, 1)
  cursorY += 6

proc glyphWidth*(c: Rune, scale: Pint = 1): Pint =
  if currentFont == nil:
    raise newException(Exception, "No font selected")
  if not currentFont.rects.hasKey(c):
    return 0
  result = currentFont.rects[c].w*scale + scale

proc glyphWidth*(c: char, scale: Pint = 1): Pint =
  glyphWidth(c.Rune)

proc textWidth*(text: string, scale: Pint = 1): Pint =
  if currentFont == nil:
    raise newException(Exception, "No font selected")
  for c in text.runes:
    if not currentFont.rects.hasKey(c):
      raise newException(Exception, "character not in font: '" & $c & "'")
    result += currentFont.rects[c].w*scale + scale

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

proc mouserel*(): (float32,float32) =
  return (mouseRelX,mouseRelY)

proc useRelativeMouse*(on: bool) =
  when not defined(js):
    backend.useRelativeMouse(on)

proc mousebtn*(b: range[0..2]): bool =
  return mouseButtons[b] > 0

proc mousebtnp*(b: range[0..2]): bool =
  return mouseButtons[b] == 1

proc mousebtnup*(b: range[0..2]): bool =
  return mouseButtons[b] == -1

proc mousebtnpr*(b: range[0..2], r: Pint): bool =
  return mouseButtons[b] > 0 and mouseButtons[b] mod r == 1

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

proc resize() =
  backend.resize()
  clip()
  cls()
  present()

proc addResizeFunc*(newResizeFunc: ResizeFunc) =
  resizeFuncs.add(newResizeFunc)

proc removeResizeFunc*(resizeFunc: ResizeFunc) =
  let i = resizeFuncs.find(resizeFunc)
  resizeFuncs.del(i)

proc setTargetSize*(w,h: int) =
  if targetScreenWidth == w and targetScreenHeight == h:
    return
  targetScreenWidth = w
  targetScreenHeight = h
  resize()

proc fixedSize*(): bool =
  return fixedScreenSize

proc fixedSize*(enabled: bool) =
  fixedScreenSize = enabled
  if backend.isWindowCreated():
    resize()

proc getScreenScale*(): float32 =
  return common.screenScale

proc integerScale*(): bool =
  return integerScreenScale

proc integerScale*(enabled: bool) =
  integerScreenScale = enabled
  if backend.isWindowCreated():
    resize()

proc newSpritesheet*(index: int, w, h: int, tw,th = 8) =
  if index < 0 or index >= spritesheets.len:
    raise newException(Exception, "Invalid spritesheet " & $index)
  spritesheets[index] = newSurface(w, h)
  spritesheets[index].tw = tw
  spritesheets[index].th = th
  spritesheets[index].filename = ""

proc setSpritesheet*(index: int) =
  if index < 0 or index >= spritesheets.len:
    raise newException(Exception, "Invalid spritesheet " & $index)

  if spritesheets[index] == nil:
    raise newException(Exception, "No spritesheet loaded: " & $index)
  spritesheet = spritesheets[index]

proc loadSpriteSheet*(index: int, filename: string, tileWidth,tileHeight: Pint = 8) =
  if index < 0 or index >= spritesheets.len:
    raise newException(Exception, "Invalid spritesheet " & $index)
  let shouldReplace = spritesheet == spritesheets[index]
  backend.loadSurfaceIndexed(joinPath(assetPath,filename)) do(surface: Surface) {.nosinks.}:
    echo "loaded spritesheet: ", filename, " ", surface.w, "x", surface.h, " tile:", tileWidth, "x", tileHeight
    if surface.w mod tileWidth != 0 or surface.h mod tileHeight != 0:
      raise newException(Exception, "Spritesheet size must be divisible by tile size: " & $tileWidth & "x" & $tileHeight)
    let numTiles = (surface.w div tileWidth) * (surface.h div tileHeight)
    spritesheets[index] = surface
    spritesheets[index].tw = tileWidth
    spritesheets[index].th = tileHeight
    spritesheets[index].filename = filename
    spritesheets[index].spriteFlags = newSeq[uint8](numTiles)
    if shouldReplace:
      setSpritesheet(index)

proc spriteSize*(): (int,int) =
  return (spritesheet.tw, spritesheet.th)

proc getSprRect(spr: Pint, w,h: Pint = 1): Rect {.inline.} =
  assert(spritesheet != nil)
  assert(spritesheet.tw > 0)
  assert(spritesheet.th > 0)
  let tilesX = spritesheet.w div spritesheet.tw
  result.x = spr mod tilesX * spritesheet.tw
  result.y = spr div tilesX * spritesheet.th
  result.w = w * spritesheet.tw
  result.h = h * spritesheet.th

proc spr*(spr: Pint, x,y: Pint, w,h: Pint = 1, hflip, vflip: bool = false) =
  if spritesheet.tw == 0 or spritesheet.th == 0:
    return
  # draw a sprite
  var src = getSprRect(spr, w, h)
  if hflip or vflip:
    blitFastFlip(spritesheet, src.x, src.y, x-cameraX, y-cameraY, src.w, src.h, hflip, vflip)
  else:
    blitFast(spritesheet, src.x, src.y, x-cameraX, y-cameraY, src.w, src.h)

proc sprshift*(spr: Pint, x,y: Pint, w,h: Pint = 1, ox,oy: Pint = 0, hflip, vflip: bool = false) =
  if spritesheet.tw == 0 or spritesheet.th == 0:
    return
  # draw a sprite
  let src = getSprRect(spr, w, h)
  if hflip or vflip:
    blitFastFlipShift(spritesheet, src.x, src.y, x-cameraX, y-cameraY, src.w, src.h, ox, oy, hflip, vflip)
  else:
    blitFastFlipShift(spritesheet, src.x, src.y, x-cameraX, y-cameraY, src.w, src.h, ox, oy, false, false)

proc sprRot*(spr: Pint, x,y: Pint, radians: float32, w,h: Pint = 1) =
  let src = getSprRect(spr, w, h)
  blitFastRot(spritesheet, src, x, y, radians)

proc sprRot90*(spr: Pint, x,y: Pint, rotations: int, w,h: Pint = 1) =
  let src = getSprRect(spr, w, h)
  blitFastRot90(spritesheet, src, x, y, rotations)

proc sprBlit*(spr: Pint, x,y: Pint, w,h: Pint = 1) =
  # draw a sprite
  let src = getSprRect(spr, w, h)
  let dst: Rect = ((x-cameraX).int,(y-cameraY).int,src.w,src.h)
  blit(spritesheet, src, dst)

proc sprBlitFast*(spr: Pint, x,y: Pint, w,h: Pint = 1) =
  # draw a sprite
  let src = getSprRect(spr, w, h)
  blitFast(spritesheet, src.x, src.y, x-cameraX, y-cameraY, src.w, src.h)

proc sprBlitFastRaw*(spr: Pint, x,y: Pint, w,h: Pint = 1) =
  # draw a sprite
  let src = getSprRect(spr, w, h)
  blitFastRaw(spritesheet, src.x, src.y, x-cameraX, y-cameraY, src.w, src.h)

proc sprBlitStretch*(spr: Pint, x,y: Pint, w,h: Pint = 1) =
  # draw a sprite
  let src = getSprRect(spr, w, h)
  let dst: Rect = ((x-cameraX).int,(y-cameraY).int,src.w,src.h)
  blitStretch(spritesheet, src, dst)

proc spr*(drawer: SpriteDraw)=
  setSpritesheet(drawer.spriteSheet)
  spr(drawer.spriteIndex, drawer.x, drawer.y, drawer.w, drawer.h, drawer.flipX, drawer.flipY)

proc spr*(drawer: SpriteDraw, x,y:Pint)=
  setSpritesheet(drawer.spriteSheet)
  spr(drawer.spriteIndex, x, y, drawer.w, drawer.h, drawer.flipX, drawer.flipY)

proc sprOverlap*(a,b : SpriteDraw): bool=
  ##Will return true if the sprites overlap
  setSpritesheet(a.spriteSheet)
  let
    aSprRect = getSprRect(a.spriteIndex,a.w,a.h)
    aRect: Rect = (a.x, a.y, aSprRect.w, aSprRect.h)

  if(a.spritesheet != b.spritesheet): setSpritesheet(b.spriteSheet)
  let
    bSprRect = getSprRect(b.spriteIndex,b.w,b.h)
    bRect: Rect = (b.x, b.y, bSprRect.w, bSprRect.h)

  if(overlap(aRect,bRect)):
    let
      xOverlap = max(aRect.x, bRect.x)
      yOverlap = max(aRect.y, bRect.y)
      wOverlap = min(aRect.x + aRect.w, bRect.x + bRect.w) - xOverlap
      hOverlap = min(aRect.y + aRect.h, bRect.y + bRect.h) - yOverlap
      aXRelative = xOverlap - a.x
      aYRelative = yOverlap - a.y
      bXRelative = xOverlap - b.x
      bYRelative = yOverlap - b.y

    var
      surfA = spritesheets[a.spriteSheet]
      surfB = spritesheets[b.spriteSheet]
      indA = 0
      indB = 0

    #Foreach pixel in the overlap check the colour there
    for xSamp in 0..<wOverlap:
      for ySamp in 0..<hOverlap:
        var
          aX = aSprRect.x + xSamp + aXRelative
          aY = aSprRect.y + ySamp + aYRelative
          bX = bSprRect.x + xSamp + bxRelative
          bY = bSprRect.y + ySamp + bYRelative

        #Logic to flip the coord samples for generating an index
        #Subtract 1 cause of size being 1 with 1 pixel not 0
        if(a.flipX):
          aX = aSprRect.x + (aSprRect.w - (xSamp + aXRelative)) - 1
        if(a.flipY):
          aY = aSprRect.y + (aSprRect.h - (ySamp + aYRelative)) - 1

        if(b.flipX):
          bX = bSprRect.x + (aSprRect.w - (xSamp + bXRelative)) - 1
        if(b.flipY):
          bY = bSprRect.y + (aSprRect.h - (ySamp + bYRelative)) - 1


        indA = aX + aY * surfA.w
        indB = bX + bY * surfB.w
        if(indA < surfA.data.len and indB < surfB.data.len):#Shouldnt ever happen but errors must be checked
          if(surfA.data[indA] > 0 and surfB.data[indB] > 0): #Using 0 as of now for alpha check
            return true

  return false


proc sprs*(spr: Pint, x,y: Pint, w,h: Pint = 1, dw,dh: Pint = 1, hflip, vflip: bool = false) =
  # draw an integer scaled sprite
  var src = getSprRect(spr, w, h)
  var dst: Rect = ((x-cameraX).int,(y-cameraY).int,(dw*8).int,(dh*8).int)
  blitStretch(spritesheet, src, dst, hflip, vflip)

proc sprss*(spr: Pint, x,y: Pint, w,h: Pint = 1, dw,dh: Pint, hflip, vflip: bool = false) =
  # draw a scaled sprite
  var src = getSprRect(spr, w, h)
  var dst: Rect = ((x-cameraX).int,(y-cameraY).int,dw.int,dh.int)
  blit(spritesheet, src, dst, hflip, vflip)

proc drawTile(spr: uint8, x,y: Pint) =
  var src = getSprRect(spr.Pint)
  if overlap(clippingRect,(x.int,y.int, spritesheet.tw, spritesheet.th)):
    blitFast(spritesheet, src.x, src.y, x, y, spritesheet.tw, spritesheet.th)

proc sspr*(sx,sy, sw,sh, dx,dy: Pint, dw,dh: Pint = -1, hflip, vflip: bool = false) =
  var src: Rect = (sx.int,sy.int,sw.int,sh.int)
  let dw = if dw >= 0: dw else: sw
  let dh = if dh >= 0: dh else: sh
  var dst: Rect = ((dx-cameraX).int,(dy-cameraY).int,dw.int,dh.int)
  blitStretch(spritesheet, src, dst, hflip, vflip)

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

proc mapDrawHex(tx,ty, tw,th, dx,dy: Pint) =
  ## tx,ty = top left tilemap coordinates to draw from
  ## tw,th = how many tiles to draw across and down
  ## dx,dy = position on virtual screen to draw at

  # draw map tiles to the screen
  let yincrement = currentTilemap.hexOffset
  let xincrement = currentTilemap.tw

  let drawWidth = clipMaxX - clipMinX
  let drawHeight = clipMaxY - clipMinY

  let startCol = max(tx, (cameraX + clipMinX) div xincrement)
  let startRow = max(ty, (cameraY + clipMinY) div yincrement)
  let endCol = min(startCol + ((drawWidth + xincrement - 1) div xincrement), tx + tw - 1)
  let endRow = min(startRow + ((drawHeight + yincrement - 1) div yincrement), ty + th - 1)
  let offsetX = dx
  let offsetY = dy

  for y in startRow..endRow:
    if y < 0 or y >= currentTilemap.h:
      continue
    for x in startCol..endCol:
      if x < 0 or x >= currentTilemap.w:
        continue
      let t = currentTilemap.data[y * currentTilemap.w + x]
      let px = x * xincrement - (if y mod 2 == 0: xincrement div 2 else : 0)
      let py = y * yincrement
      if t != 0:
        drawTile(t, px - cameraX, py - cameraY)

var mapFilterFlags: uint8 = 0'u8

proc mapFilter*(flags: uint8 = 0'u8) =
  ## set the sprite flag filter for map drawing
  mapFilterFlags = flags

proc mapFilter*(flag: range[0..7], on: bool) =
  ## set the sprite flag filter for map drawing
  if on:
    mapFilterFlags.set(flag.uint8)
  else:
    mapFilterFlags.unset(flag.uint8)

proc mapDraw*(tx,ty, tw,th, dx,dy: Pint, dw,dh: Pint = -1, loop: bool = false, ox,oy: Pint = 0) =
  ## tx,ty = top left tilemap coordinates to draw from
  ## tw,th = how many tiles to draw across and down
  ## dx,dy = position on virtual screen to draw at
  ## dw,dh = draw width, draw height, -1 = as big as map
  ## ox,oy = offset drawing position, useful for parallax

  if currentTilemap == nil:
    raise newException(Exception, "No map set")

  if currentTilemap.hex:
    mapDrawHex(tx,ty,tw,th,dx,dy)
    return

  # draw map tiles to the screen
  let yincrement = currentTilemap.th
  let xincrement = currentTilemap.tw

  let dx = dx - cameraX
  let dy = dy - cameraY

  var dw = dw
  var dh = dh

  if dw == -1:
    dw = tw * currentTilemap.tw
  if dh == -1:
    dh = th * currentTilemap.th

  var dminx = dx
  var dminy = dy
  var dmaxx = dx + dw - 1
  var dmaxy = dy + dh - 1

  # clip these bounds
  dminx = max(dminx, clipMinX)
  dmaxx = min(dmaxx, clipMaxX)
  dminy = max(dminy, clipMinY)
  dmaxy = min(dmaxy, clipMaxY)

  dw = min(dw, dmaxx - dminx)
  dh = min(dh, dmaxy - dminy)

  let offsetX = dminx - dx - ox
  let offsetY = dminy - dy - oy

  # the first row,col we draw might not be the one specified as it might be offscreen
  var startCol = (offsetX - xincrement + 1) div xincrement
  var startRow = (offsetY - yincrement + 1) div yincrement
  if not loop:
    startCol = max(0, startCol)
    startRow = max(0, startRow)

  var endCol = startCol + (dw + xincrement + 1) div xincrement
  var endRow = startRow + (dh + yincrement + 1) div yincrement
  if not loop:
    endCol = min(endCol, currentTilemap.w - tx)
    endRow = min(endRow, currentTilemap.h - ty)

  #debug "d", dw, dh, "dmin", dminx, dminy, "dmax", dmaxx, dmaxy, "o", offsetX, offsetY, "tstart", startCol, startRow, "tend", endCol, endRow

  var count = 0
  for y in startRow..endRow:
    var ty = if loop: ty + wrap(y, currentTilemap.h) else: ty + y
    if not loop and ty < 0 or ty >= currentTilemap.h:
      continue
    for x in startCol..endCol:
      var tx = if loop: tx + wrap(x, currentTilemap.w) else: tx + x
      if not loop and tx < 0 or tx >= currentTilemap.w:
        continue
      let t = currentTilemap.data[ty * currentTilemap.w + tx]
      let px = x * xincrement
      let py = y * yincrement
      if t != 0:
        if (mapFilterFlags == 0) or (spritesheet.spriteFlags[t] and mapFilterFlags) != 0:
          drawTile(t, dminx - offsetX + px, dminy - offsetY + py)
      count+=1

  #debug "count", count, "x", endCol - startCol, "y", endRow - startRow

proc mapWidth*(): Pint =
  return currentTilemap.w

proc mapHeight*(): Pint =
  return currentTilemap.h

proc loadMapFromJson(index: int, filename: string, layer: int) =
  var tm: Tilemap
  # read tiled output format
  var data = readJsonFile(joinPath(assetPath,filename))
  tm.w = data["width"].getBiggestInt.int
  tm.h = data["height"].getBiggestInt.int
  tm.hex = data["orientation"].getStr == "hexagonal"
  tm.tw = data["tilewidth"].getBiggestInt.int
  tm.th = data["tileheight"].getBiggestInt.int
  if tm.hex:
    let hsl = data["hexsidelength"].getBiggestInt.int
    tm.hexOffset = hsl + ((tm.th - hsl) div 2)
  # only look at the selected layer
  if layer < 0 or layer >= data["layers"].len:
    raise newException(RangeError, "layer #$1 not found in map".format(layer))
  tm.data = newSeq[uint8](tm.w*tm.h)
  for i in 0..<(tm.w*tm.h):
    let t = data["layers"][layer]["data"][i].getBiggestInt()
    # map is stored as 0 = blank, 1 = first tile, so we need to subtract 1 from anything higher than 0
    tm.data[i] = if t > 0: (t-1).uint8 else: 0

  tilemaps[index] = tm

proc saveMap*(index: int, filename: string) =
  var tm = tilemaps[index]
  var data: seq[int] = @[]
  for t in tm.data:
    data.add(t.int+1)
  var j = %*{
    "height": tm.h,
    "width": tm.w,
    "version": 1,
    "tilewidth": tm.tw,
    "tileheight": tm.th,
    "nextobjectid": 1,
    "orientation": "orthogonal",
    "renderorder": "right-down",
    "layers": [
      {
        "width": tm.w,
        "height": tm.h,
        "data": data,
        "name": "map",
        "opacity": 1,
        "type": "tilelayer",
        "visible": true,
        "x": 0,
        "y": 0,
      }
    ],
    "tilesets": [
      {
        "columns": (spritesheet.w div tm.tw),
        "firstgid": 1,
        "image": joinPath("..",spritesheet.filename),
        "imagewidth": spritesheet.w,
        "imageheight": spritesheet.h,
        "margin": 0,
        "name": "tileset",
        "spacing": 0,
        "tilewidth": tm.tw,
        "tileheight": tm.th,
        "tilecount": (spritesheet.w div tm.tw) * (spritesheet.h div tm.th),
      }
    ]
  }
  var fp = open(joinPath(assetPath,filename), fmWrite)
  fp.write($j)
  fp.close()

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

proc loadMap*(index: int, filename: string, layer: int = 0) =
  if filename.endsWith(".json"):
    loadMapFromJson(index, filename, layer)
  else:
    when not defined(js):
      loadMapBinary(index, filename)

proc newMap*(index: int, w,h: Pint, tw,th: Pint = 8) =
  var tm = tilemaps[index].addr
  tm[].w = w
  tm[].h = h
  tm[].tw = tw
  tm[].th = th
  tm[].data = newSeq[uint8](w*h)

proc setMap*(index: int) =
  currentTilemap = tilemaps[index].addr

template succWrap*[T](x: T): T =
  if x == T.high:
    T.low
  else:
    x.succ()

template predWrap*[T](x: T): T =
  if x == T.low:
    T.high
  else:
    x.pred()

template incWrap*[T](x: var T) =
  if x == T.high:
    x = T.low
  else:
    x.inc()

template decWrap*[T](x: var T) =
  if x == T.low:
    x = T.high
  else:
    x.dec()

proc rnd*[T: Natural](x: T): T =
  return rand(x.int-1).T

proc rnd*(x: Pfloat): Pfloat =
  return rand(x)

proc rndbi*[T](x: T): T =
  return rand(x) - rand(x)

proc rnd*[T](min: T, max: T): T =
  return rand(max - min) + min

proc rnd*[T](a: openarray[T]): T =
  return sample(a)

proc srand*(seed: int) =
  if seed == 0:
    raise newException(Exception, "Do not srand(0)")
  randomize(seed)

proc srand*() =
  randomize()

proc getControllers*(): seq[NicoController] =
  return controllers

proc setFont*(fontId: FontId) =
  # sets the active font to be used by future print calls
  if fontId > fonts.len:
    return
  currentFontId = fontId
  currentFont = fonts[currentFontId]

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

proc wrap*[T](x,m: T): T =
  if m == 0:
    return 0
  return (x mod m + m) mod m

export note
export noteToNoteStr
export noteStrToNote

proc init*(org, app: string) =
  ## Initializes Nico ready to be used
  controllers = newSeq[NicoController]()

  backend.init(org, app)

  setPalette(loadPalettePico8())

  initialized = true

  randomize(epochTime().int64)
  loadConfig()

  spritesheets[0] = newSurface(128,128)
  spritesheets[0].tw = 8
  spritesheets[0].th = 8
  setSpritesheet(0)

  loadDefaultFont(0)

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

proc addEventListener*(f: EventListener): EventListener {.discardable.} =
  eventListeners.add(f)

proc removeEventListener*(f: EventListener) =
  let i = eventListeners.find(f)
  if i != -1:
    eventListeners.del(i)

proc removeAllEventListeners*() =
  eventListeners = @[]

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

proc invLerp*(a,b,v: Pfloat): Pfloat =
  (v - a) / (b - a)

proc modSign*[T](a,n: T): T =
  return (a mod n + n) mod n

proc angleDiff*(a,b: Pfloat): Pfloat =
  return modSign((a - b) + PI, TAU) - PI

converter toPint*(x: uint8): Pint =
  x.Pint

iterator all*[T](a: var openarray[T]): T {.inline.} =
  let len = a.len
  for i in 0..<len:
    yield a[i]

when defined(android):
  {.emit: """

  extern int cmdCount;
  extern char** cmdLine;
  extern char** gEnv;

  N_CDECL(void, NimMain)(void);

  int SDL_main(int argc, char** args) {
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
    test "angleDiff":
      check(angleDiff(0'f,0'f) == 0'f)
      check(angleDiff(deg2rad(90'f),deg2rad(-90'f)) == deg2rad(180'f))
      check(angleDiff(deg2rad(-90'f),deg2rad(90'f)) == deg2rad(180'f))
      check(angleDiff(deg2rad(-180'f),deg2rad(180'f)) == deg2rad(0'f))

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
