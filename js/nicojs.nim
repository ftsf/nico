import dom
import jsconsole
import ajax
import html5_canvas
import random
import math
import json
import strutils

import webaudio

type Pint* = int
type SfxId* = int
type MusicId* = int
type InitFunc = proc()
type UpdateFunc = proc(dt: float)
type DrawFunc = proc()

type ColorId* = range[0..15]
type Rect = tuple
  x,y,w,h: int

type BtnId* = enum
  pcLeft = 0
  pcRight = 1
  pcUp = 2
  pcDown = 3
  pcA = 4
  pcB = 5
  pcX = 6
  pcY = 7
  pcStart = 8
  pcBack = 9

type Surface = object
  width,height: int
  data: seq[uint8]

type Font = object
  width,height: int
  data: seq[uint8]
  rects: seq[Rect]

type Spritesheet = object
  width,height: int
  data: seq[uint8]
  rects: seq[Rect]

type TileMap = object
  width,height: int
  data: seq[uint8]

var basePath*: string
var swCanvas: seq[uint8]
var screenWidth*,screenHeight*: int
var swCanvas32: ImageData
var currentColor: ColorId
var canvas: Canvas

var mouseX,mouseY: int
var mouseButtonsDown: array[3,bool]
var mouseButtons: array[3,int]
var haveMouse: bool

var sfxData: array[64,AudioBuffer]
var musicData: array[64,AudioBuffer]
var currentMusic: AudioBufferSourceNode = nil

var ctx: CanvasRenderingContext2d
var audioContext: AudioContext
var sfxGain,musicGain: GainNode

var cameraX,cameraY = 0

var timeStep* = 1.0/60.0

var tilemap: TileMap

var clipRect: Rect = (0,0,128,128)
var clipMinX = 0
var clipMinY = 0
var clipMaxX = 127
var clipMaxY = 127

var font: Font
var spritesheet: Spritesheet

var paletteTransparent: array[16,bool]
var paletteMapDraw: array[16,ColorId]

for i in 0..15:
  paletteTransparent[i] = false
  paletteMapDraw[i] = i
paletteTransparent[0] = true


var frame* = 0

var initFunc: InitFunc
var updateFunc: UpdateFunc
var drawFunc: DrawFunc

proc makeColor(r,g,b: int): array[3,uint8] =
  return [r.uint8,g.uint8,b.uint8]

var colors = [
  makeColor(0,0,0),
  makeColor(29,43,83),
  makeColor(126,37,83),
  makeColor(0,135,81),
  makeColor(171,82,54),
  makeColor(95,87,79),
  makeColor(194,195,199),
  makeColor(255,241,232),
  makeColor(255,0,77),
  makeColor(255,163,0),
  makeColor(255,240,36),
  makeColor(0,231,86),
  makeColor(41,173,255),
  makeColor(131,118,156),
  makeColor(255,119,168),
  makeColor(255,204,170),
]

proc loadPalettePico8*() =
  colors[0]  = makeColor(0,0,0)
  colors[1]  = makeColor(29,43,83)
  colors[2]  = makeColor(126,37,83)
  colors[3]  = makeColor(0,135,81)
  colors[4]  = makeColor(171,82,54)
  colors[5]  = makeColor(95,87,79)
  colors[6]  = makeColor(194,195,199)
  colors[7]  = makeColor(255,241,232)
  colors[8]  = makeColor(255,0,77)
  colors[9]  = makeColor(255,163,0)
  colors[10] = makeColor(255,240,36)
  colors[11] = makeColor(0,231,86)
  colors[12] = makeColor(41,173,255)
  colors[13] = makeColor(131,118,156)
  colors[14] = makeColor(255,119,168)
  colors[15] = makeColor(255,204,170)

proc loadPaletteArne16*() =
  colors[0]  = makeColor(0,0,0)
  colors[1]  = makeColor(157,157,157)
  colors[2]  = makeColor(255,255,255)
  colors[3]  = makeColor(190,38,51)
  colors[4]  = makeColor(224,111,139)
  colors[5]  = makeColor(73,60,43)
  colors[6]  = makeColor(164,100,34)
  colors[7]  = makeColor(235,137,49)
  colors[8]  = makeColor(247,226,107)
  colors[9]  = makeColor(47,72,78)
  colors[10] = makeColor(68,137,26)
  colors[11] = makeColor(163,206,39)
  colors[12] = makeColor(27,38,50)
  colors[13] = makeColor(0,87,132)
  colors[14] = makeColor(49,162,242)
  colors[15] = makeColor(178,220,239)

