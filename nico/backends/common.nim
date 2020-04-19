import math
import tables
import unicode
import hashes
import times
import algorithm
import strutils

import nico/keycodes
export Keycode
export Scancode

# Constants

const maxPaletteSize* = 256
const nAudioChannels* = 16
const deadzone* = int16.high div 2
const gifScale* = 2
const maxPlayers* = 4
const recordingEnabled* = true
const musicBufferSize* = 4096

# TYPES

type Palette* = tuple
  size: int
  data: array[maxPaletteSize, tuple[r,g,b: uint8]]

proc hash*(a: Keycode): Hash =
  var h: Hash = 0
  h = h !& a.cint
  result = !$h

import nico/controller
import nico/ringbuffer

var keysDown* = initTable[Keycode, uint32]() # keysDown[keycode] = numbersOfFramesHeldDown, 1 == first frame held down
var aKeyWasPressed*: bool
var aKeyWasReleased*: bool

type KeyListener* = proc(sym: int, mods: uint16, scancode: int, down: bool): bool

type
  Pint* = int32
  Pfloat* = float32
  ColorId* = int

  Rect* = tuple
    x,y,w,h: int

  Font* = ref object
    rects*: Table[Rune,Rect]
    data*: seq[uint8]
    w*,h*: int

  FontId* = range[0..15]
  MusicId* = range[-1..63]
  SfxId* = range[-1..63]

type AudioChannelId* = range[-2..nAudioChannels.high]

type
  ChannelKind* = enum
    channelNone
    channelSynth
    channelWave
    channelMusic
    channelCallback

  SynthShape* = enum
    synSame = "-"
    synSin = "sin"
    synSqr = "sqr"
    synP12 = "p12"
    synP25 = "p25"
    synSaw = "saw"
    synTri = "tri"
    synNoise = "noi"
    synNoise2 = "met"
    synWav = "wav" # use custom waveform

# low level events
type
  EventKind* = enum
    ekMouseButtonDown
    ekMouseButtonUp
    ekMouseMotion
    ekKeyDown
    ekKeyUp
    ekMouseWheel
    ekTextInput
    ekTextEditing

  Event* = object
    kind*: EventKind
    button*: uint8
    x*,y*: int
    xrel*,yrel*: float32
    keycode*: Keycode
    scancode*: Scancode
    mods*: uint16
    clicks*: uint8
    repeat*: int
    ywheel*: int
    text*: string

  EventListener* = proc(e: Event): bool # takes a single event and returns true if it's handled or false if not

type
  Surface* = ref object
    data*: seq[uint8]
    channels*: int
    w*,h*: int
    tw*,th*: int
    filename*: string

proc set*(s: Surface, x,y: int, v: uint8) =
  if x < 0 or y < 0 or x >= s.w or y >= s.h:
    return
  s.data[y * s.w + x] = v

proc get*(s: Surface, x,y: int): uint8 =
  if x < 0 or y < 0 or x >= s.w or y >= s.h:
    return 0
  return s.data[y * s.w + x]

type
  Tilemap* = object
    data*: seq[uint8]
    w*,h*: int
    hex*: bool
    hexOffset*: int
    tw*,th*: int

type
  LineIterator = iterator(): (Pint,Pint)
  Edge = tuple[xint, xfrac, dxint, dxfrac, dy, life: int]


type ResizeFunc* = proc(x,y: int)

## CONVERTERS

converter toFloat32*(x: float): float32 {.inline.} =
  return x.float32

converter toPint*(x: float): Pint {.inline.} =
  return floor(x).Pint

converter toPint*(x: float32): Pint {.inline.} =
  return floor(x).Pint

converter toPint*(x: int): Pint {.inline.} =
  return x.Pint

converter toPfloat*(x: float): Pfloat {.inline.} =
  return x.Pfloat

## GLOBALS
##

var currentPalette*: Palette

var masterVolume* = 1.0
var sfxVolume* = 1.0
var musicVolume* = 1.0

var sampleRate* = 44100.0
var invSampleRate* = 1.0 / sampleRate

var tickFunc*: proc() = nil

var currentBpm*: Natural = 128
var currentTpb*: Natural = 4

var initialized*: bool
var running*: bool

var keyListeners*: seq[KeyListener] = @[]
var eventListeners*: seq[EventListener] = @[]

var loading*: int # number of resources loading

var cursorX* = 0
var cursorY* = 0

var swCanvas*: Surface

var stencilBuffer*: Surface
type StencilMode* = enum
  stencilAlways,
  stencilEqual,
  stencilLess,
  stencilGreater,
  stencilLEqual,
  stencilGEqual,
  stencilNot,
