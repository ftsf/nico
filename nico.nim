import nico/backends/common
import tables
import unicode

import nico/keycodes
export nico.keycodes

import nico/spritedraw
export spritedraw

when not defined(js):
  import nico/backends/sdl2 as backend

import os

export StencilMode
export StencilBlend

export EventListener
export Palette

export SynthData
export SynthDataStep
export synthDataToString
export synthDataFromString
export synthIndex

export waitUntilReady
export getRealDt

export profileGetLastStats
export profileGetLastStatsPeak
export profileCollect
export profileBegin
export profileEnd
export ProfilerNode
export profileHistory

export errorPopup

export setClipboardText
export getClipboardText

# Audio
export joinPath
export loadSfx
export loadMusic
export sfx
export music
export getMusic
export synth
export SfxId

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
export volume
export musicGetPos
export musicSeek

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

export startTextInput
export stopTextInput
export isTextInput

export btn
export btnp
export btnpr
export btnup
#export axis
#export axisp

export TouchState
export Touch

import nico/ringbuffer
import math
export pow
import algorithm
import json

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
proc print*(text: string, scale: Pint = 1) # print at cursor
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
proc loadPaletteFromHexString*(s: string): Palette
proc loadPaletteFromImage*(filename: string): Palette
proc loadPalettePico8*(): Palette
proc loadPaletteCGA*(mode: range[0..2] = 0, highIntensity: bool = true): Palette
proc loadPaletteGrayscale*(steps: range[1..256] = 256): Palette
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

proc palCol*(c: ColorId): (uint8,uint8,uint8) =
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

proc setStencilWriteFail*(on: bool) =
  stencilWriteFail = on

proc setStencilOnly*(on: bool) =
  stencilOnly = on

proc stencilMode*(mode: StencilMode) =
  common.stencilMode = mode

proc stencilClear*() =
  for i in 0..<screenWidth*screenHeight:
    stencilBuffer.data[i] = 0

proc stencilClear*(v: Pint) =
  for i in 0..<screenWidth*screenHeight:
    stencilBuffer.data[i] = v.uint8

proc setStencilBlend*(blend: StencilBlend = stencilReplace) =
  stencilBlend = blend

proc stencilTest(x,y: int, nv: uint8): bool =
  if common.stencilMode == stencilNever:
    return false
  if common.stencilMode == stencilAlways:
    return true
  let v = stencilBuffer.get(x,y)
  case common.stencilMode:
  of stencilNever:
    return false
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
proc emulateMouse*(on: bool)

# Input / Touch
proc getTouches*(): seq[Touch] =
  return touches
proc getTouchCount*(): int =
  return touches.len

export hideMouse
export showMouse

## Drawing API

# pixels
proc pset*(x,y: Pint) {.inline.}
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
proc hlineFast*(x0,y,x1: Pint)
proc vline*(x,y0,y1: Pint)
proc tline*(x0,y0,x1,y1: Pint, tx,ty: Pfloat, tdx: Pfloat = 1f, tdy: Pfloat = 0f)

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
proc init*(org: string, app: string)

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
proc mset*(tx,ty: Pint, t: int)
proc mget*(tx,ty: Pint): int
proc mapDraw*(startTX,startTY, tw,th, dx,dy: Pint, dw,dh: Pint = -1, loop: bool = false, ox,oy: Pint = 0)
proc setMap*(index: int)
proc loadMap*(index: int, filename: string, layer = 0)
proc loadMapObjects*(index: int, filename: string, layer = 0): seq[(float32,float32,string,string)]
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
proc lerpSnap*[T](a,b: T, t: Pfloat, threshold = 0.1f): T

proc rnd*[T: Natural](x: T): T
proc rnd*[T](a: openarray[T]): T
proc rnd*(x: Pfloat): Pfloat
proc rnd*[T](x: HSlice[T,T]): T

## Internal functions

proc psetRaw*(x,y: Pint, c: ColorId) {.inline.}
proc psetRaw*(x,y: Pint) {.inline.}

proc fps*(fps: int) =
  ## sets the frame rate in frames per second
  frameRate = fps
  timeStep = 1.0 / fps.float32

proc fps*(): int =
  ## returns the current frame rate in frames per second
  return frameRate

proc time*(): float =
  ## returns the current unix epoch time as a float
  return epochTime()

proc speed*(speed: int) =
  frameMult = speed

proc loadPaletteFromImage*(filename: string): Palette =
  ## returns a palette from a PNG image
  var loaded = false
  var palette: Palette
  backend.loadSurfaceFromPNGNoConvert(joinPath(assetPath,filename)) do(surface: Surface):
    if surface == nil:
      loaded = true
      raise newException(IOError, "Error loading palette image: " & filename)
    var surface = surface
    if surface.channels != 4:
      surface = surface.convertToRGBA()
    var nColors = 0
    let stride = surface.w * surface.channels
    for y in 0..<surface.h:
      for x in 0..<surface.w:
        let r = surface.data[(y * stride) + (x * surface.channels) + 0]
        let g = surface.data[(y * stride) + (x * surface.channels) + 1]
        let b = surface.data[(y * stride) + (x * surface.channels) + 2]
        palette.data[nColors] = RGB(r,g,b)
        nColors += 1
    palette.size = nColors
    loaded = true
  while not loaded:
    # force sync
    discard
  return palette

proc loadPaletteFromHexString*(s: string): Palette =
  var palette: Palette
  for i in 0..<s.len/6:
    let strI = i*6
    let r = strutils.fromHex[uint8](s[strI..<strI+2])
    let g = strutils.fromHex[uint8](s[strI+2..<strI+4])
    let b = strutils.fromHex[uint8](s[strI+4..<strI+6])
    palette.data[i] = RGB(r, g, b)
    palette.size += 1
  return palette

proc loadPaletteFromGPL*(filename: string): Palette =
  ## returns a palette from a GPL (GIMP PALETTE) file
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
    if scanf(line, "$s$i$s$i$s$i", r,g,b):
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
  ## returns the number of entries in the current palette
  return currentPalette.size

proc setPalette*(p: Palette) =
  ## sets the current palette for future drawing operations
  currentPalette = p

proc getPalette*(): Palette =
  ## returns the current palette
  return currentPalette

proc loadPaletteCGA*(mode: range[0..2] = 0, highIntensity: bool = true): Palette =
  ## loads a 4 color CGA palette, mode 0: cyan,magenta,white; mode 1: green,red,yellow; mode 2: cyan,red,white
  result.data[0] = RGB(0,0,0)
  case mode:
  of 0:
    if highIntensity:
      result.data[1] = RGB(0x55FFFF) # light cyan
      result.data[2] = RGB(0xFF55FF) # light magenta
      result.data[3] = RGB(0xFFFFFF) # white
    else:
      result.data[1] = RGB(0x00AAAA) # cyan
      result.data[2] = RGB(0xAA00AA) # magenta
      result.data[3] = RGB(0xAAAAAA) # grey

  of 1:
    if highIntensity:
      result.data[1] = RGB(0x55FF55) # light green
      result.data[2] = RGB(0xFF5555) # light red
      result.data[3] = RGB(0xFFFF55) # yellow
    else:
      result.data[1] = RGB(0x00AA00) # green
      result.data[2] = RGB(0xAA0000) # red
      result.data[3] = RGB(0xAA5500) # brown

  of 2:
    if highIntensity:
      result.data[1] = RGB(0x55FFFF) # light cyan
      result.data[2] = RGB(0xFF5555) # light red
      result.data[3] = RGB(0xFFFFFF) # white
    else:
      result.data[1] = RGB(0x00AAAA) # cyan
      result.data[2] = RGB(0xAA0000) # red
      result.data[3] = RGB(0xAAAAAA) # grey

  result.size = 4

proc loadPalettePico8*(): Palette =
  ## loads a 16 color palette based on Pico8's built-in palette
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
  ## loads a 32 color palette based on Pico8's built-in palettes
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

proc loadPaletteGrayscale*(steps: range[1..256] = 256): Palette =
  ## loads grayscale palette with specified number of steps
  for i in 0..<steps:
    let v = floor(i.float32 / 255f).int
    result.data[i] = RGB(v,v,v)
  result.size = steps

clipMaxX = screenWidth-1
clipMaxY = screenHeight-1

proc clip*() =
  ## resets the clipping rectangle to the full screen
  clipMinX = 0
  clipMaxX = screenWidth-1
  clipMinY = 0
  clipMaxY = screenHeight-1
  clippingRect.x = 0
  clippingRect.y = 0
  clippingRect.w = screenWidth
  clippingRect.h = screenHeight