var keysDown: array[BtnId,bool]
var keyState: array[BtnId,int]

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

proc rgb*(c: array[3,uint8]): cstring =
  return rgb(c[0].int,c[1].int,c[2].int)

proc setColor*(c: ColorId) =
  currentColor = c

proc getColor*(): ColorId =
  return currentColor

proc pset*(x,y: Pint) {.inline.} =
  let x = x - cameraX
  let y = y - cameraY
  if x < 0 or x > screenWidth - 1 or y < 0 or y > screenHeight - 1:
    return
  swCanvas[y*screenWidth+x] = currentColor

proc pset*(x,y: Pint, c: ColorId) {.inline.} =
  let x = x - cameraX
  let y = y - cameraY

  if x < 0 or x > screenWidth - 1 or y < 0 or y > screenHeight - 1:
    return
  swCanvas[y*screenWidth+x] = c

proc pget*(x,y: Pint): Pint {.inline.} =
  return swCanvas[y*screenWidth+x].Pint

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
    if e2 > (-dx).float:
      err -= dy.float
      x += sx
    if e2 < dy.float:
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

proc cls*() =
  for i in 0..<swCanvas.len:
    swCanvas[i] = 0

proc rectfill*(x,y,w,h: Pint) {.inline.} =
  for y in y..<y+h:
    hline(x,y,x+w-1)

proc rect*(x,y,w,h: Pint) {.inline.} =
  hline(x,y,x+w-1)
  hline(x,y+h-1,x+w-1)
  vline(x,y+1,y+h-2)
  vline(x+w-1,y+1,y+h-2)

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

proc dirname(filename: string): string =
  var index = filename.rfind('/')
  if index != -1:
    return filename[0..index]

proc init*(org, appname: string) =
  let pathname = $dom.window.location.pathname
  basePath = pathname.dirname
  console.log("basePath: ", basePath)

  audioContext = newAudioContext()
  audioContext.resume()

  sfxGain = audioContext.createGain()
  sfxGain.gain.value = 1.0
  musicGain = audioContext.createGain()
  musicGain.gain.value = 1.0
  sfxGain.connect(audioContext.destination)
  musicGain.connect(audioContext.destination)
  console.log(audioContext)

proc setBtn*(b: BtnId, down: bool = true) {.exportc.} =
  keysDown[b] = down

proc btn*(b: BtnId): bool =
  return keyState[b] > 0

proc btnp*(b: BtnId): bool =
  return keyState[b] == 1

proc btnpr*(b: BtnId, r: Pint): bool =
  return keyState[b] mod r == 1

proc mouse*(): (Pint,Pint) =
  return (mouseX,mouseY)

proc mousebtn*(b: range[0..2]): bool =
  return mouseButtons[b] > 0

proc mousebtnp*(b: range[0..2]): bool =
  return mouseButtons[b] == 1

proc mousebtnpr*(b: range[0..2], r: Pint): bool =
  return mouseButtons[b] mod r == 1

proc hasMouse*(): bool =
  return haveMouse

proc srand*(seed: Pint) =
  randomize(seed+1)

proc rnd*[T: Ordinal](x: T): T =
  if x == 0:
    return 0
  return random(x.int).T

proc rnd*(x: float): float =
  return random(x)

proc rnd*[T](a: openarray[T]): T =
  return random(a)

proc setCamera*(x,y: Pint) =
  cameraX = x
  cameraY = y

proc setCamera*() =
  cameraX = 0
  cameraY = 0

