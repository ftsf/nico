import dom
import jsconsole
import ajax
import html5_canvas
import math

import common
import nico.controller
import json

import webaudio
var ctx: CanvasRenderingContext2d
var swCanvas32: ImageData
var canvas: Canvas
var interval: ref TInterval
var audioContext: AudioContext

type Channel = object
  kind: ChannelKind
  buffer: AudioBuffer
  callback: proc(samples: seq[float32])
  musicFile: AudioBuffer
  musicIndex: int
  musicBuffer: int
  musicBuffers: array[2,array[musicBufferSize,float32]]

  arp: uint16
  arpSpeed: uint8

  loop: int
  phase: float # or position
  freq: float # or speed
  basefreq: float
  targetFreq: float
  width: float
  pan: float
  shape: SynthShape
  gain: float

  init: range[0..15]
  env: range[-7..7]
  envValue: float32
  envPhase: int
  length: range[0..255]
  vibspeed: range[1..15]
  vibamount: range[0..15]
  glide: range[0..15]

  pchange: range[-127..127]

  trigger: bool
  lfsr: int
  lfsr2: int
  nextClick: int
  outvalue: float32

  priority: float

  wavData: array[32, uint8]

var audioChannels: array[nAudioChannels, Channel]

var tickFunc: proc() = nil


var currentBpm: Natural = 128
var currentTpb: Natural = 4
var sampleRate = 44100.0
var nextTick = 0
var clock: bool
var nextClock = 0

var sfxData: array[64,AudioBuffer]
var musicData: array[64,AudioBuffer]
var currentMusic: AudioBufferSourceNode = nil

var sfxGain,musicGain,masterGain: GainNode

keymap = [
  @[37, 65], # left
  @[39, 68], # right
  @[38, 87], # up
  @[40, 83], # down
  @[90, 89], # A, Y
  @[88], # B
  @[16], # X
  @[67], # Y
  @[70], # L1
  @[71], # L2
  @[86], # R1
  @[66], # R2
  @[13], # Start
  @[27, 8], # Back
]

export convertToConsoleLoggable

template debug*(args: varargs[untyped]) =
  console.log(args)

proc setKeyMap*(newmap: string) =
  discard

proc present*() =
  # copy swCanvas to canvas
  for i,v in swCanvas.data:
    swCanvas32.data[i*4] = colors[v][0]
    swCanvas32.data[i*4+1] = colors[v][1]
    swCanvas32.data[i*4+2] = colors[v][2]
    swCanvas32.data[i*4+3] = 255
  ctx.putImageData(swCanvas32,0,0)

proc createWindow*(title: string, w,h: int, scale: int = 2, fullscreen: bool = false) =
  swCanvas = newSurface(w,h)
  screenWidth = w
  screenHeight = h
  canvas = dom.document.createElement("canvas").Canvas
  canvas.width = w
  canvas.height = h
  canvas.style.width = $(w * scale) & "px"
  canvas.style.height = $(h * scale) & "px"
  canvas.style.cursor = "none"

  canvas.onmousemove = proc(e: Event) =
    mouseDetected = true
    let scale = canvas.clientWidth.float / screenWidth.float
    mouseX = (e.offsetX.float / scale).int
    mouseY = (e.offsetY.float / scale).int

  canvas.onmousedown = proc(e: Event) =
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
    for btn,keys in keymap:
      for key in keys:
        if event.keyCode == key:
          controllers[0].setButtonState(btn, true)
          event.preventDefault()

  dom.window.onkeyup = proc(event: Event) =
    for btn,keys in keymap:
      for key in keys:
        if event.keyCode == key:
          controllers[0].setButtonState(btn, false)
          event.preventDefault()

type FileMode = enum
  fmRead
  fmWrite
  fmReadWrite

proc loadFile*(filename: string, callback: proc(data: string)) =
  loading += 1
  var xhr = newXMLHttpRequest()
  xhr.open("GET", filename, true)
  xhr.send()
  xhr.onreadystatechange = proc(e: Event) =
    if xhr.status == 200:
      loading -= 1
      callback($xhr.responseText)
    else:
      loading -= 1
      raise newException(IOError, "unable to open file: " & filename)