proc clip*(x,y,w,h: Pint) =
  ## sets the clipping rectangle with top left and width and height
  clipMinX = max(x, 0)
  clipMaxX = min(x+w-1, screenWidth-1)
  clipMinY = max(y, 0)
  clipMaxY = min(y+h-1, screenHeight-1)
  clippingRect.x = max(x, 0)
  clippingRect.y = max(y, 0)
  clippingRect.w = min(w, screenWidth - x)
  clippingRect.h = min(h, screenHeight - y)

proc getClip*(): (int,int,int,int) =
  ## returns the clipping rectangle as x,y,w,h
  return (clipMinX,clipMinY,clipMaxX-clipMinX,clipMaxY-clipMinY)

var ditherColor: int = -1

proc setDitherColor*(c: Pint = -1) =
  ## sets the color to draw for the dither pattern, default is do not draw
  ditherColor = c

proc ditherPattern*(pattern: uint16 = 0b1111_1111_1111_1111) =
  ## sets the dithering pattern for future draw calls, default pattern is no dithering
  # 0123
  # 4567
  # 89ab
  # cdef
  gDitherMode = Dither4x4
  gDitherPattern = pattern

proc ditherOffset*(x,y: Pint) =
  gDitherOffsetX = x
  gDitherOffsetY = y

proc ditherPatternScanlines*() =
  ## sets the dithering pattern to draw every odd scanline
  gDitherMode = Dither4x4
  gDitherPattern = 0b1111_0000_1111_0000

proc ditherPatternScanlines2*() =
  ## sets the dithering pattern to draw every even scanline
  gDitherMode = Dither4x4
  gDitherPattern = 0b0000_1111_0000_1111

proc ditherPatternCheckerboard*() =
  ## sets the dithering pattern to draw a checkerboard
  gDitherMode = Dither4x4
  gDitherPattern = 0b1010_0101_1010_0101

proc ditherPatternCheckerboard2*() =
  ## sets the dithering pattern to draw a checkerboard
  gDitherMode = Dither4x4
  gDitherPattern = 0b0101_1010_0101_1010

proc ditherPatternBigCheckerboard*() =
  ## sets the dithering pattern to draw a 2x2 checkerboard
  gDitherMode = Dither4x4
  gDitherPattern = 0b1100_1100_0011_0011

proc ditherPatternBigCheckerboard2*() =
  ## sets the dithering pattern to draw a 2x2 checkerboard
  gDitherMode = Dither4x4
  gDitherPattern = 0b0011_0011_1100_1100

const bayer4x4int: array[16, int] = [
  0, 8, 2, 10,
  12, 4, 14, 6,
  3, 11, 1, 9,
  15, 7, 13, 5
]
var bayer4x4: array[16, float32]
for i in 0..<16:
  bayer4x4[i] = bayer4x4int[i].float32 / 16f

proc ditherPatternBayer*(a: float32) =
  ## sets the dithering pattern based on an amount 0f..1f using a 4x4 bayer matrix
  gDitherMode = Dither4x4
  gDitherPattern = 0
  for i in 0..<16:
    let b = a < bayer4x4[i]
    if b:
      gDitherPattern = gDitherPattern or (1 shl i).uint16

proc ditherNone*() =
  gDitherMode = DitherNone

proc ditherADitherAdd*(v: float32, a = 237,b = 119, c = 255) =
  gDitherMode = DitherADitherAdd
  gDitherADitherInput = v
  gDitherADitherA = a
  gDitherADitherB = b
  gDitherADitherC = c

proc ditherADitherXor*(v: float32, a = 149,b = 1234, c = 511) =
  gDitherMode = DitherADitherXor
  gDitherADitherInput = v
  gDitherADitherA = a
  gDitherADitherB = b
  gDitherADitherC = c

proc ditherPass(x,y: int): bool {.inline.} =
  if gDitherMode == DitherNone:
    return true

  let x = floorMod(x + gDitherOffsetX, screenWidth)
  let y = floorMod(y + gDitherOffsetY, screenHeight)

  case gDitherMode:
  of DitherNone:
    return true
  of Dither4x4:
    let x4 = (x mod 4).uint16
    let y4 = (y mod 4).uint16
    let bit = (y4 * 4 + x4).uint16
    return (gDitherPattern and (1.uint16 shl bit)) != 0
  of DitherADitherAdd:
    return (gDitherADitherInput + (((x + y * gDitherADitherA) * gDitherADitherB and gDitherADitherC).float32 / gDitherADitherC.float32)) > 1f
  of DitherADitherXor:
    return (gDitherADitherInput + (((x xor y * gDitherADitherA) * gDitherADitherB and gDitherADitherC).float32 / gDitherADitherC.float32)) > 1f

proc isKeyboard*(player: range[0..maxPlayers]): bool =
  ## returns true if player is using a keyboard
  if player > controllers.high:
    return false
  return controllers[player].kind == Keyboard

proc isGamepad*(player: range[0..maxPlayers]): bool =
  ## returns true if player is using a gamepad
  if player > controllers.high:
    return false
  return controllers[player].kind == Gamepad

proc btn*(b: NicoButton): bool =
  ## returns true while button is held down on any controller
  for c in controllers:
    if c.btn(b):
      return true
  return false

proc btnup*(b: NicoButton): bool =
  ## returns true if button was just released on any controller
  for c in controllers:
    if c.btnup(b):
      return true
  return false

proc btn*(b: NicoButton, player: range[0..maxPlayers]): bool =
  ## returns true while button is held down on player's controller
  if player > controllers.high:
    return false
  return controllers[player].btn(b)

proc btnup*(b: NicoButton, player: range[0..maxPlayers]): bool =
  ## returns true if button was just released on player's controller
  if player > controllers.high:
    return false
  return controllers[player].btnup(b)

proc btnRaw*(b: NicoButton, player: range[0..maxPlayers]): int =
  ## returns the internal button value 0 = not down, -1 = just released, >1 = how long it's been held down
  if player > controllers.high:
    return 0
  return controllers[player].buttons[b]

proc btnp*(b: NicoButton): bool =
  ## returns true if button was just pressed on any controller
  for c in controllers:
    if c.btnp(b):
      return true
  return false

proc btnp*(b: NicoButton, player: range[0..maxPlayers]): bool =
  ## returns true if button was just pressed on player's controller
  if player > controllers.high:
    return false
  return controllers[player].btnp(b)

proc btnpr*(b: NicoButton, repeat = 48): bool =
  ## returns true if button was just pressed or held down repeating every repeat frames on player's controller
  for c in controllers:
    if c.btnpr(b, repeat):
      return true
  return false

proc btnpr*(b: NicoButton, player: range[0..maxPlayers], repeat = 48): bool =
  ## returns true if button was just pressed or held down repeating every repeat frames on any controller
  if player > controllers.high:
    return false
  return controllers[player].btnpr(b, repeat)

proc anybtnp*(): bool =
  ## returns true if any key pressed
  for c in controllers:
    if c.anybtnp():
      return true

proc anybtnp*(player: range[0..maxPlayers]): bool =
  ## returns true if any key pressed
  if player > controllers.high:
    return false
  return controllers[player].anybtnp()

proc key*(k: Keycode): bool =
  ## returns true if key is down
  keysDown.hasKey(k) and keysDown[k] != 0

proc keyp*(k: Keycode): bool =
  ## returns true if key was pressed this frame
  keysDown.hasKey(k) and keysDown[k] == 1

proc keypr*(k: Keycode, repeat: int = 48): bool =
  ## returns true if key was pressed this frame or held down repeating every repeat frames
  keysDown.hasKey(k) and keysDown[k].int mod repeat == 1

proc anykeyp*(): bool =
  ## returns true if any key pressed
  aKeyWasPressed

proc jaxis*(axis: NicoAxis): Pfloat =
  ## returns the joystick axis value
  for c in controllers:
    let v = c.axis(axis)
    if abs(v) > c.deadzone:
      return v
  return 0.0

proc jaxis*(axis: NicoAxis, player: range[0..maxPlayers]): Pfloat =
  ## returns the joystick axis value
  if player > controllers.high:
    return 0.0
  return controllers[player].axis(axis)

proc axis*(axis: NicoAxis): Pfloat =
  ## returns the joystick axis value
  for c in controllers:
    let v = c.axis(axis)
    if abs(v) > c.deadzone:
      result += v
    if axis == pcXAxis:
      if c.btn(pcLeft):
        result -= 1f
      if c.btn(pcRight):
        result += 1f
    elif axis == pcYAxis:
      if c.btn(pcUp):
        result -= 1f
      if c.btn(pcDown):
        result += 1f
  result = clamp(result, -1f, 1f)