proc loadFont*(filename: string, chars: string) =
  var img = dom.document.createElement("img").ImageElement
  img.onload = proc(event: Event) =
    let target = event.target.ImageElement
    console.log("image loaded: ", target.src)
    # need to get the image data from the font
    var canvas = document.createElement("canvas").Canvas
    var ctx = canvas.getContext2D()
    let w = target.width
    let h = target.height
    canvas.width = w
    canvas.height = h
    ctx.drawImage(target, 0, 0)
    var fontData32 = ctx.getImageData(0,0, w.float,h.float)
    font.width = w
    font.height = h
    font.data = newSeq[uint8](w*h)
    for i in 0..<w*h:
      if fontData32.data[i*4+3] == 0:
        font.data[i] = 0
      elif fontData32.data[i*4+0] > 0.uint8:
        font.data[i] = 2
      else:
        font.data[i] = 1

    font.rects = newSeq[Rect](256)

    var newChar = false
    let blankColor = font.data[0]
    var currentRect: Rect = (0,0,0,0)
    var i = 0
    for x in 0..<w:
      let color = font.data[x]
      if color == blankColor:
        currentRect.w = x - currentRect.x
        if currentRect.w != 0:
          # go down until we find blank or h
          currentRect.h = h-1
          for y in 0..<h:
            let color = font.data[y*w+x]
            if color == blankColor:
              currentRect.h = y-2
          let charId = chars[i].int
          font.rects[charId] = currentRect
          i += 1
        newChar = true
        currentRect.x = x + 1

  img.src = basePath & "assets/" & filename

proc mapRGB(r,g,b: uint8): ColorId =
  for i,v in colors:
    if v[0] == r and v[1] == g and v[2] == b:
      return i
  return 0

proc loadSpriteSheet*(filename: string) =
  var img = dom.document.createElement("img").ImageElement
  img.onload = proc(event: Event) =
    console.log("spritesheet loaded: ", img.src)
    let w = img.width
    let h = img.height

    var canvas = document.createElement("canvas").Canvas
    var ctx = canvas.getContext2D()
    canvas.width = w
    canvas.height = h
    ctx.drawImage(img, 0, 0)
    var imgData = ctx.getImageData(0,0, w.float,h.float)

    spritesheet.width = w
    spritesheet.height = h
    spritesheet.data = newSeq[uint8](w*h)
    for y in 0..<h:
      for x in 0..<w:
        let r = imgData.data[(y*w*4)+(x*4)]
        let g = imgData.data[(y*w*4)+(x*4)+1]
        let b = imgData.data[(y*w*4)+(x*4)+2]
        let c = mapRGB(r,g,b)
        spritesheet.data[y*w+x] = c

  img.src = basePath & "assets/" & filename

proc fontBlit(font: Font, srcRect, dstRect: Rect, color: ColorId) =
  let dPitch = screenWidth
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
      if sx.int < 0 or sy.int < 0 or sx.int > font.width or sy.int > font.height:
        continue
      if dx.int < clipMinX or dy.int < clipMinY or dx.int > min(screenWidth,clipMaxX) or dy.int > min(screenHeight,clipMaxY):
        continue
      if font.data[sy.int * font.width + sx.int] == 1:
        swCanvas[dy.int * dPitch + dx.int] = currentColor
      sx += 1.0 * (sw/dw)
      dx += 1.0
    sy += 1.0 * (sh/dh)
    dy += 1.0

proc glyph*(c: char, x,y: Pint, scale: Pint = 1): Pint =
  var src = font.rects[c.int]
  var dst: Rect = (x,y, src.w * scale, src.h * scale)
  fontBlit(font, src, dst, currentColor)
  return src.w * scale + scale

proc print*(text: string, x,y: Pint, scale: Pint = 1) =
  if font.data != nil:
    var x = x - cameraX
    let y = y - cameraY
    for c in text:
      x += glyph(c, x, y, scale)

proc glyphWidth*(c: char, scale: Pint = 1): Pint =
  if font.data == nil:
    return 0
  var src: Rect = font.rects[c.int]
  result += src.w*scale + scale

proc textWidth*(text: string, scale: Pint = 1): Pint =
  if font.data == nil:
    return 0
  for c in text:
    var src: Rect = font.rects[c.int]
    result += src.w*scale + scale

proc printr*(text: string, x,y: Pint, scale: Pint = 1) =
  let width = textWidth(text, scale)
  print(text, x-width, y, scale)

proc printc*(text: string, x,y: Pint, scale: Pint = 1) =
  let width = textWidth(text, scale)
  print(text, x-(width div 2), y, scale)


