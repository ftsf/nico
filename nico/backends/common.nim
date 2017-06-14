## TYPES

import nico.controller
import nico.ringbuffer

when defined(js):
  type Scancode = int

type
  Pint* = int32
  ColorId* = range[0..15]

  Rect* = tuple
    x,y,w,h: int

  Font* = ref object
    rects*: seq[Rect]
    data*: seq[uint8]
    w*,h*: int

  FontId* = range[0..3]
  MusicId* = range[-1..63]
  SfxId* = range[-1..63]

type
  Surface* = object
    data*: seq[uint8]
    channels*: int
    w*,h*: int

type
  Tilemap* = object
    data*: seq[uint8]
    w*,h*: int

type
  LineIterator = iterator(): (Pint,Pint)
  Edge = tuple[xint, xfrac, dxint, dxfrac, dy, life: int]

type ResizeFunc* = proc(x,y: int)

## CONSTANTS

const deadzone* = int16.high div 2
const gifScale* = 2
const maxPlayers* = 4
const recordingEnabled* = true

## CONVERTERS

converter toPint*(x: float): Pint {.inline.} =
  return x.Pint

converter toPint*(x: float32): Pint {.inline.} =
  return x.Pint

converter toPint*(x: int): Pint {.inline.} =
  return x.Pint

## GLOBALS
##

var initialized*: bool
var running*: bool

var loading*: int # number of resources loading

var swCanvas*: Surface

var targetScreenWidth* = 128
var targetScreenHeight* = 128

var fixedScreenSize* = true
var integerScreenScale* = false

var screenWidth* = 128
var screenHeight* = 128

var screenPaddingX* = 0
var screenPaddingY* = 0

var keymap*: array[NicoButton, seq[int]]

var controllerAddedFunc*: proc(controller: NicoController)
var controllerRemovedFunc*: proc(controller: NicoController)

var controllers*: seq[NicoController]

var focused* = true
var recordSeconds* = 30
var fullSpeedGif* = true

var currentTilemap*: Tilemap

var spriteFlags*: array[128, uint8]
var mixerChannels* = 0


var frameRate* = 60
var timeStep* = 1/frameRate
var frameMult* = 1

var basePath*: string # should be the current dir with the app
var assetPath*: string # basepath + "/assets"
var writePath*: string # should be a writable dir

var screenScale* = 4.0
var spriteSheets*: array[16,Surface]
var spriteSheet*: ptr Surface

var initFunc*: proc()
var updateFunc*: proc(dt:float)
var drawFunc*: proc()
var textFunc*: proc(text: string): bool
var resizeFunc*: ResizeFunc

var fonts*: array[FontId, Font]
var currentFontId*: FontId

var frame* = 0

type NicoColor* = tuple[r,g,b: uint8]

var colors*: array[16, NicoColor]

var cameraX*: Pint = 0
var cameraY*: Pint = 0

var paletteSize*: range[0..16] = 16

var paletteMapDraw*: array[256, ColorId]
var paletteMapDisplay*: array[256, ColorId]
var paletteTransparent*: array[256, bool]

for i in 0..<paletteSize.int:
  paletteMapDraw[i] = i
  paletteMapDisplay[i] = i
  paletteTransparent[i] = if i == 0: true else: false

var currentColor*: ColorId = 0

var keepRunning* = true
var muteAudio* = false


var currentMusicId*: int = -1

var clipMinX*, clipMaxX*, clipMinY*, clipMaxY*: int
var clippingRect*: Rect

var mouseDetected*: bool
var mouseX*,mouseY*: int
var mouseButtonsDown*: array[3,bool]
var mouseButtons*: array[3,int]
var mouseWheelState*: int

when defined(js):
  import jsconsole
  export convertToConsoleLoggable
  template debug*(args: varargs[untyped]) =
    console.log(args)
else:
  proc debug*(args: varargs[string, `$`]) =
    for i, s in args:
      write(stderr, s)
      if i != args.high:
        write(stderr, ", ")
    write(stderr, "\n")

proc newSurface*(w,h: int): Surface =
  result.data = newSeq[uint8](w*h)
  result.w = w
  result.h = h

proc convertToABGR*(src: Surface, rgbaPixels: pointer, dpitch, w,h: cint) =
  assert(src.w == w and src.h == h)
  var rgbaPixels = cast[ptr array[int.high, uint8]](rgbaPixels)
  for y in 0..h-1:
    for x in 0..w-1:
      let c = colors[paletteMapDisplay[src.data[y*src.w+x]]]
      rgbaPixels[y*dpitch+(x*4)] = 255
      rgbaPixels[y*dpitch+(x*4)+1] = c.b
      rgbaPixels[y*dpitch+(x*4)+2] = c.g
      rgbaPixels[y*dpitch+(x*4)+3] = c.r

proc convertToRGBA*(src: Surface, abgrPixels: pointer, dpitch, w,h: cint) =
  var abgrPixels = cast[ptr array[int.high, uint8]](abgrPixels)
  for y in 0..h-1:
    for x in 0..w-1:
      let c = colors[paletteMapDisplay[src.data[y*src.w+x]]]
      abgrPixels[y*dpitch+(x*4)] = c.r
      abgrPixels[y*dpitch+(x*4)+1] = c.g
      abgrPixels[y*dpitch+(x*4)+2] = c.b
      abgrPixels[y*dpitch+(x*4)+3] = 255

proc mapRGB*(r,g,b: uint8): ColorId =
  for i,v in colors:
    if v[0] == r and v[1] == g and v[2] == b:
      return i
  return 0

proc convertToIndexed*(surface: Surface): Surface =
  if surface.channels != 4:
    raise newException(Exception, "Converting non RGBA surface to indexed")
  result.data = newSeq[uint8](surface.w*surface.h)
  result.w = surface.w
  result.h = surface.h
  result.channels = 1
  for i in 0..<surface.w*surface.h:
    result.data[i] = mapRGB(
      surface.data[i*4+0],
      surface.data[i*4+1],
      surface.data[i*4+2],
    )

proc RGB*(r,g,b: Pint): NicoColor =
  return (r.uint8,g.uint8,b.uint8)