proc axis*(axis: NicoAxis, player: range[0..maxPlayers]): Pfloat =
  ## returns the joystick axis value
  if player > controllers.high:
    return 0.0
  ## returns the joystick axis value
  let c = controllers[player]
  let v = c.axis(axis)
  if abs(v) > c.deadzone:
    result += v
  if axis == pcXAxis:
    if c.btn(pcLeft):
      result -= 1f
    if c.btn(pcRight):
      result += 1f
  elif axis == pcYAxis:
    if c.btn(pcUp):
      result -= 1f
    if c.btn(pcDown):
      result += 1f
  result = clamp(result, -1f, 1f)

proc pal*(a,b: ColorId) =
  ## set the drawing palette color mapping for a to b
  ## future drawing of color a will draw b instead
  paletteMapDraw[a] = b

proc pal*(a: ColorId): ColorId =
  ## returns the drawing palette color mapping for a
  return paletteMapDraw[a]

proc pal*() =
  ## resets the drawing palette to default
  for i in 0..<maxPaletteSize:
    paletteMapDraw[i] = i

proc pald*(a,b: ColorId) =
  ## set the display palette color mapping for a to b
  paletteMapDisplay[a] = b

proc pald*(a: ColorId): ColorId =
  ## returns the display palette color mapping for a
  return paletteMapDisplay[a]

proc pald*() =
  ## resets the display palette
  for i in 0..<maxPaletteSize:
    paletteMapDisplay[i] = i

proc palt*(a: ColorId, trans: bool) =
  ## sets transparency for color
  paletteTransparent[a] = trans

proc palt*() =
  ## resets palette transparency, all colors will be opaque except for color 0
  for i in 0..<maxPaletteSize:
    paletteTransparent[i] = if i == 0: true else: false

{.push checks:off, optimization: speed.}
proc cls*(c: ColorId = 0) =
  ## clears the screen to the given color. Default is 0. If you need clipping, use rectfill() instead.
  let colId = paletteMapDraw[c].uint8
  for i in 0..<swCanvas.data.len:
    swCanvas.data[i] = colId

proc setCamera*(x,y: Pint = 0) =
  ## sets the current camera position, future drawing operations will draw based on camera position
  cameraX = x
  cameraY = y

proc getCamera*(): (Pint,Pint) =
  ## returns the current camera position as a tuple
  return (cameraX, cameraY)

proc setColor*(colId: ColorId) =
  ## sets the current color
  currentColor = colId

proc getColor*(): ColorId =
  ## returns the current color
  return currentColor

proc psetRaw*(x,y: Pint, c: ColorId) =
  ## sets a pixel to the color c
  ## does not apply camera offset
  if x < clipMinX or y < clipMinY or x > clipMaxX or y > clipMaxY:
    return
  if c >= 0 and stencilTest(x,y,stencilRef):
    if not stencilOnly:
      if ditherPass(x,y):
        swCanvas.set(x,y,paletteMapDraw[c].uint8)
      elif ditherColor >= 0:
        swCanvas.set(x,y,paletteMapDraw[ditherColor.ColorId].uint8)
    if stencilWrite:
      case stencilBlend:
      of stencilReplace:
        stencilBuffer.set(x,y,stencilRef)
      of stencilAdd:
        stencilBuffer.add(x,y,stencilRef)
      of stencilSubtract:
        stencilBuffer.subtract(x,y,stencilRef)
      of stencilMax:
        stencilBuffer.blendMax(x,y,stencilRef)
      of stencilMin:
        stencilBuffer.blendMin(x,y,stencilRef)
  elif c < 0 and stencilTest(x,y,stencilRef):
    # special mode to only draw to stencil with negative of color value
    # eg. drawing with color -1 will write 1 (blended) to the stencil buffer and not draw to screen
    let cref = (-c).uint8
    case stencilBlend:
    of stencilReplace:
      stencilBuffer.set(x,y,cref)
    of stencilAdd:
      stencilBuffer.add(x,y,cref)
    of stencilSubtract:
      stencilBuffer.subtract(x,y,cref)
    of stencilMax:
      stencilBuffer.blendMax(x,y,cref)
    of stencilMin:
      stencilBuffer.blendMin(x,y,cref)
  elif stencilWriteFail:
    case stencilBlend:
    of stencilReplace:
      stencilBuffer.set(x,y,stencilRef)
    of stencilAdd:
      stencilBuffer.add(x,y,stencilRef)
    of stencilSubtract:
      stencilBuffer.subtract(x,y,stencilRef)
    of stencilMax:
      stencilBuffer.blendMax(x,y,stencilRef)
    of stencilMin:
      stencilBuffer.blendMin(x,y,stencilRef)

proc psetRaw*(x,y: Pint) =
  ## sets a pixel to current color, (unsafe, does not check for bounds)
  psetRaw(x,y,currentColor)

proc pset*(x,y: Pint, c: ColorId) =
  ## sets a pixel to the color c
  psetRaw(x-cameraX, y-cameraY, c)

proc pset*(x,y: Pint) =
  ## sets a pixel to the current color
  pset(x,y,currentColor)

proc ssetSafe*(x,y: Pint, c: int = -1) =
  ## set the color for a pixel on the spritesheet, does nothing if out of bounds
  let c = if c == -1: currentColor else: c
  if x < 0 or y < 0 or x > spritesheet.w-1 or y > spritesheet.h-1:
    return
  spritesheet.data[y*spritesheet.w+x] = paletteMapDraw[c].uint8

proc sset*(x,y: Pint, c: int = -1) =
  ## set the color for a pixel on the spritesheet, throws an exception if out of bounds
  let c = if c == -1: currentColor else: c
  if x < 0 or y < 0 or x > spritesheet.w-1 or y > spritesheet.h-1:
    raise newException(RangeDefect, "sset ($1,$2) out of bounds".format(x,y))
  spritesheet.data[y*spritesheet.w+x] = paletteMapDraw[c].uint8

proc sget*(x,y: Pint): ColorId =
  ## returns the palette index for a pixel on the spritesheet
  if x > spritesheet.w-1 or x < 0 or y > spritesheet.h-1 or y < 0:
    debug "sget invalid coord: ", x, y
    return 0
  let color = spritesheet.data[y*spritesheet.w+x].ColorId
  return color

proc pget*(x,y: Pint): ColorId =
  ## returns the palette index for a pixel on the canvas
  let x = x - cameraX
  let y = y - cameraY
  if x > swCanvas.w-1 or x < 0 or y > swCanvas.h-1 or y < 0:
    return 0
  return swCanvas.data[y*swCanvas.w+x].ColorId

proc pgetRaw*(x,y: Pint): ColorId =
  ## returns the palette index for a pixel on the canvas, does not account for camera
  return swCanvas.data[y*swCanvas.w+x].ColorId