proc blitFast(sx,sy, dx,dy, w,h: Pint) =
  if spritesheet.data == nil:
    return

  var sxi = sx
  var syi = sy
  var dxi = dx
  var dyi = dy

  while dyi < dy + h:
    if syi < 0 or syi > spritesheet.height-1 or dyi < clipMinY or dyi > min(screenHeight-1,clipMaxY):
      syi += 1
      dyi += 1
      sxi = sx
      dxi = dx
      continue
    while dxi < dx + w:
      if sxi < 0 or sxi > spritesheet.width-1 or dxi < clipMinX or dxi > min(screenWidth-1,clipMaxX):
        # ignore if it goes outside the source size
        dxi += 1
        sxi += 1
        continue
      let srcCol = spritesheet.data[syi * spritesheet.width + sxi]
      if not paletteTransparent[srcCol]:
        swCanvas[dyi * screenWidth + dxi] = paletteMapDraw[srcCol]
      sxi += 1
      dxi += 1
    syi += 1
    dyi += 1
    sxi = sx
    dxi = dx

proc blitStretch(srcRect, dstRect: Rect, hflip, vflip: bool = false) =
  let sPitch = spritesheet.width
  let dPitch = screenWidth

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
      if sx < 0 or sy < 0 or sx.int > spritesheet.width-1 or sy.int > spritesheet.height-1:
        continue
      if not (dx.int < clipMinX or dy.int < clipMinY or dx.int > min(screenWidth,clipMaxX) or dy.int > min(screenHeight,clipMaxY)):
        let srcCol = spritesheet.data[sy.int * sPitch + sx.int]
        if not paletteTransparent[srcCol]:
          swCanvas[dy.int * dPitch + dx.int] = paletteMapDraw[srcCol]
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


proc getSprRect(spr: range[0..255], w,h: Pint = 1): Rect {.inline.} =
  result.x = spr%%16 * 8
  result.y = spr div 16 * 8
  result.w = w * 8
  result.h = h * 8

proc spr*(spr: range[0..255], x,y: Pint, w,h: Pint = 1, hflip, vflip: bool = false) =
  # draw a sprite
  var src = getSprRect(spr, w, h)
  var dst: Rect = (x-cameraX,y-cameraY,src.w,src.h)
  blitFast(src.x, src.y, x-cameraX, y-cameraY, src.w, src.h)

proc sspr*(sx,sy, sw,sh, dx,dy: Pint, dw,dh: Pint = -1, hflip, vflip: bool = false) =
  var src: Rect = (sx,sy,sw,sh)
  let dw = if dw >= 0: dw else: sw
  let dh = if dh >= 0: dh else: sh
  var dst: Rect = (dx-cameraX,dy-cameraY,dw,dh)
  blitStretch(src, dst, hflip, vflip)

proc mset*(tx,ty: Pint, t: uint8) =
  if tx < 0 or tx > tilemap.width - 1 or ty < 0 or ty > tilemap.height:
    return
  tilemap.data[ty * tilemap.width + tx] = t

proc mget*(tx,ty: Pint): uint8 =
  if tx < 0 or tx > tilemap.width - 1 or ty < 0 or ty > tilemap.height:
    return 0
  return tilemap.data[ty * tilemap.width + tx]

proc mapWidth*(): Pint =
  return tilemap.width

proc mapHeight*(): Pint =
  return tilemap.height

proc drawTile(spr: range[0..255], x,y: Pint, tileSize = 8) =
  var src = getSprRect(spr)
  blitFast(src.x, src.y, x-cameraX, y-cameraY, tileSize, tileSize)

proc mapDraw*(tx,ty, tw,th, dx,dy: Pint) =
  # draw map tiles to the screen
  var xi = dx
  var yi = dy
  var increment = 8
  for y in ty..ty+th-1:
    if y >= 0 and y < tilemap.height:
      for x in tx..tx+tw-1:
        if x >= 0  and x < tilemap.width:
          let t = tilemap.data[y * tilemap.width + x]
          if t != 0:
            drawTile(t, xi, yi, increment)
        xi += increment
    yi += increment
    xi = dx