var stencilMode*: StencilMode
var stencilWrite*: bool
var stencilRef*: uint8

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

var spriteFlags*: array[128, uint8]
var mixerChannels* = 0

var gDitherPattern*: uint16 = 0b1111_1111_1111_1111


var frameRate* = 60
var timeStep* = 1/frameRate
var frameMult* = 1

var basePath*: string # should be the current dir with the app
var assetPath*: string # basepath + "/assets"
var writePath*: string # should be a writable dir

var screenScale* = 4.0
var spritesheets*: array[16,Surface]
var spritesheet*: Surface

var tilemaps*: array[16,Tilemap]
var currentTilemap*: ptr Tilemap

var initFunc*: proc()
var updateFunc*: proc(dt: Pfloat)
var drawFunc*: proc()
var textFunc*: proc(text: string): bool
var resizeFuncs*: seq[ResizeFunc]

var fonts*: array[FontId, Font]
var currentFont*: Font
var currentFontId*: FontId

var frame* = 0

var cameraX*: Pint = 0
var cameraY*: Pint = 0

var paletteMapDraw*: array[maxPaletteSize, ColorId]
var paletteMapDisplay*: array[maxPaletteSize, ColorId]
var paletteTransparent*: array[maxPaletteSize, bool]

for i in 0..<maxPaletteSize:
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
var mouseRawX*,mouseRawY*: int
var mouseRelX*,mouseRelY*: float32
var lastMouseX*,lastMouseY*: int
var lastMouseRawX*,lastMouseRawY*: int
var mouseButtonsDown*: array[3,bool]
var mouseButtons*: array[3,int]
var mouseWheelState*: int

proc lerp*[T](a,b: T, t: Pfloat): T =
  return a + (b - a) * t

proc interpolatedLookup*[T](a: openarray[T], s: Pfloat): T =
  let alpha = s mod 1.0
  let sample = s.int mod a.len
  let nextSample = (sample + 1) mod a.len
  result = lerp(a[sample],a[nextSample],alpha)

proc newSurface*(w,h: int): Surface =
  result = new(Surface)
  result.data = newSeq[uint8](w*h)
  result.w = w
  result.h = h

{.push checks:off.}
proc convertToABGR*(src: Surface, rgbaPixels: pointer, dpitch, w,h: cint) =
  assert(src.w == w and src.h == h)
  var rgbaPixels = cast[ptr array[int.high, uint8]](rgbaPixels)
  for y in 0..h-1:
    for x in 0..w-1:
      let c = currentPalette.data[paletteMapDisplay[src.data[y*src.w+x]]]
      rgbaPixels[y*dpitch+(x*4)] = 255
      rgbaPixels[y*dpitch+(x*4)+1] = c.b
      rgbaPixels[y*dpitch+(x*4)+2] = c.g
      rgbaPixels[y*dpitch+(x*4)+3] = c.r

proc convertToRGBA*(src: Surface, abgrPixels: pointer, dpitch, w,h: cint) =
  var abgrPixels = cast[ptr array[int.high, uint8]](abgrPixels)
  for y in 0..h-1:
    for x in 0..w-1:
      let c = currentPalette.data[paletteMapDisplay[src.data[y*src.w+x]]]
      abgrPixels[y*dpitch+(x*4)] = c.r
      abgrPixels[y*dpitch+(x*4)+1] = c.g
      abgrPixels[y*dpitch+(x*4)+2] = c.b
      abgrPixels[y*dpitch+(x*4)+3] = 255

proc mapRGB*(r,g,b: uint8): ColorId =
  for i,v in currentPalette.data:
    if v[0] == r and v[1] == g and v[2] == b:
      return i
  return 0

proc mapRGBA*(r,g,b,a: uint8): ColorId =
  for i,v in currentPalette.data:
    if a == 0 and i == 0:
      return i
    elif i != 0 and v[0] == r and v[1] == g and v[2] == b:
      return i
  return 0

proc convertToIndexed*(surface: Surface): Surface =
  if surface.channels > 4 or surface.channels < 3:
    raise newException(Exception, "Converting non RGBA surface to indexed")
  result.data = newSeq[uint8](surface.w*surface.h)
  result.w = surface.w
  result.h = surface.h
  result.channels = 1
  if surface.channels == 3:
    for i in 0..<surface.w*surface.h:
      result.data[i] = mapRGB(
        surface.data[i*surface.channels+0],
        surface.data[i*surface.channels+1],
        surface.data[i*surface.channels+2]
      ).uint8
  elif surface.channels == 4:
    for i in 0..<surface.w*surface.h:
      result.data[i] = mapRGBA(
        surface.data[i*surface.channels+0],
        surface.data[i*surface.channels+1],
        surface.data[i*surface.channels+2],
        surface.data[i*surface.channels+3]
      ).uint8