proc readFile*(filename: string): string =
  var xhr = newXMLHttpRequest()
  xhr.open("GET", filename, false)
  xhr.send()
  if xhr.status == 200:
    return $xhr.responseText
  else:
    raise newException(IOError, "unable to open file: " & filename)

proc readJsonFile*(filename: string): JsonNode =
  return parseJson(readFile(filename))

proc loadSurface*(filename: string, callback: proc(surface: Surface)) =
  loading += 1
  var img = dom.document.createElement("img").ImageElement
  img.addEventListener("load") do(event: Event):
    loading -= 1
    let target = event.target.ImageElement
    console.log("image loaded: ", target.src)
    var canvas = document.createElement("canvas").Canvas
    var ctx = canvas.getContext2D()
    let w = target.width
    let h = target.height
    canvas.width = w
    canvas.height = h
    ctx.drawImage(target, 0, 0)
    var imgData = ctx.getImageData(0,0, w.float,h.float)
    var surface: Surface
    surface.w = w
    surface.h = h
    surface.channels = 4
    surface.data = imgData.data
    callback(surface)
  img.src = filename

proc step() =
  if loading > 0:
    debug("loading...", loading)
    # copy swCanvas to canvas
    for i,v in swCanvas.data:
      swCanvas32.data[i*4] = colors[v][0]
      swCanvas32.data[i*4+1] = colors[v][1]
      swCanvas32.data[i*4+2] = colors[v][2]
      swCanvas32.data[i*4+3] = 255
    ctx.putImageData(swCanvas32,0,0)

    frame += 1
    return

  for i,b in mouseButtonsDown:
    if b:
      mouseButtons[i] += 1
    else:
      mouseButtons[i] = 0

  for controller in controllers:
    controller.update()

  if updateFunc != nil:
    updateFunc(1.0/60.0)

  if drawFunc != nil:
    drawFunc()

  # copy swCanvas to canvas
  for i,v in swCanvas.data:
    swCanvas32.data[i*4] = colors[v][0]
    swCanvas32.data[i*4+1] = colors[v][1]
    swCanvas32.data[i*4+2] = colors[v][2]
    swCanvas32.data[i*4+3] = 255
  ctx.putImageData(swCanvas32,0,0)

  frame += 1

when declared(dom.window.localStorage):
  proc updateConfigValue*(section, key, value: string) =
    dom.window.localStorage.setItem(section & ":" & key, value)

  proc getConfigValue*(section, key: string): string =
    return $dom.window.localStorage.getItem(section & ":" & key)

  proc clearSaveData*() {.exportc:"clearSaveData".} =
    dom.window.localStorage.clear()
else:
  proc updateConfigValue*(section, key, value: string) =
    discard

  proc getConfigValue*(section, key: string): string =
    return ""

proc saveConfig*() =
  discard

proc loadConfig*() =
  discard

proc init*(org, app: string) =
  basePath = ""
  assetPath = "assets/"
  writePath = ""

  controllers = newSeq[NicoController]()
  controllers.add(newNicoController(-1))

proc flip*() =
  present()

proc resize*() =
  discard

proc resize*(w,h: int) =
  # TODO adjust canvas size
  discard

proc loadSfx*(sfxId: SfxId, filename: string) =
  loading += 1
  var xhr = newXMLHttpRequest()
  xhr.open("GET", assetPath & filename, true)
  xhr.responseType = "arraybuffer"
  xhr.onreadystatechange = proc(e: Event) =
    if xhr.readyState == rsDone:
      loading -= 1
      if xhr.status == 200:
        audioContext.decodeAudioData(xhr.response, proc(buffer: AudioBuffer) =
          sfxData[sfxId] = buffer
        , proc() =
          debug("loaded sfx")
        )
  xhr.send()

proc loadMusic*(musicId: MusicId, filename: string) =
  loading += 1
  var xhr = newXMLHttpRequest()
  xhr.open("GET", assetPath & filename, true)
  xhr.responseType = "arraybuffer"
  xhr.onreadystatechange = proc(e: Event) =
    if xhr.readyState == rsDone:
      loading -= 1
      if xhr.status == 200:
        audioContext.decodeAudioData(xhr.response, proc(buffer: AudioBuffer) =
          musicData[musicId] = buffer
        , proc() =
          debug("loaded music")
        )
  xhr.send()

proc musicVol*(value: int) =
  musicGain.gain.value = value.float / 256.0