proc copy*(sx,sy,dx,dy,w,h: Pint) =
  let sPitch = screenWidth
  let dPitch = screenWidth

  var sxi = sx
  var syi = sy
  var dxi = dx
  var dyi = dy

  while dyi < dy + h:
    if syi < 0 or syi > screenHeight-1 or dyi < clipMinY or dyi > min(screenHeight-1,clipMaxY):
      syi += 1
      dyi += 1
      sxi = sx
      dxi = dx
      continue
    while dxi < dx + w:
      if sxi < 0 or sxi > screenWidth-1 or dxi < clipMinX or dxi > min(screenWidth-1,clipMaxX):
        # ignore if it goes outside the source size
        dxi += 1
        sxi += 1
        continue
      let srcCol = swCanvas[syi * sPitch + sxi]
      swCanvas[dyi * dPitch + dxi] = srcCol
      sxi += 1
      dxi += 1
    syi += 1
    dyi += 1
    sxi = sx
    dxi = dx

proc loadSfx*(sfx: SfxId, filename: string) =
  console.log("loadSfx", sfx, ": ", filename)
  var xhr = newXMLHttpRequest()
  xhr.open("GET", basePath  & "assets/" & filename, true)
  xhr.responseType = "arraybuffer"
  xhr.onreadystatechange = proc(e: Event) =
    if xhr.readyState == rsDone:
      if xhr.status == 200:
        audioContext.decodeAudioData(xhr.response, proc(buffer: AudioBuffer) =
          sfxData[sfx] = buffer
        , proc() =
          console.log("error decoding audio: ", filename)
        )
        console.log("loaded ok: ", filename)
      else:
        console.log("error loading sfx:", sfx, ":", filename)
  xhr.send()

proc loadMusic*(music: MusicId, filename: string) =
  console.log("music", music, ": ", filename)
  var xhr = newXMLHttpRequest()
  xhr.open("GET", basePath  & "assets/" & filename, true)
  xhr.responseType = "arraybuffer"
  xhr.onreadystatechange = proc(e: Event) =
    if xhr.readyState == rsDone:
      if xhr.status == 200:
        audioContext.decodeAudioData(xhr.response, proc(buffer: AudioBuffer) =
          musicData[music] = buffer
        , proc() =
          console.log("error decoding audio: ", filename)
        )
        console.log("loaded ok: ", filename)
      else:
        console.log("error loading music:", music, ":", filename)
  xhr.send()

proc musicVol*(vol: int) =
  musicGain.gain.value = vol.float / 256.0

proc musicVol*(): int =
  return int(musicGain.gain.value * 256.0)

proc sfxVol*(vol: int) =
  sfxGain.gain.value = vol.float / 256.0

proc sfxVol*(): int =
  return int(sfxGain.gain.value * 256.0)

proc mute*() {.exportc:"mute".} =
  if musicGain.gain.value != 0.0:
    musicGain.gain.value = 0.0
    sfxGain.gain.value = 0.0
  else:
    musicGain.gain.value = 1.0
    sfxGain.gain.value = 1.0

proc sfx*(sfx: SfxId, channel: int = -1) =
  if sfxData[sfx] != nil:
    var source = audioContext.createBufferSource()
    source.buffer = sfxData[sfx]
    source.connect(sfxGain)
    source.start()

proc music*(music: MusicId) =
  if currentMusic != nil:
    currentMusic.stop()
    currentMusic = nil

  if musicData[music] != nil:
    var source = audioContext.createBufferSource()
    source.buffer = musicData[music]
    source.loop = true
    source.connect(musicGain)
    source.start()
    currentMusic = source

proc fadeMusicOut*(ms: int) =
  discard

proc fadeMusicIn*(music: MusicId, ms: int) =
  discard

proc parseFile*(filename: string): JsonNode =
  console.log("parseFile: ", filename)
  var xhr = newXMLHttpRequest()
  xhr.open("GET", filename, false)
  xhr.send()
  if xhr.status == 200:
    return parseJson($xhr.responseText)
  else:
    raise newException(IOError, "unable to open file")

proc updateConfigValue*(section, key, value: string) =
  dom.window.localStorage.setItem(section & ":" & key, value)

proc getConfigValue*(section, key: string): string =
  return $dom.window.localStorage.getItem(section & ":" & key)

proc clearSaveData*() {.exportc:"clearSaveData".} =
  dom.window.localStorage.clear()

proc saveConfig*() =
  discard

proc loadConfig*() =
  discard