proc RGB*(r,g,b: Pint): tuple[r,g,b: uint8] =
  return (r.uint8,g.uint8,b.uint8)
{.pop.}

type ProfilerNode* = object
  name*: string
  start*: Time
  time*: int64
  count*: int
  parent*: ptr ProfilerNode
  children*: seq[ProfilerNode]

var profileCollect* = true
var profileHistory* = newRingBuffer[ProfilerNode](256)

when defined(profile):
  var rootProfilerNode: ProfilerNode
  var currentProfilerNode: ptr ProfilerNode
  var profilePath: string
  var profileStack*: seq[tuple[name: string, path: string, time: Time]]
  var profileData* = initTable[string,int64](64)
  var profileDataHistory* = initTable[(string,uint8),int64](64)
  var profileFrame: uint8
  var lastProfileStats*: ProfilerNode

  proc sortChildren(n: var ProfilerNode) =
    n.children.sort do(a,b: ProfilerNode) -> int:
      cmp(b.time, a.time)
    for c in n.children.mitems:
      c.sortChildren()

  proc profileBegin*(name: string) =
    if not profileCollect:
      return
    let now = getTime()
    profileStack.add((name, profilePath, now))
    profilePath &= "/" & name

    currentProfilerNode.children.add(ProfilerNode(name: name, start: now, count: 1, parent: currentProfilerNode))
    currentProfilerNode = currentProfilerNode.children[^1].addr

  proc profileEnd*() =
    if not profileCollect:
      return
    let now = getTime()
    #var top = profileStack.pop()
    #if not profileData.hasKey(profilePath):
    #  profileData[profilePath] = 0
    #profileData[profilePath] += (now - top.time).inNanoseconds
    #profilePath = top.path

    currentProfilerNode.time = (now - currentProfilerNode.start).inNanoseconds
    currentProfilerNode = currentProfilerNode.parent

  proc profileStartFrame*() =
    if not profileCollect:
      return

    rootProfilerNode = ProfilerNode(name: "", parent: nil, start: getTime())
    currentProfilerNode = rootProfilerNode.addr
    #profilePath = ""
    #for k,v in profileData:
    #  profileData[k] = 0

  proc profileEndFrame*() =
    if not profileCollect:
      return

    if currentProfilerNode == nil:
      return
    assert(currentProfilerNode == rootProfilerNode.addr)

    let now = getTime()
    currentProfilerNode.time = (now - currentProfilerNode.start).inNanoseconds


    # go through each node and sort siblings by time
    #currentProfilerNode[].sortChildren()

    lastProfileStats = currentProfilerNode[]
    profileHistory.add(currentProfilerNode[])

    proc dumpNode(n: ProfilerNode, depth = 0) =
      echo "  ".repeat(depth), (if n.name == "": "root" else: n.name), ": ", n.time
      for c in n.children:
        dumpNode(c, depth + 1)

    #dumpNode(currentProfilerNode[])

    #var stats = newSeq[tuple[name: string, time: int64]]()
    #for k,v in profileData:
    #  stats.add((k,v))
    #  profileDataHistory[(k,profileFrame)] = v

    #stats.sort do(a,b: tuple[name: string, time: int64]) -> int:
    #  result = cmp(b.time, a.time)

    #result = stats
    profileFrame.inc()
    if profileFrame mod 16 == 0:
      profileFrame = 0

  proc profileGetLastStats*(): ProfilerNode =
    return lastProfileStats

  proc profileGetLastStatsPeak*(): seq[tuple[name: string, time: int64]] =
    var peakTable = initTable[string,int64](64)
    for k,time in profileDataHistory:
      let (key,frame) = k
      if not peakTable.hasKey(key):
        peakTable[key] = 0
      if time > peakTable[key]:
        peakTable[key] = time

    var stats = newSeq[tuple[name: string, time: int64]]()
    for k,v in peakTable:
      stats.add((k,v))

    stats.sort do(a,b: tuple[name: string, time: int64]) -> int:
      result = cmp(b.time, a.time)

    result = stats

else:
  template profileBegin*(name: untyped): untyped =
    discard

  template profileEnd*(): untyped =
    discard

  template profileStartFrame*(): untyped =
    discard

  template profileEndFrame*(): untyped =
    discard

  proc profileGetLastStats*(): seq[tuple[name: string, time: int64]] =
    return @[]

  proc profileGetLastStatsPeak*(): seq[tuple[name: string, time: int64]] =
    return @[]