proc pgetRGB*(x,y: Pint): (uint8,uint8,uint8) =
  ## returns the RGB values for a pixel on the canvas, does not account for camera
  if x > swCanvas.w-1 or x < 0 or y > swCanvas.h-1 or y < 0:
    return (0'u8,0'u8,0'u8)
  return palCol(swCanvas.data[y*swCanvas.w+x].ColorId)

proc rectfill*(x1,y1,x2,y2: Pint) =
  ## draws a filled rectangle from two points
  let minx = min(x1,x2) - cameraX
  let maxx = max(x1,x2) - cameraX
  let miny = min(y1,y2) - cameraY
  let maxy = max(y1,y2) - cameraY

  for y in max(miny,clipMinY)..min(maxy,clipMaxY):
    for x in max(minx,clipMinX)..min(maxx,clipMaxX):
      psetRaw(x,y,currentColor)

proc rrectfill*(x1,y1,x2,y2: Pint, r: Pint = 1) =
  ## draws a filled rounded rectangle from two points, r specifies radius
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
  ## draws a hollow rectangle from position and size
  hline(x,y,x+w-1)
  vline(x,y,y+h-1)
  vline(x+w-1,y,y+h-1)
  hline(x,y+h-1,x+w-1)

proc boxfill*(x,y,w,h: Pint) =
  ## draws a filled rectangle from position and size
  if w == 0 or h == 0:
    return
  for y in y..<y+h:
    hline(x,y,x+w-1)

proc rbox*(x,y,w,h: Pint, r: Pint = 1) =
  ## draws a hollow rounded rectangle from position and size, r specifies radius
  rrect(x,y,x+w-1,y+h-1,r)

proc rboxfill*(x,y,w,h: Pint, r: Pint = 1) =
  ## draws a filled rounded rectangle from position and size, r specifies radius
  rrectfill(x,y,x+w-1,y+h-1,r)

template innerLineLow(x0,y0,x1,y1: int, call: untyped): untyped =
  var dx = x1 - x0
  var dy = y1 - y0
  var yi = 1
  if dy < 0:
    yi = -1
    dy = -dy
  var D = 2*dy - dx
  var y {.inject.} = y0

  for x {.inject.} in x0..x1:
    call
    if D > 0:
      y = y + yi
      D = D - 2*dx
    D = D + 2*dy

template innerLineHigh(x0,y0,x1,y1: int, call: untyped): untyped =
  var dx = x1 - x0
  var dy = y1 - y0
  var xi = 1
  if dx < 0:
    xi = -1
    dx = -dx
  var D = 2*dx - dy
  var x {.inject.} = x0

  for y {.inject.} in y0..y1:
    call
    if D > 0:
      x = x + xi
      D = D - 2*dy
    D = D + 2*dx

template innerLine(x0,y0,x1,y1: Pint, call: untyped): untyped =
  if x0 == x1 and y0 == y1:
    let x {.inject.} = x0
    let y {.inject.} = y0
    call

  elif y0 == y1:
    # horizontal
    let y {.inject.} = y0
    for x {.inject.} in min(x0,x1)..max(x0,x1):
      call

  elif x0 == x1:
    # vertical
    let x {.inject.} = x0
    for y {.inject.} in min(y0,y1)..max(y0,y1):
      call

  elif abs(y1 - y0) < abs(x1 - x0):
    if x0 > x1:
      innerLineLow(x1,y1,x0,y0):
        call
    else:
      innerLineLow(x0,y0,x1,y1):
        call
  else:
    if y0 > y1:
      innerLineHigh(x1,y1,x0,y0):
        call
    else:
      innerLineHigh(x0,y0,x1,y1):
        call

proc line*(x0,y0,x1,y1: Pint) =
  ## draws a line between two points
  innerLine(x0,y0,x1,y1):
    pset(x,y)

proc tline*(x0,y0,x1,y1: Pint, tx,ty: Pfloat, tdx: Pfloat = 1f, tdy: Pfloat = 0f) =
  ## draws a textured line between two points sampling the current spritesheet
  ## tx,ty are starting texture coordinates
  ## tdx: amount to add to tx after each pixel is drawn defaults to 1 pixel
  ## tdy: amount to add to ty after each pixel is drawn defaults to 0 pixels
  var tx = tx
  var ty = ty
  var i = 0
  innerLine(x0,y0,x1,y1):
    let c = sget(tx.int,ty.int)
    pset(x,y,c)
    echo "i: ", i, " tx: ", tx, " ty: ", ty
    tx += tdx
    ty += tdy
    i.inc()

proc hlineFast*(x0,y,x1: Pint) =
  ## draws a horizontal line without checking for errors (unsafe, be sure to check bounds before using this)
  if y < clipMinY or y > clipMaxY:
    return
  for x in max(x0,clipMinX)..min(x1,clipMaxX):
    psetRaw(x,y,currentColor)

proc hline*(x0,y,x1: Pint) =
  ## draws a horizontal line
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
  ## draws a vertical line
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

proc lineDashed*(x0,y0,x1,y1: Pint, pattern: uint8 = 0b10101010) =
  ## draws a dashed line, the line will only been drawn where the pattern is 1 in binary
  var i = 0
  innerLine(x0,y0,x1,y1):
    if (pattern and (1 shl i).uint8) != 0:
      pset(x,y)

proc rect*(x1,y1,x2,y2: Pint) =
  ## draws a rectangle defined by two points
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
  ## draws a rounded rectangle, radius defined by r

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
  ## draws the corners of a rectangle
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
  ## draws the corners of a rounded rectangle
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
  ## returns x rounded down
  return x.floor()

proc lerp[T](a, b: T, t: Pfloat): T =
  return a + (b - a) * t

proc lerpSnap*[T](a, b: T, t: Pfloat, threshold = 0.1f): T =
  # lerp and then snap once within threshold
  result = a + (b - a) * t
  when T is array:
    for i in 0..<result.len:
      if abs(result[i] - b[i]) < threshold:
        result[i] = b[i]
  else:
    if abs(result - b) < threshold.T:
      result = b

proc orient2d(ax,ay,bx,by,cx,cy: Pint): int =
  return (bx - ax) * (cy - ay) - (by - ay) * (cx-ax)

proc trifill*(ax,ay,bx,by,cx,cy: Pint) =
  ## fills a triangle defined by 3 points with current color
  #  https://github.com/rygorous/rygblog-src/blob/master/posts/optimizing-the-basic-rasterizer.md
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

  # Barycentric coordinates at minX/minY corner
  var w0_row = orient2d(bx,by,cx,cy,minx,miny)
  var w1_row = orient2d(cx,cy,ax,ay,minx,miny)
  var w2_row = orient2d(ax,ay,bx,by,minx,miny)

  # Go through all the pixels in the triangle's bounding box
  # and test if they are within the triangle
  # if inside then draw the pixel
  for py in minY..maxY:
    var w0 = w0_row
    var w1 = w1_row
    var w2 = w2_row

    for px in minX..maxX:
      #if w0 >= 0 and w1 >= 0 and w2 >= 0: # tests whether the pixel is inside the triangle
      if (w0 or w1 or w2) > 0:
        psetRaw(px,py)

      w0 += A12
      w1 += A20
      w2 += A01

    w0_row += B12
    w1_row += B20
    w2_row += B01

proc ttrifill*(ax,ay,au,av,bx,by,bu,bv,cx,cy,cu,cv: Pfloat) =
  ## fills a triangle defined by 3 points with current color
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

  let invArea = 1f / orient2d(ax,ay,bx,by,cx,cy).float32
  var w0_row = orient2d(bx,by,cx,cy,minx,miny)
  var w1_row = orient2d(cx,cy,ax,ay,minx,miny)
  var w2_row = orient2d(ax,ay,bx,by,minx,miny)

  for py in minY..maxY:
    var w0 = w0_row
    var w1 = w1_row
    var w2 = w2_row

    for px in minX..maxX:
      if w0 >= 0 and w1 >= 0 and w2 >= 0:
        let bw0 = w0.float32 * invArea
        let bw1 = w1.float32 * invArea
        let bw2 = w2.float32 * invArea
        let tx = au * bw0 + bu * bw1 + cu * bw2
        let ty = av * bw0 + bv * bw1 + cv * bw2
        let c = sget(tx,ty)
        psetRaw(px,py,c)

      w0 += A12
      w1 += A20
      w2 += A01

    w0_row += B12
    w1_row += B20
    w2_row += B01

proc quadfill*(x1,y1,x2,y2,x3,y3,x4,y4: Pint) =
  ## fills a quadrilateral with current color
  trifill(x1,y1,x2,y2,x3,y3)
  trifill(x1,y1,x3,y3,x4,y4)

proc tquadfill*(x1,y1,u1,v1, x2,y2,u2,v2, x3,y3,u3,v3, x4,y4,u4,v4: Pfloat) =
  ## fills a quadrilateral with current color
  ttrifill(x1,y1,u1,v1, x2,y2,u2,v2, x3,y3,u3,v3)
  ttrifill(x1,y1,u1,v1, x3,y3,u3,v3, x4,y4,u4,v4)

proc plot4pointsfill(cx,cy,x,y: Pint) =
  hline(cx - x, cy + y, cx + x)
  if x != 0 and y != 0:
    hline(cx - x, cy - y, cx + x)

template doWhile*(a, b: untyped): untyped =
  ## loops a least once and then until condition b is no longer met
  b
  while a:
    b

proc ellipsefill*(cx,cy: Pint, rx,ry: Pint) =
  ## fills an axis aligned ellipse
  ## cx,cy: center position
  ## rx,ry: radius
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
  ## draws a filled circle at cx,cy with radius r
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
  ## draws a hollow circle at cx,cy with radius r
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

when false:
  proc arc*(cx,cy: Pint, r: Pfloat, startAngle, endAngle: Pfloat) =
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
      #if x >= startX and x < endX and y >= startY and y < endY:
      when true:
        pset(cx + x, cy + y)
        pset(cx + y, cy + x)
        pset(cx - y, cy + x)
        pset(cx - x, cy + y)

        pset(cx - x, cy - y)
        pset(cx - y, cy - x)
        pset(cx + y, cy - x)
        pset(cx + x, cy - y)

      y += 1
      err += 1 + 2 * y.float32
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
      if sx.int < 0 or sy.int < 0 or sx.int > font.w - 1 or sy.int > font.h - 1:
        continue
      if font.data[sy * font.w + sx] == 1:
        pset(dx,dy,currentColor)

      sx += 1.0f * (sw/dw)
      dx += 1.0f
    sy += 1.0f * (sh/dh)
    dy += 1.0f

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
      let srcCol = src.data[syi * src.w + sxi].ColorId
      if not paletteTransparent[srcCol]:
        psetRaw(dxi,dyi,srcCol)
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
      let srcCol = spritesheet.data[syi * srcw + sxi].ColorId
      if not paletteTransparent[srcCol]:
        psetRaw(dxi, dyi, paletteMapDraw[srcCol])
      sxi += 1
      dxi += 1
    syi += 1
    dyi += 1
    sxi = sx
    dxi = dx

proc blitFast(src: Surface, sx,sy, dx,dy, w,h: Pint) {.inline.} =
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
      let srcCol = src.data[syi * src.w + sxi].ColorId
      if not paletteTransparent[srcCol]:
        psetRaw(dxi, dyi, paletteMapDraw[srcCol])
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

  let dstCenterX = (dstW - 1f) / 2f
  let dstCenterY = (dstH - 1f) / 2f

  for y in 0..<dstH:
    for x in 0..<dstW:
      let dx = (centerX - dstCenterX) + x - cameraX
      let dy = (centerY - dstCenterY) + y - cameraY

      # check dest pixel is in bounds
      if dx < clipMinX or dy < clipMinY or dx > clipMaxX or dy > clipMaxY:
        continue

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

      let srcCol = src.data[sy * src.w + sx].ColorId
      if not paletteTransparent[srcCol]:
        psetRaw(dx, dy, paletteMapDraw[srcCol])

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

      let srcCol = src.data[(srcRect.y + sy) * src.w + (srcRect.x + sx)].ColorId
      if not paletteTransparent[srcCol]:
        psetRaw(dx, dy, paletteMapDraw[srcCol])

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

      let srcCol = src.data[syi * src.w + sxi].ColorId
      if not paletteTransparent[srcCol]:
        psetRaw(dxi,dyi,paletteMapDraw[srcCol])

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

      let srcCol = src.data[(startsy + wrap(syi + oy, h)) * src.w + (startsx + wrap(sxi + ox, w))].ColorId
      if not paletteTransparent[srcCol]:
        pset(dxi,dyi,paletteMapDraw[srcCol])

      sxi += xi
      dxi += 1
    syi += yi
    dyi += 1
    sxi = startsx
    dxi = dx

proc blitStretch(src: Surface, srcRect, dstRect: Rect, hflip, vflip: bool = false) =
  # if dstrect doesn't overlap clipping rect, skip it
  if not overlap(dstrect, clippingRect):
    return

  var dx = dstRect.x
  var dy = dstRect.y
  var dw = dstRect.w
  var dh = dstRect.h

  var sx = srcRect.x.float32
  var sy = srcRect.y.float32
  var sw = srcRect.w.float32
  var sh = srcRect.h.float32

  let sxinc = sw / dw.float32 * (if hflip: -1f else: 1f)
  let syinc = sh / dh.float32 * (if vflip: -1f else: 1f)

  if vflip:
    sy = (srcRect.y + srcRect.h - 1).float32

  for y in 0..dstRect.h-1:
    if hflip:
      sx = (srcRect.x + srcRect.w - 1).float32
    else:
      sx = srcRect.x.float32

    let syi = if vflip: ceil(sy).int else: flr(sy).int

    dx = dstRect.x
    for x in 0..dstRect.w-1:
      let sxi = if hflip: ceil(sx).int else: flr(sx).int
      if sxi < 0 or syi < 0 or sxi > src.w-1 or syi > src.h-1:
        continue

      if not (dx < clipMinX or dy < clipMinY or dx > clipMaxX or dy > clipMaxY):
        let srcCol = src.data[syi * src.w + sxi].ColorId
        if not paletteTransparent[srcCol]:
          psetRaw(dx,dy,paletteMapDraw[srcCol])

      sx += sxinc
      dx += 1
    sy += syinc
    dy += 1
{.pop.}

proc mset*(tx,ty: Pint, t: int) =
  ## sets the map tile at tx,ty to t
  if currentTilemap == nil:
    raise newException(Exception, "No map set")
  if tx < 0 or tx > currentTilemap.w - 1 or ty < 0 or ty > currentTilemap.h - 1:
    return
  currentTilemap[].data[ty * currentTilemap.w + tx] = t

proc mget*(tx,ty: Pint): int =
  ## returns the map tile at tx,ty
  if currentTilemap == nil:
    raise newException(Exception, "No map set")
  if tx < 0 or tx > currentTilemap.w - 1 or ty < 0 or ty > currentTilemap.h - 1:
    return 0
  return currentTilemap[].data[ty * currentTilemap.w + tx]

iterator mapAdjacent*(tx,ty: Pint): (Pint,Pint) =
  ## returns all tiles orthogonally adjacent to tx,ty
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
  ## returns the spriteflag for sprite s
  return spritesheet.spriteFlags[s]

proc fget*(s: Pint, f: uint8): bool =
  ## returns true if spriteflag for sprite s has bit f set
  return spritesheet.spriteFlags[s].contains(f)

proc fset*(s: Pint, f: uint8) =
  ## sets spriteflags for sprite s to f
  spritesheet.spriteFlags[s] = f

proc fset*(s: Pint, f: uint8, v: bool) =
  ## sets bit f for sprite s's spriteflags to v
  if v:
    spritesheet.spriteFlags[s].set(f)
  else:
    spritesheet.spriteFlags[s].unset(f)

proc masterVol*(newVol: range[0..255]) =
  ## sets the master volume to newVol
  echo "setting masterVol: ", newVol
  masterVolume = clamp(newVol.float32 / 255.0'f, 0'f, 1'f)

proc masterVol*(): int =
  ## returns the master volume 0..255
  return (masterVolume * 255.0'f).int

proc sfxVol*(newVol: range[0..255]) =
  ## sets the sfx volume to newVol
  sfxVolume = clamp(newVol.float32 / 255.0'f, 0'f, 1'f)

proc sfxVol*(): int =
  ## returns the sfx volume
  return (sfxVolume * 255.0'f).int

proc musicVol*(newVol: range[0..255]) =
  ## sets the music volume
  musicVolume = clamp(newVol.float32 / 255.0'f, 0'f, 1'f)

proc musicVol*(): int =
  ## returns the music volume
  return (musicVolume * 255.0'f).int

proc consumeCharacter(font: Font, posX, posY: var int, index: int, charId: Rune) =
  var rect: Rect = (posX,posY,0,0)
  while font.data[rect.y*font.w+rect.x] == 2:
    rect.x.inc()
  # determine height, go down until we hit the bottom of font or borderColor
  for y in posY..<font.h:
    if font.data[y*font.w+rect.x] == 2:
      break
    rect.h.inc()
  for x in rect.x..<font.w:
    if font.data[posY*font.w+x] == 2:
      break
    rect.w.inc()
  when defined(fontDebug):
    echo index, ": ", $charId, " ", rect
  font.rects[charId] = rect
  posX = rect.x + rect.w + 1
  posY = rect.y

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
    var borderColorRGBA = (
      surface.data[0],
      surface.data[1],
      surface.data[2],
      surface.data[3]
    )
    for i in 0..<font.w*font.h:
      var col = (
        surface.data[i*surface.channels+0],
        surface.data[i*surface.channels+1],
        surface.data[i*surface.channels+2],
        surface.data[i*surface.channels+3]
      )
      if col == borderColorRGBA:
        font.data[i] = borderColor
      elif col[3] == 0:
        font.data[i] = transparentColor
      else:
        font.data[i] = solidColor

  elif surface.channels == 1:
    debug "loading font from indexed", surface.filename
    for i in 0..<font.w*font.h:
      font.data[i] = surface.data[i]

  font.rects = initTable[Rune,Rect](128)


  var currentRect: Rect = (0,0,0,0)
  var i = 0
  var charPos = 0
  var lastChar = -1
  echo "loading font ", surface.filename, " with ", chars.runeLen, " chars, width: ", font.w
  # scan across the top of the font image
  var posX, posY: int
  var charId: Rune
  while charPos < chars.len:
    chars.fastRuneAt(charPos, charId, true)
    if font.rects.hasKey(charId):
      raise newException(Exception, "font already has character: " & $charId & " index: " & $i)
    font.consumeCharacter(posX, posY, i, charId)
    if posX >= font.w:
      break
    i.inc()

  echo "loaded font with ", font.rects.len, "/", chars.runeLen, " chars"

  if font.rects.len != chars.runeLen:
    if lastChar != -1:
      echo "last loaded char: ", lastChar.Rune, " at index ", i, " x: ", currentRect.x
    raise newException(Exception, "didn't load all characters from font, loaded: " & $font.rects.len & " bitmaps of specified chars " & $chars.runeLen)

  return font

import nico/fontdata

proc loadDefaultFont*(index: int) =
  ## loads the default font into font index
  let shouldReplace = currentFont == fonts[index]
  fonts[index] = createFontFromSurface(defaultFontSurface, defaultFontChars)
  if shouldReplace:
    debug "updating current font ", index
    setFont(index)

proc loadFont*(index: int, filename: string) =
  ## loads the font from filename into font index. expects a png file with a png.dat file with a list of the characters
  let shouldReplace = currentFont == fonts[index]
  var chars: string
  var datPath: string
  try:
    datPath = joinPath(assetPath, filename & ".dat")
    chars = backend.readFile(datPath)
  except IOError as e:
    raise newException(Exception, "Missing " & datPath & " needed if not passing chars to loadFont: " & e.msg)
  chars.removeSuffix()
  backend.loadSurfaceFromPNGNoConvert(joinPath(assetPath,filename)) do(surface: Surface):
    fonts[index] = createFontFromSurface(surface, chars)
    if shouldReplace:
      debug "updating current font ", index
      setFont(index)

proc loadFont*(index: int, filename: string, chars: string) =
  ## loads the font from filename into font index. expects a png file, you must pass a list of characters in the font
  let shouldReplace = currentFont == fonts[index]
  backend.loadSurfaceFromPNG(joinPath(assetPath,filename)) do(surface: Surface):
    fonts[index] = createFontFromSurface(surface, chars)
  if shouldReplace:
    setFont(index)

proc glyph*(c: Rune, x,y: Pint, scale: Pint = 1): Pint =
  ## draw a glyph from the current font
  if currentFont == nil:
    raise newException(Exception, "No font selected")
  if not currentFont.rects.hasKey(c):
    return
  let src: Rect = currentFont.rects[c]
  let dst: Rect = (x.int, y.int, src.w * scale, src.h * scale)
  try:
    fontBlit(currentFont, src, dst, currentColor)
  except IndexDefect:
    debug "index error glyph: ", c, " @ ", x, ",", y
    raise
  return src.w * scale + scale

proc glyph*(c: char, x,y: Pint, scale: Pint = 1): Pint =
  ## draw a glyph from the current font
  return glyph(c.Rune, x, y, scale)

proc fontHeight*(): Pint =
  ## returns the height of the current font in pixels
  if currentFont == nil:
    return 0
  return currentFont.rects[Rune(' ')].h

proc print*(text: string, x,y: Pint, scale: Pint = 1) =
  ## prints a string using the current font
  if currentFont == nil:
    raise newException(Exception, "No font selected")
  var x = x
  var y = y
  let ix = x
  let lineHeight = fontHeight() * scale + scale
  for line in text.splitLines:
    for c in line.runes:
      x += glyph(c, x, y, scale)
    x = ix
    y += lineHeight

proc print*(text: string, scale: Pint = 1) =
  ## prints a string using the current font at cursor position
  if currentFont == nil:
    raise newException(Exception, "No font selected")
  var x = cursorX
  let y = cursorY
  let lineHeight = fontHeight() * scale + scale
  for c in text.runes:
    x += glyph(c, x, y, scale)
  cursorY += lineHeight

proc glyphWidth*(c: Rune, scale: Pint = 1): Pint =
  ## returns the width of the glyph in the current font
  if currentFont == nil:
    raise newException(Exception, "No font selected")
  if not currentFont.rects.hasKey(c):
    return 0
  result = currentFont.rects[c].w*scale + scale

proc glyphWidth*(c: char, scale: Pint = 1): Pint =
  ## returns the width of the glyph in the current font
  glyphWidth(c.Rune)

proc textWidth*(text: string, scale: Pint = 1): Pint =
  ## returns the width of a string in the current font
  if currentFont == nil:
    raise newException(Exception, "No font selected")
  for c in text.runes:
    if not currentFont.rects.hasKey(c):
      raise newException(Exception, "character not in font: '" & $c & "'")
    result += currentFont.rects[c].w*scale + scale

proc printr*(text: string, x,y: Pint, scale: Pint = 1) =
  ## prints a string in the current font, right aligned
  let width = textWidth(text, scale)
  print(text, x-width, y, scale)

proc printc*(text: string, x,y: Pint, scale: Pint = 1) =
  ## prints a string in the current font, center aligned
  let width = textWidth(text, scale)
  print(text, x-(width div 2), y, scale)

proc copy*(sx,sy,dx,dy,w,h: Pint) =
  ## copy a rectangle of w by h pixels from sx,sy to dx,dy
  blitFastRaw(swCanvas, sx, sy, dx, dy, w, h)

proc copyPixelsToMem*(sx,sy: Pint, buffer: var openarray[uint8], count = -1) =
  ## copy pixels from the canvas to memory
  let offset = sy*swCanvas.w+sx
  let count = if count == -1: buffer.len else: count
  for i in 0..<min(buffer.len,count):
    if offset+i < 0:
      continue
    if offset+i > swCanvas.data.high:
      break
    buffer[i] = swCanvas.data[offset+i]

proc copyMemToScreen*(dx,dy: Pint, buffer: var openarray[uint8], count = -1) =
  ## copy pixels from memory to the canvas
  let offset = dy*swCanvas.w+dx
  let count = if count == -1: buffer.len else: count
  for i in 0..<min(buffer.len,count):
    if offset+i < 0:
      continue
    if offset+i > swCanvas.data.high:
      break
    swCanvas.data[offset+i] = buffer[i]

proc hasMouse*(): bool =
  ## returns true if there is a mouse
  return mouseDetected

proc emulateMouse*(on: bool) =
  ## sets whether to treat touch input as a mouse
  touchMouseEmulation = on

proc mouse*(): (int,int) =
  ## returns the mouse position relative to the canvas
  return (mouseX,mouseY)

proc mouserel*(): (float32,float32) =
  ## returns the relative mouse movement
  return (mouseRelX,mouseRelY)

proc useRelativeMouse*(on: bool) =
  ## enable relative mouse data
  backend.useRelativeMouse(on)

proc mousebtn*(b: range[0..2]): bool =
  ## returns true if mouse button b is down
  return mouseButtons[b] > 0

proc mousebtnp*(b: range[0..2]): bool =
  ## returns true if mouse button b was pressed this frame
  return mouseButtons[b] == 1

proc mousebtnup*(b: range[0..2]): bool =
  ## returns true if mouse button b was released this frame
  return mouseButtons[b] == -1

proc mousebtnpr*(b: range[0..2], r: Pint): bool =
  ## returns true if mouse button b was pressed this frame or repeating every r frames
  return mouseButtons[b] > 0 and mouseButtons[b] mod r == 1

proc mousewheel*(): int =
  ## return the mousewheel status, 0 no movement, -1 for down, 1 for up
  return mouseWheelState

proc clearKeysForBtn*(btn: NicoButton) =
  ## clear key map for btn
  keymap[btn] = @[]

proc addKeyForBtn*(btn: NicoButton, scancode: Scancode) =
  ## add a new key for btn
  if not (scancode in keymap[btn]):
    keymap[btn].add(scancode)

proc shutdown*() =
  ## shut down nico
  keepRunning = false

proc resize() =
  backend.resize()
  echo "resize ", screenWidth, " x ", screenHeight
  clip()
  cls()
  present()

proc addResizeFunc*(newResizeFunc: ResizeFunc) =
  ## add a callback for when the window is resized
  resizeFuncs.add(newResizeFunc)

proc removeResizeFunc*(resizeFunc: ResizeFunc) =
  ## remove a callback for when the window is resized
  let i = resizeFuncs.find(resizeFunc)
  resizeFuncs.del(i)

proc setTargetSize*(w,h: int) =
  ## set the desired canvas size
  if targetScreenWidth == w and targetScreenHeight == h:
    return
  targetScreenWidth = w
  targetScreenHeight = h
  resize()

proc fixedSize*(): bool =
  ## returns true if fixed size mode is enabled
  return fixedScreenSize

proc fixedSize*(enabled: bool) =
  ## set whether to use fixed size mode, if true canvas size will match target size, if false, the window can be resized and the canvas will match the window
  fixedScreenSize = enabled
  if backend.hasWindow():
    resize()

proc getScreenScale*(): float32 =
  ## return the canvas scaling factor
  return common.screenScale

proc integerScale*(): bool =
  ## returns true if integer scaling mode is enabled
  return integerScreenScale

proc integerScale*(enabled: bool) =
  ## set whether to use integer scaling mode or not, if true scaling factor will always be an integer, otherwise it may be a real number
  integerScreenScale = enabled
  if backend.hasWindow():
    resize()

proc newSpritesheet*(index: int, w, h: int, tw,th = 8) =
  ## create a new spritesheet with w,h pixels, each sprite will be tw by th
  if index < 0 or index >= spritesheets.len:
    raise newException(Exception, "Invalid spritesheet " & $index)
  spritesheets[index] = newSurface(w, h)
  spritesheets[index].tw = tw
  spritesheets[index].th = th
  spritesheets[index].filename = ""

proc setSpritesheet*(index: int) =
  ## set the current spritesheet for future sprite drawing operations
  if index < 0 or index >= spritesheets.len:
    raise newException(Exception, "Invalid spritesheet " & $index)

  if spritesheets[index] == nil:
    raise newException(Exception, "No spritesheet loaded: " & $index)
  spritesheet = spritesheets[index]

proc loadSpriteSheet*(index: int, filename: string, tileWidth,tileHeight: Pint = 8) =
  ## load a spritesheet into index from filename, must be a png file, spritesheet dimensions must be divisible by tileWidth,tileHeight
  if index < 0 or index >= spritesheets.len:
    raise newException(Exception, "Invalid spritesheet " & $index)
  let shouldReplace = spritesheet == spritesheets[index]
  backend.loadSurfaceFromPNG(joinPath(assetPath,filename)) do(surface: Surface) {.nosinks.}:
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
  ## returns the current spritesheets's tileWidth and tileHeight
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
  ## draw a sprite at x,y. w,h allow drawing multiple sprites as one, draws from top left
  if spritesheet.tw == 0 or spritesheet.th == 0:
    return
  var src = getSprRect(spr, w, h)
  if hflip or vflip:
    blitFastFlip(spritesheet, src.x, src.y, x-cameraX, y-cameraY, src.w, src.h, hflip, vflip)
  else:
    blitFast(spritesheet, src.x, src.y, x-cameraX, y-cameraY, src.w, src.h)

proc sprshift*(spr: Pint, x,y: Pint, w,h: Pint = 1, ox,oy: Pint = 0, hflip, vflip: bool = false) =
  ## draw a sprite but slide and wrap the pixels
  if spritesheet.tw == 0 or spritesheet.th == 0:
    return
  let src = getSprRect(spr, w, h)
  if hflip or vflip:
    blitFastFlipShift(spritesheet, src.x, src.y, x-cameraX, y-cameraY, src.w, src.h, ox, oy, hflip, vflip)
  else:
    blitFastFlipShift(spritesheet, src.x, src.y, x-cameraX, y-cameraY, src.w, src.h, ox, oy, false, false)

proc sprRot*(spr: Pint, x,y: Pint, radians: float32, w,h: Pint = 1) =
  ## draw a rotated sprite, center will be at x,y and rotated around the center
  let src = getSprRect(spr, w, h)
  blitFastRot(spritesheet, src, x, y, radians)

proc sprRot90*(spr: Pint, x,y: Pint, rotations: int, w,h: Pint = 1) =
  ## draw a 90 degree rotated sprite from top left, rotations = 1 = 90 degrees clockwise, 2 = 180 degrees, 3 = 90 degrees anti-clockwise
  let src = getSprRect(spr, w, h)
  blitFastRot90(spritesheet, src, x, y, rotations)

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
  ## draw an integer scaled sprite
  var src = getSprRect(spr, w, h)
  var dst: Rect = ((x-cameraX).int,(y-cameraY).int,(dw*spriteSheet.tw).int,(dh*spriteSheet.th).int)
  blitStretch(spritesheet, src, dst, hflip, vflip)

proc sprss*(spr: Pint, x,y: Pint, w,h: Pint = 1, dw,dh: Pint, hflip, vflip: bool = false) =
  ## draw a scaled sprite
  var src = getSprRect(spr, w, h)
  var dst: Rect = ((x-cameraX).int,(y-cameraY).int,dw.int,dh.int)
  blitStretch(spritesheet, src, dst, hflip, vflip)

proc drawTile(spr: Pint, x,y: Pint) =
  var src = getSprRect(spr.Pint)
  # ensure destination is inside clipping rect
  if overlap(clippingRect,(x.int,y.int, src.w, src.h)):
    blitFast(spritesheet, src.x, src.y, x, y, src.w, src.h)

proc sspr*(sx,sy, sw,sh, dx,dy: Pint, dw,dh: Pint = -1, hflip, vflip: bool = false) =
  ## draw a stretched sprite
  var src: Rect = (sx.int,sy.int,sw.int,sh.int)
  let dw = if dw >= 0: dw else: sw
  let dh = if dh >= 0: dh else: sh
  var dst: Rect = ((dx-cameraX).int,(dy-cameraY).int,dw.int,dh.int)
  blitStretch(spritesheet, src, dst, hflip, vflip)

proc roundTo*[T](a: T, n: T): T =
  ## returns a rounded to the nearest n
  when T is int:
    if a < 0:
      ((a - (n - 1)) div n) * n
    else:
      (a div n) * n

  else:
    if a < 0:
      floor((a - (n - 1)) / n) * n
    else:
      floor(a / n) * n

proc remainder*(a: int, n: int): int =
  ## returns the remainder of a divided by n
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

proc mapDraw*(startTX,startTY, tw,th, dx,dy: Pint, dw,dh: Pint = -1, loop: bool = false, ox,oy: Pint = 0) =
  ## tx,ty = top left tilemap coordinates to draw from
  ## tw,th = how many tiles to draw across and down
  ## dx,dy = position on virtual screen to draw at
  ## dw,dh = draw width, draw height, -1 = as big as map
  ## ox,oy = offset drawing position, useful for parallax

  if currentTilemap == nil:
    raise newException(Exception, "No map set")

  if currentTilemap.hex:
    mapDrawHex(startTX,startTY,tw,th,dx,dy)
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

  dw = min(dw, (dmaxx+1) - dminx)
  dh = min(dh, (dmaxy+1) - dminy)

  let offsetX = dminx - dx - ox
  let offsetY = dminy - dy - oy

  # the first row,col we draw might not be the one specified as it might be offscreen
  var startCol = (offsetX - xincrement + 1) div xincrement
  var startRow = (offsetY - yincrement + 1) div yincrement
  if not loop:
    startCol = max(0, startCol)
    startRow = max(0, startRow)

  let nCols = (dw + xincrement + xincrement - 1) div xincrement
  var endCol = startCol + nCols
  let nRows = (dh + yincrement + yincrement - 1) div yincrement
  var endRow = startRow + nRows
  if not loop:
    endCol = min(endCol, currentTilemap.w - startTX)
    endRow = min(endRow, currentTilemap.h - startTY)

  #echo "nRows: ", nRows, " endRow: ", endRow, " startRow: ", startRow

  #debug "d", dw, dh, "dmin", dminx, dminy, "dmax", dmaxx, dmaxy, "o", offsetX, offsetY, "tstart", startCol, startRow, "tend", endCol, endRow

  #echo "startCol ", startCol, " endCol ", endCol, " xincrement ", xincrement, " nCols ", nCols, " tm.width ", currentTilemap.w

  var count = 0
  for y in startRow..endRow:
    let ty = if loop: startTY + wrap(y, currentTilemap.h) else: startTY + y
    if not loop and ty < 0 or ty > currentTilemap.h - 1:
      continue
    for x in startCol..endCol:
      let tx = if loop: startTX + wrap(x, currentTilemap.w) else: startTX + x
      if not loop and tx < 0 or tx > currentTilemap.w - 1:
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
  ## returns the width of the current map
  return currentTilemap.w

proc mapHeight*(): Pint =
  ## returns the height of the current map
  return currentTilemap.h

proc loadMap*(index: int, filename: string, layer = 0) =
  ## loads map from a Tiled format json file into map slot `index`, extracts specified `layer`
  var tm: Tilemap
  # read tiled output format
  var j: JsonNode
  try:
    j = readJsonFile(joinPath(assetPath,filename))
  except:
    return
  tm.w = j["width"].getBiggestInt.int
  tm.h = j["height"].getBiggestInt.int
  tm.hex = j["orientation"].getStr == "hexagonal"
  tm.tw = j["tilewidth"].getBiggestInt.int
  tm.th = j["tileheight"].getBiggestInt.int
  if tm.hex:
    let hsl = j["hexsidelength"].getBiggestInt.int
    tm.hexOffset = hsl + ((tm.th - hsl) div 2)
  # only look at first layer
  tm.data = newSeq[int](tm.w*tm.h)
  let jLayerData = j["layers"][layer]["data"]
  for i in 0..<(tm.w*tm.h):
    let t = jLayerData[i].getInt()
    # map is stored as 0 = blank, 1 = first tile, so we need to subtract 1 from anything higher than 0
    tm.data[i] = if t > 0: (t-1) else: 0

  tilemaps[index] = tm

proc loadMapObjects*(index: int, filename: string, layer = 0): seq[(float32,float32,string,string)] =
  ## loads map from a Tiled format json file and extracts an object layer and returns a sequence of tuples (x,y,name,type)
  let j = readJsonFile(joinPath(assetPath,filename))
  for jobj in j["layers"][layer]["objects"]:
    result.add((jobj["x"].getFloat().float32, jobj["y"].getFloat().float32, jobj["name"].getStr(), jobj["type"].getStr()))

proc saveMap*(index: int, filename: string) =
  ## saves current map to filename
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
    return ((tx * currentTilemap.tw).Pint, (ty * currentTilemap.th).Pint)

proc newMap*(index: int, w,h: Pint, tw,th: Pint = 8) =
  var tm = tilemaps[index].addr
  tm[].w = w
  tm[].h = h
  tm[].tw = tw
  tm[].th = th
  tm[].data = newSeq[int](w*h)

proc setMap*(index: int) =
  currentTilemap = tilemaps[index].addr

template succWrap*[T](x: T): T =
  ## returns the next value after x, but wraps from T.high to T.low
  if x == T.high:
    T.low
  else:
    x.succ()

template predWrap*[T](x: T): T =
  ## returns the prev value before x, but wraps from T.low to T.high
  if x == T.low:
    T.high
  else:
    x.pred()

template incWrap*[T](x: var T) =
  ## increments x but wraps, good for bools or enums
  if x == T.high:
    x = T.low
  else:
    x.inc()

template decWrap*[T](x: var T) =
  ## decrements x but wraps, good for enums
  if x == T.low:
    x = T.high
  else:
    x.dec()

proc rnd*[T: Natural](x: T): T =
  ## returns a random number from 0..<x, x will never be returned
  return rand(x.int-1).T

proc rnd*(x: Pfloat): Pfloat =
  ## returns a random float from 0..x
  return rand(x)

proc rndbi*[T](x: T): T =
  ## returns a random number between -x..x inclusive
  return rand(x) - rand(x)

proc rnd*[T](min: T, max: T): T =
  ## returns a random number from min..max inclusive
  return rand(max - min) + min

proc rnd*[T](a: openarray[T]): T =
  ## returns a random element of a
  return sample(a)

proc rnd*[T](x: HSlice[T,T]): T =
  ## returns a random element in slice
  return rand(x)

proc srand*(seed: int) =
  ## sets the seed for random number operations
  if seed == 0:
    raise newException(Exception, "Do not srand(0)")
  randomize(seed)

proc srand*() =
  ## sets the seed for random number operations to a random seed
  randomize()

proc getControllers*(): seq[NicoController] =
  ## returns a list of controllers
  return controllers

proc setFont*(fontId: FontId) =
  ## sets the active font to be used by future print calls
  if fontId > fonts.len:
    return
  currentFontId = fontId
  currentFont = fonts[currentFontId]

proc getFont*(): FontId =
  ## gets the current font id
  return currentFontId

proc createWindow*(title: string, w,h: int, scale: int = 2, fullscreen: bool = false) =
  ## creates a new window (nico only supports a single window)
  backend.createWindow(title, w, h, scale, fullscreen)
  clip()

proc hasWindow*(): bool =
  ## returns true if window has been created
  return backend.hasWindow()

export setVSync
export getVSync

proc readFile*(filename: string): string =
  ## returns the contents of filename
  return backend.readFile(filename)

proc readJsonFile*(filename: string): JsonNode =
  ## returns the contents of json file
  return backend.readJsonFile(filename)

proc saveJsonFile*(filename: string, data: JsonNode) =
  ## saves json data to a file
  backend.saveJsonFile(filename, data)

proc flip*() {.inline.} =
  ## puts the contents of the canvas to the screen
  backend.flip()

proc setFullscreen*(fullscreen: bool) =
  ## enable or disable fullscreen mode
  backend.setFullscreen(fullscreen)

proc getFullscreen*(): bool =
  ## returns true if in fullscreen mode
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

  addResizeFunc(proc(w,y: int) = clip())

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
  initFuncCalled = false

proc setUpdateFunc*(update: (proc(dt:float32))) =
  updateFunc = update

proc setDrawFunc*(draw: (proc())) =
  drawFunc = draw

proc setControllerAdded*(cadded: proc(controller: NicoController)) =
  controllerAddedFunc = cadded

proc setControllerRemoved*(cremoved: proc(controller: NicoController)) =
  controllerRemovedFunc = cremoved

proc run*(init: (proc()), update: (proc(dt:float32)), draw: (proc())) =
  echo "run"
  assert(update != nil)
  assert(draw != nil)

  initFunc = init
  initFuncCalled = false
  echo "initFuncCalled = false"
  updateFunc = update
  drawFunc = draw

  if common.running:
    backend.stopLastRun()

  common.running = true
  backend.run()

proc setWritePath*(path: string) =
  ## sets the path for writing data
  if path.endswith("/"):
    writePath = path
  else:
    writePath = path & "/"

proc setAssetPath*(path: string) =
  ## sets the path to use when loading assets
  if path.endswith("/"):
    assetPath = path
  else:
    assetPath = path & "/"

proc setGifScale*(gs: int = 2) =
  gifScale = gs

proc bpm*(newBpm: Natural) =
  ## sets the beats per minute
  currentBpm = newBpm

proc tpb*(newTpb: Natural) =
  ## sets the number of ticks per beat
  currentTpb = newTpb

proc setAudioTickCallback*(callback: proc()) =
  audioTickCallback = callback

proc addKeyListener*(p: KeyListener) =
  ## adds a key listener, this will be called for all key events
  keyListeners.add(p)

proc removeKeyListener*(p: KeyListener) =
  for i,v in keyListeners:
    if v == p:
      keyListeners.del(i)
      break

proc addEventListener*(f: EventListener): EventListener {.discardable.} =
  ## adds an event listeners, this will be called for all events
  eventListeners.add(f)

proc removeEventListener*(f: EventListener) =
  ## removes a specific event listener
  let i = eventListeners.find(f)
  if i != -1:
    eventListeners.del(i)

proc removeAllEventListeners*() =
  ## removes all registed event listeners
  eventListeners = @[]

proc sgn*(x: Pint): Pint =
  ## returns the sign of the input, 0 if input is 0
  if x < 0:
    return -1
  if x >= 0:
    return 1
  else:
    return 0

const DEG2RAD* = PI / 180.0
const RAD2DEG* = 180.0 / PI

template deg2rad*(x: typed): untyped =
  ## converts degrees to radians
  x * DEG2RAD

template rad2deg*(x: typed): untyped =
  ## converts radians to degrees
  x * RAD2DEG

proc invLerp*(a,b,v: Pfloat): Pfloat =
  ## returns the value of v as if a is 0 and b is 1
  (v - a) / (b - a)

proc modSign*[T](a,n: T): T =
  ## returns remainder that uses the sign of the numerator
  return (a mod n + n) mod n

proc angleDiff*(a,b: Pfloat): Pfloat =
  ## returns the nearest difference between two angles in radians
  var r = (b.float - a.float) mod TAU.float
  if r < -PI:
    r += TAU
  if r >= PI:
    r -= TAU
  return r.float32

proc remove*[T](a: var seq[T], v: T) =
  ## remove item with value of v from sequence a
  let i = a.find(v)
  if i != -1:
    a.delete(i)

proc approach*[T](a: var T, b: T, speed: T) =
  if b > a:
    a = min(a + speed, b)
  elif a > b:
    a = max(a - speed, b)

proc approach*[T](a: T, b: T, speed: T): T =
  if b > a:
    return min(a + speed, b)
  elif a > b:
    return max(a - speed, b)

proc approachAngle*(a: var float32, b: float32, speed: float32) =
  let diff = angleDiff(a, b)
  a = a + clamp(diff, -speed, speed)

template timer*(a: typed, body: untyped): untyped =
  if a > 0:
    a -= 1
    if a == 0:
      body

converter toPint*(x: uint8): Pint =
  x.Pint

converter toPfloat*(x: int): Pfloat {.inline.} =
  return x.Pfloat

iterator all*[T](a: var openarray[T]): T {.inline.} =
  let len = a.len
  for i in 0..<len:
    yield a[i]

when defined(test):
  import unittest

  suite "nico":
    proc `~=`(a,b: float32): bool =
      ## approximately equal
      return abs(a-b) < 0.000001f

    test "angleDiff":
      check(angleDiff(0'f,0'f) == 0'f)
      check(angleDiff(deg2rad(90'f),deg2rad(-90'f)) ~= deg2rad(180'f))
      check(angleDiff(deg2rad(-90'f),deg2rad(90'f)) ~= deg2rad(-180'f))
      check(angleDiff(deg2rad(-180'f),deg2rad(180'f)) ~= deg2rad(0'f))
      check(angleDiff(deg2rad(180'f),deg2rad(-180'f)) ~= deg2rad(0'f))

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
      check(roundTo(42f + 45f * 0.5f, 45f) == 45f)
      check(roundTo(3f, 45f) == 0f)

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

    test "approach":
      check(approach(0f, 1f, 0.1f) == 0.1f)
      check(approach(1f, 0f, 0.1f) == 0.9f)
      check(approach(0f, 1f, 1.5f) == 1.0f)
      check(approach(0f, -1f, 1.5f) == -1.0f)

      var a = 0f
      a.approach(1f, 1.5f)
      check(a == 1f)