proc loadMapFromJson*(filename: string) =
  var xhr = newXMLHttpRequest()
  xhr.onreadystatechange = proc(e: Event) =
    if xhr.readyState == rsDONE:
      if xhr.status == 200:
        console.log("loaded map: ", filename)
        var data = parseJson($xhr.responseText)
        let w = data["width"].getNum.int
        let h = data["height"].getNum.int
        tilemap.width = w
        tilemap.height = h
        # only look at first layer
        tilemap.data = newSeq[uint8](w*h)
        for i in 0..<(w*h):
          let t = data["layers"][0]["data"][i].getNum().uint8 - 1
          let x = i mod w
          let y = i div w
          mset(x,y,t)

  xhr.open("GET", filename)
  xhr.send()


proc step() =
  for i,k in keysDown:
    if k:
      keyState[i] += 1
    else:
      keyState[i] = 0

  for i,b in mouseButtonsDown:
    if b:
      mouseButtons[i] += 1
    else:
      mouseButtons[i] = 0

  if updateFunc != nil:
    updateFunc(1.0/60.0)

  if drawFunc != nil:
    drawFunc()

  # copy swCanvas to canvas
  for i,v in swCanvas:
    swCanvas32.data[i*4] = colors[v][0]
    swCanvas32.data[i*4+1] = colors[v][1]
    swCanvas32.data[i*4+2] = colors[v][2]
    swCanvas32.data[i*4+3] = 255
  ctx.putImageData(swCanvas32,0,0)

  frame += 1

var interval: ref TInterval

proc run*(newInitFunc: InitFunc, newUpdateFunc: UpdateFunc, newDrawFunc: DrawFunc) =
  initFunc = newInitFunc
  updateFunc = newUpdateFunc
  drawFunc = newDrawFunc

  if initFunc != nil:
    initFunc()

  if interval != nil:
    dom.window.clearInterval(interval)
  interval = dom.window.setInterval(step, 1000 div 60)

proc shutdown*() =
  dom.window.clearInterval(interval)

proc createWindow*(title: string, w,h: Pint, scale: Pint = 2) =
  swCanvas = newSeq[uint8](w*h)
  screenWidth = w
  screenHeight = h
  canvas = dom.document.createElement("canvas").Canvas
  canvas.width = w
  canvas.height = h
  canvas.style.width = $(w * scale) & "px"
  canvas.style.height = $(h * scale) & "px"
  canvas.style.cursor = "none"

  canvas.onmousemove = proc(e: Event) =
    haveMouse = true
    let scale = canvas.clientWidth.float / screenWidth.float
    mouseX = (e.offsetX.float / scale).int
    mouseY = (e.offsetY.float / scale).int

  canvas.onmousedown = proc(e: Event) =
    haveMouse = true
    mouseButtonsDown[e.button] = true
    e.preventDefault()

  canvas.onmouseup = proc(e: Event) =
    mouseButtonsDown[e.button] = false
    e.preventDefault()

  canvas.addEventListener("contextmenu") do(e: Event):
    e.preventDefault()

  canvas.addEventListener("touchstart") do(e: Event):
    let e = e.TouchEvent
    mouseButtonsDown[0] = true
    let scale = canvas.clientWidth.float / screenWidth.float
    mouseX = ((e.touches.item(0).pageX - e.target.HtmlElement.offsetLeft).float / scale).int
    mouseY = ((e.touches.item(0).pageY - e.target.HtmlElement.offsetTop).float / scale).int

    e.preventDefault()

  canvas.addEventListener("touchmove") do(e: Event):
    let e = e.TouchEvent
    let scale = canvas.clientWidth.float / screenWidth.float
    mouseX = ((e.touches.item(0).pageX - e.target.HtmlElement.offsetLeft).float / scale).int
    mouseY = ((e.touches.item(0).pageY - e.target.HtmlElement.offsetTop).float / scale).int
    e.preventDefault()

  canvas.addEventListener("touchend") do(e: Event):
    mouseButtonsDown[0] = false
    e.preventDefault()


  var holder = dom.document.getElementById("nicogame")
  if holder != nil:
    holder.appendChild(canvas)
  ctx = canvas.getContext2D()
  swCanvas32 = ctx.getImageData(0,0,w.float,h.float)

  frame = 0

  dom.window.onkeydown = proc(event: Event) =
    if event.keyCode == 27:
      keysDown[pcBack] = true
      event.preventDefault()

    if event.keyCode == 13:
      keysDown[pcStart] = true
      event.preventDefault()

    if event.keyCode == 37:
      keysDown[pcLeft] = true
      event.preventDefault()
    if event.keyCode == 39:
      keysDown[pcRight] = true
      event.preventDefault()
    if event.keyCode == 38:
      keysDown[pcUp] = true
      event.preventDefault()
    if event.keyCode == 40:
      keysDown[pcDown] = true
      event.preventDefault()

    if event.keyCode == 90: # z
      keysDown[pcA] = true
      event.preventDefault()
    if event.keyCode == 88: # x
      keysDown[pcX] = true
      event.preventDefault()
    if event.keyCode == 16: # shift
      keysDown[pcB] = true
      event.preventDefault()
    if event.keyCode == 67: # c
      keysDown[pcY] = true
      event.preventDefault()

  dom.window.onkeyup = proc(event: Event) =
    if event.keyCode == 27:
      keysDown[pcBack] = false
      event.preventDefault()

    if event.keyCode == 13:
      keysDown[pcStart] = false
      event.preventDefault()

    if event.keyCode == 37:
      keysDown[pcLeft] = false
      event.preventDefault()
    if event.keyCode == 39:
      keysDown[pcRight] = false
      event.preventDefault()
    if event.keyCode == 38:
      keysDown[pcUp] = false
      event.preventDefault()
    if event.keyCode == 40:
      keysDown[pcDown] = false
      event.preventDefault()

    if event.keyCode == 90: # z
      keysDown[pcA] = false
      event.preventDefault()
    if event.keyCode == 88: # x
      keysDown[pcX] = false
      event.preventDefault()
    if event.keyCode == 16: # shift
      keysDown[pcB] = false
      event.preventDefault()
    if event.keyCode == 67: # c
      keysDown[pcY] = false
      event.preventDefault()