proc musicVol*(): int =
  return int(musicGain.gain.value * 256.0)

proc sfxVol*(value: int) =
  sfxGain.gain.value = value.float / 256.0

proc sfxVol*(): int =
  return int(sfxGain.gain.value * 256.0)

proc mute*() {.exportc:"mute".} =
  if musicGain.gain.value != 0.0:
    musicGain.gain.value = 0.0
    sfxGain.gain.value = 0.0
  else:
    musicGain.gain.value = 1.0
    sfxGain.gain.value = 1.0


proc sfx*(sfxId: SfxId, channel: range[-1..15] = -1, loop: int = 0) =
  if sfxData[sfxId] != nil:
    var source = audioContext.createBufferSource()
    source.buffer = sfxData[sfxId]
    source.connect(sfxGain)
    source.start()

proc getMusic*(channel: int): int =
  ## returns the id of the music currently being played on `channel` or -1 if no music is playing
  return -1

proc music*(musicId: MusicId, channel: int) =
  if currentMusic != nil:
    currentMusic.stop()
    currentMusic = nil

  if musicData[musicId] != nil:
    var source = audioContext.createBufferSource()
    source.buffer = musicData[musicId]
    source.loop = true
    source.connect(musicGain)
    source.start()
    currentMusic = source

proc volume*(channel: int, volume: int) =
  audioChannels[channel].gain = (volume.float / 255.0)

proc pitchbend*(channel: int, changeSpeed: range[-128..128]) =
  audioChannels[channel].pchange = changeSpeed

proc vibrato*(channel: int, speed: range[1..15], amount: range[0..15]) =
  audioChannels[channel].vibspeed = speed
  audioChannels[channel].vibamount = amount

proc glide*(channel: int, glide: range[0..15]) =
  audioChannels[channel].glide = glide

proc wavData*(channel: int): array[32, uint8] =
  return audioChannels[channel].wavData

proc wavData*(channel: int, data: array[32, uint8]) =
  audioChannels[channel].wavData = data

proc pitch*(channel: int, freq: float) =
  audioChannels[channel].targetFreq = freq

proc synthShape*(channel: int, newShape: SynthShape) =
  audioChannels[channel].shape = newShape

proc setTickFunc*(f: proc()) =
  tickFunc = f

proc synth*(channel: int, shape: SynthShape, freq: float, init: range[0..15], env: range[-7..7], length: range[0..255] = 0) =
  if channel > audioChannels.high:
    raise newException(KeyError, "invalid channel: " & $channel)
  audioChannels[channel].kind = channelSynth
  audioChannels[channel].shape = shape
  audioChannels[channel].basefreq = freq
  audioChannels[channel].targetFreq = freq
  audioChannels[channel].trigger = true
  audioChannels[channel].init = init
  audioChannels[channel].env = env
  audioChannels[channel].envPhase = 0
  audioChannels[channel].pchange = 0
  audioChannels[channel].loop = -1
  audioChannels[channel].length = length
  audioChannels[channel].arp = 0x0000
  audioChannels[channel].arpSpeed = 1
  audioChannels[channel].nextClick = 0
  audioChannels[channel].vibamount = 0
  audioChannels[channel].vibspeed = 1
  #if shape == synNoise:
  #  audioChannels[channel].lfsr = 0xfeed

proc arp*(channel: int, arp: uint16, speed: uint8 = 1) =
  audioChannels[channel].arp = arp
  audioChannels[channel].arpSpeed = max(1.uint8, speed)

proc synthUpdate*(channel: int, shape: SynthShape, freq: float) =
  if channel > audioChannels.high:
    raise newException(KeyError, "invalid channel: " & $channel)
  if shape != synSame:
    audioChannels[channel].shape = shape
  audioChannels[channel].freq = freq

proc bpm*(newBpm: Natural) =
  currentBpm = newBpm

proc tpb*(newTpb: Natural) =
  currentTpb = newTpb

proc run*() =
  if interval != nil:
    dom.window.clearInterval(interval)
  interval = dom.window.setInterval(step, 1000 div 60)

proc setScreenSize*(w,h: int) =
  discard

proc setWindowTitle*(title: string) =
  discard

proc setFullscreen*(fullscreen: bool) =
  discard

proc getFullscreen*(): bool =
  return false