converter toPint*(x: float): Pint =
  result = x.Pint

when isMainModule:

  var x,y: float
  var xv,yv: float
  var t = 8.0
  var splat: bool

  proc gameInit() =
    x = 64
    y = 64
    xv = 0
    yv = 0
    t = 8.0
    splat = false

  proc gameUpdate(dt: float) =
    splat = false
    t += 0.1
    if t >= 16.0:
      t = 8.0

    if btn(0):
      xv -= 0.1
    if btn(1):
      xv += 0.1
    if btn(2):
      yv -= 0.1
    if btn(3):
      yv += 0.1

    x += xv
    y += yv

    if x < 4.0:
      xv = -xv
      x = 4
      splat = true

    if x > screenWidth.float - 4.0:
      x = screenWidth - 4
      xv = - xv
      splat = true

    if y < 4.0:
      yv = -yv
      y = 4
      splat = true

    if y > screenHeight.float - 4.0:
      y = screenHeight - 4
      yv = - yv
      splat = true

    xv *= 0.95
    yv *= 0.95

  proc gameDraw() =
    if frame == 0 or btnp(5):
      setColor(1)
      rectfill(0,0,128,128)

    palt(0,false)
    palt(5,true)
    spr(0,x.int-7,y.int-7,2,2)
    palt()

    if splat:
      circfill(x,y,8+rnd(3))
      for i in 0..rnd(6):
        circfill(x.int+rnd(32)-16,y.int+rnd(32)-16,2+rnd(3))

    for i in 0..100:
      let x = rnd(128)
      let y = rnd(128)
      var c = pget(x,y)
      if c != 1 or rnd(10) == 0:
        setColor(c)
        pset(x,y+1)


    if rnd(30) == 0:
      let x = rnd(128)
      let y = rnd(128)
      setColor(1)
      circfill(x,y,4+rnd(3))
      for i in 0..rnd(5):
        circfill(x+rnd(16)-8,y+rnd(16)-8,1+rnd(3))

    setColor(7)
    print("HELLO WORLD", 64 - 11 * 2, 64)

  init("nico","test")
  loadPaletteArne16()
  createWindow("test", 128, 128, 5)
  loadFont("assets/font.png", " !\"#$%&'()*+,-./0123456789:;<=>?@abcdefghijklmnopqrstuvwxyz[\\]^_`ABCDEFGHIJKLMNOPQRSTUVWXYZ{:}~")
  loadSpriteSheet("assets/spritesheet.png")
  run(gameInit, gameUpdate, gameDraw)
