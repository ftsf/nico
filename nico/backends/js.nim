import dom
import jsconsole
import ajax
import html5_canvas
import math
import sequtils
import strformat
import jsffi

import common
import nico/controller
import json

import tables

import webaudio

var ctx: CanvasRenderingContext2d
var swCanvas32: ImageData
var canvas: Canvas
var interval: ref Interval

var audioContext: AudioContext

var noiseBuffer: AudioBuffer
var noiseBuffer2: AudioBuffer

type Channel = object
  kind: ChannelKind
  source: AudioNode
  callback: proc(samples: seq[float32])
  musicId: int

  loop: int
  phase: float32 # or position
  freq: float32 # or speed
  basefreq: float32
  targetFreq: float32
  width: float32
  pan: float32
  shape: SynthShape
  gain: GainNode

  synthData: SynthData
  synthDataIndex: int
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

  priority: float32

  wavData: array[32, uint8]

var audioChannels: array[nAudioChannels, Channel]

var tickFunc: proc() = nil

proc synthSetOsc(self: var Channel)

proc toNicoKeycode(x: int): Keycode =
  var x = x
  if x >= 65 and x <= 90:
    x += 32
  return (Keycode)(x)

var currentBpm: Natural = 128
var currentTpb: Natural = 4

var sfxData: array[64,AudioBuffer]
var musicData: array[64,AudioBuffer]
var currentMusic: AudioBufferSourceNode = nil

var sfxGain, musicGain, masterGain: GainNode

keymap = [
  @[37, 65], # left = arrow, a
  @[39, 68], # right = arrow, d
  @[38, 87], # up = arrow, w
  @[40, 83], # down = arrow, s

  @[90, 78], # A = z, n
  @[88, 77], # B = x, m
  @[67, 72], # X = c, h
  @[86, 74], # Y = v, j

  @[70], # L1, F
  @[71], # L2, G
  @[72], # L3, H

  @[86], # R1, V
  @[66], # R2, B
  @[78], # R3, N

  @[13, 32], # Start
  @[27, 8], # Back
]

template debug*(args: varargs[untyped]) =
  console.log(args)

proc setKeyMap*(newmap: string) =
  discard

proc resize*(displayW,displayH: int)
proc resizeCanvas(w,h: int, scale: int)

proc present*() =
  # copy swCanvas to canvas
  for i,v in swCanvas.data.mpairs:
    swCanvas32.data[i*4] = currentPalette.data[paletteMapDisplay[v]][0]
    swCanvas32.data[i*4+1] = currentPalette.data[paletteMapDisplay[v]][1]
    swCanvas32.data[i*4+2] = currentPalette.data[paletteMapDisplay[v]][2]
    swCanvas32.data[i*4+3] = 255
  ctx.putImageData(swCanvas32,0,0)

proc requestPointerLock(e: Element) {.importjs:"#.requestPointerLock(@)".}
proc requestFullscreen(e: Element) {.importjs:"#.requestFullscreen(@)".}
var requestedFullscreen = false

type WheelEvent = ref object of MouseEvent
  deltaY: int

proc createWindow*(title: string, w,h: int, scale: int = 2, fullscreen: bool = false) =
  targetScreenWidth = w
  targetScreenHeight = h

  document.title = title

  if fixedScreenSize:
    resizeCanvas(targetScreenWidth,targetScreenHeight,scale)
  else:
    resize(dom.window.innerWidth,dom.window.innerHeight)

  dom.window.addEventListener("resize") do(e: dom.Event):
    resize(dom.window.innerWidth, dom.window.innerHeight)

  canvas.onmousemove = proc(e: dom.Event) =
    let e = e.MouseEvent
    mouseDetected = true
    let scale = canvas.clientWidth.float32 / screenWidth.float32
    mouseX = (e.offsetX.float32 / scale).int
    mouseY = (e.offsetY.float32 / scale).int
    mouseRawX = e.offsetX
    mouseRawY = e.offsetY

  canvas.onmousedown = proc(e: dom.Event) =
    let e = e.MouseEvent
    mouseButtonsDown[e.button] = true
    e.preventDefault()

  canvas.addEventListener("wheel", proc(e: dom.Event) =
    let e = WheelEvent(e)
    mouseWheelState = sgn(e.deltaY)
    e.preventDefault()
  )

  canvas.onmouseup = proc(e: dom.Event) =
    let e = e.MouseEvent
    mouseButtonsDown[e.button] = false
    e.preventDefault()

  canvas.addEventListener("contextmenu") do(e: dom.Event):
    e.preventDefault()


  canvas.addEventListener("touchstart") do(e: dom.Event):
    if fullscreen and not requestedFullscreen:
      canvas.requestFullscreen()

    let e = e.TouchEvent
    e.preventDefault()
    let scale = canvas.clientWidth.float32 / screenWidth.float32
    if touchMouseEmulation:
      mouseButtonsDown[0] = true
      mouseX = ((e.touches[0].pageX - e.target.offsetLeft).float32 / scale).int
      mouseY = ((e.touches[0].pageY - e.target.offsetTop).float32 / scale).int

    for t in e.changedTouches:
      let sx = (t.pageX - e.target.offsetLeft).float32
      let sy = (t.pageY - e.target.offsetTop).float32

      touches.add(common.Touch(
        state: tsStarted,
        id: t.identifier,
        sx: sx,
        sy: sy,
        x: (sx / scale).int,
        y: (sy / scale).int,
        xrel: 0'f,
        yrel: 0'f,
        xrelraw: 0'f,
        yrelraw: 0'f,
      ))

  canvas.addEventListener("touchmove") do(e: dom.Event):
    let e = e.TouchEvent
    e.preventDefault()
    let scale = canvas.clientWidth.float32 / screenWidth.float32
    if touchMouseEmulation:
      mouseX = ((e.touches[0].pageX - e.target.offsetLeft).float32 / scale).int
      mouseY = ((e.touches[0].pageY - e.target.offsetTop).float32 / scale).int

    for t in e.changedTouches:
      for et in touches.mitems:
        if et.id == t.identifier:
          if et.state notin [tsStarted,tsEnded,tsCancelled]:
            et.state = tsMoved
          let sx = (t.pageX - e.target.offsetLeft).float32
          let sy = (t.pageY - e.target.offsetTop).float32
          et.xrelraw = sx - et.sx
          et.yrelraw = sy - et.sy
          et.xrel = (sx - et.sx) / scale
          et.yrel = (sy - et.sy) / scale
          et.sx = sx
          et.sy = sy
          et.x = (sx / scale).int
          et.y = (sy / scale).int
          break

  canvas.addEventListener("touchend") do(e: dom.Event):
    let e = e.TouchEvent
    let scale = canvas.clientWidth.float32 / screenWidth.float32
    e.preventDefault()
    if touchMouseEmulation:
      mouseButtonsDown[0] = false

    for t in e.changedTouches:
      for et in touches.mitems:
        if et.id == t.identifier:
          et.state = tsEnded
          let sx = (t.pageX - e.target.offsetLeft).float32
          let sy = (t.pageY - e.target.offsetTop).float32
          et.sx = sx
          et.sy = sy
          et.xrelraw = sx - et.sx
          et.yrelraw = sy - et.sy
          et.xrel = (sx - et.sx) / scale
          et.yrel = (sy - et.sy) / scale
          et.x = (sx / scale).int
          et.y = (sy / scale).int
          break

  canvas.addEventListener("touchcancel") do(e: dom.Event):
    let e = e.TouchEvent
    e.preventDefault()
    let scale = canvas.clientWidth.float32 / screenWidth.float32
    if touchMouseEmulation:
      mouseButtonsDown[0] = false

    for t in e.changedTouches:
      for et in touches.mitems:
        if et.id == t.identifier:
          et.state = tsCancelled
          let sx = t.pageX - e.target.offsetLeft
          let sy = t.pageY - e.target.offsetTop
          et.xrelraw = (sx - et.sx).float32
          et.yrelraw = (sy - et.sy).float32
          et.xrel = (sx - et.sx).float32 / scale
          et.yrel = (sy - et.sy).float32 / scale
          et.x = (sx.float32 / scale).int
          et.y = (sy.float32 / scale).int
          break

  var holder = dom.document.getElementById("nicogame")
  if holder != nil:
    holder.appendChild(canvas)
  frame = 0

  dom.window.onkeydown = proc(event: dom.Event) =
    let event = event.KeyboardEvent
    for btn,keys in keymap:
      for key in keys:
        if event.keyCode == key:
          if controllers[0].buttons[btn] <= 0:
            controllers[0].setButtonState(btn, true)
          event.preventDefault()
    if not keysDown.hasKey(toNicoKeycode(event.keyCode)) or keysDown[toNicoKeycode(event.keyCode)] == 0.uint32:
      keysDown[toNicoKeycode(event.keyCode)] = 1.uint32

  dom.window.onkeyup = proc(event: dom.Event) =
    let event = event.KeyboardEvent
    for btn,keys in keymap:
      for key in keys:
        if event.keyCode == key:
          controllers[0].setButtonState(btn, false)
          event.preventDefault()
    keysDown[toNicoKeycode(event.keyCode)] = 0.uint32

type FileMode = enum
  fmRead
  fmWrite
  fmReadWrite

proc loadFile*(filename: string, callback: proc(data: string)) =
  loading += 1
  var xhr = newXMLHttpRequest()
  xhr.open("GET", filename, true)
  xhr.send()
  xhr.onreadystatechange = proc(e: dom.Event) =
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

proc loadSurfaceRGBA*(filename: string, callback: proc(surface: Surface)) =
  loading += 1
  var img = dom.document.createElement("img").ImageElement
  img.addEventListener("load") do(event: dom.Event):
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
    var imgData = ctx.getImageData(0,0, w.float32,h.float32)
    var surface = newSurfaceRGBA(w,h)
    surface.filename = filename
    surface.data = imgData.data
    callback(surface)

  img.addEventListener("error") do(event: dom.Event):
    callback(nil)

  img.src = filename

proc loadSurfaceIndexed*(filename: string, callback: proc(surface: Surface)) =
  loadSurfaceRGBA(filename) do(surface: Surface):
    callback(surface.convertToIndexed())

proc resetChannel(self: var Channel) =
  if self.source != nil:
    self.source.disconnect()
    try:
      self.source.stop()
    except:
      discard
    self.source = nil
  self.kind = channelNone

proc audioClock(self: var Channel) =
  case self.kind:
  of channelNone:
    discard
  of channelSynth:
    if self.length > 0:
      self.length -= 1
      if self.length == 0:
        self.resetChannel()
        return

    if self.synthDataIndex >= 0:
      let i = self.synthDataIndex div (self.synthData.speed.int + 1)
      if i < self.synthData.length.int:
        self.shape = self.synthData.steps[i].shape
        self.basefreq = note(self.synthData.steps[i].note.int)
        self.targetFreq = self.basefreq
        self.freq = self.basefreq
        self.trigger = true
        self.init = self.synthData.steps[i].volume
        self.env = 0
        self.envPhase = 0
        self.pchange = 0
        self.synthDataIndex += 1
        self.synthSetOsc()
      else:
        # reached end of data
        if self.synthData.loop > 0:
          if self.synthData.loop != 15:
            # if not looping forever
            self.synthData.loop.dec()
          if self.synthData.loop > 0:
            self.synthDataIndex = 0
        else:
          self.resetChannel()

    if self.glide == 0:
      self.freq = self.targetFreq
    else:
      self.freq = lerp(self.freq, self.targetFreq, 1.0 - (self.glide.float32 / 16.0))

    self.envPhase += 1

    if self.pchange != 0:
      self.targetFreq = self.targetFreq + self.targetFreq * self.pchange.float32 / 128.0

      if self.targetFreq > sampleRate / 2.0:
        self.targetFreq = sampleRate / 2.0

      self.basefreq = self.targetFreq
      self.freq = self.targetFreq


    if self.vibamount > 0:
      self.targetFreq = self.basefreq + sin(self.envPhase.float32 / self.vibspeed.float32) * self.basefreq * 0.03'f * self.vibamount.float32

    if self.source != nil:
      try:
        OscillatorNode(self.source).frequency.value = self.freq
      except:
        try:
          AudioBufferSourceNode(self.source).playbackRate.value = self.freq / 1000.0'f
        except:
          discard
    if self.env < 0:
      self.envValue = clamp(lerp(self.init.float32 / 15.0'f, 0, self.envPhase / (-self.env * 4)), 0.0'f, 1.0'f)
      if self.envValue <= 0:
        self.resetChannel()
        return
    elif self.env > 0:
      # attack
      self.envValue = clamp(lerp(self.init.float32 / 15.0'f, 1.0'f, self.envPhase / (self.env * 4)), 0.0'f, 1.0'f)
    elif self.env == 0:
      self.envValue = self.init.float32 / 15.0'f

    self.gain.gain.value = clamp(lerp(self.gain.gain.value, self.envValue, 0.9), 0.0, 1.0)
  else:
    discard

proc audioClock() =
  if audioContext != nil:
    sfxGain.gain.value = sfxVolume
    musicGain.gain.value = musicVolume
    masterGain.gain.value = masterVolume

    for channel in mitems(audioChannels):
      channel.audioClock()

proc step() =
  if loading > 0:
    debug("loading...", loading)
    # copy swCanvas to canvas
    present()

    frame += 1
    return

  mouseRelX = (mouseRawX - lastMouseRawX).float32 / screenScale.float32
  mouseRelY = (mouseRawY - lastMouseRawY).float32 / screenScale.float32

  for i,b in mouseButtonsDown:
    if b:
      mouseButtons[i] += 1
    else:
      if mouseButtons[i] > 0:
        mouseButtons[i] = -1
      else:
        mouseButtons[i] = 0

  for controller in controllers:
    controller.update()

  if updateFunc != nil:
    updateFunc(timeStep)

  if drawFunc != nil:
    drawFunc()

  for k,v in keysDown:
    if v.int > 0:
      keysDown[k] += 1

  lastMouseRawX = mouseRawX
  lastMouseRawY = mouseRawY

  for touch in touches.mitems:
    if touch.state == tsStarted or touch.state == tsMoved:
      touch.state = tsHeld

  touches.keepItIf(it.state notin [tsEnded, tsCancelled])

  present()

  audioClock()

  mouseWheelState = 0

  frame += 1

proc updateConfigValue*(section, key, value: string) =
  var win = dom.window
  var ls = win.localStorage
  ls.setItem(fmt"{section}:{key}", value)

proc getConfigValue*(section, key: string): string =
  var win = dom.window
  var ls = win.localStorage
  let data = ls.getItem(fmt"{section}:{key}")
  if data.isNull or data.isUndefined:
    return ""
  else:
    return $data

proc clearSaveData*() {.exportc:"clearSaveData".} =
  dom.window.localStorage.clear()

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

  try:
    audioContext = newAudioContext()
  except JsTypeError:
    audioContext = nil

  if audioContext != nil:
    echo "audioContext established"
    sfxGain = audioContext.createGain();
    sfxGain.gain.value = 1.0
    musicGain = audioContext.createGain();
    musicGain.gain.value = 1.0
    masterGain = audioContext.createGain();
    masterGain.gain.value = 1.0

    connect(sfxGain, masterGain)
    connect(musicGain, masterGain)
    connect(masterGain, audioContext.destination)

    for c in mitems(audioChannels):
      c.gain = audioContext.createGain()
      c.gain.gain.value = 1.0
  else:
    echo "no audioContext"

proc flip*() =
  present()

proc resize*(displayW,displayH: int) =
  echo "display ", displayW, " x ", displayH
  echo "canvas target size ", targetScreenWidth, " x ", targetScreenHeight
  screenScale = max(1'f, min((displayW.float32 / targetScreenWidth.float32).floor, (displayH.float32 / targetScreenHeight.float32).floor))
  echo "scale ", screenScale

  if fixedScreenSize:
    var canvasW = targetScreenWidth
    var canvasH = targetScreenHeight
    resizeCanvas(canvasW,canvasH,screenScale.int)
  else:
    screenWidth = displayW div screenScale.int
    screenHeight = displayH div screenScale.int
    resizeCanvas(screenWidth,screenHeight,screenScale.int)

proc resize*() =
  resize(dom.window.innerWidth,dom.window.innerHeight)

proc resizeCanvas(w,h: int, scale: int) =
  echo "resizing canvas to ", w, " x ", h, " at scale ", scale
  swCanvas = newSurface(w,h)
  screenWidth = w
  screenHeight = h
  screenScale = scale.float32
  if canvas == nil:
    canvas = dom.document.createElement("canvas").Canvas
  canvas.width = w
  canvas.height = h
  canvas.style.width = $(w * scale) & "px"
  canvas.style.height = $(h * scale) & "px"

  ctx = canvas.getContext2D()
  swCanvas32 = ctx.getImageData(0,0,w.float32,h.float32)

  stencilBuffer = newSurface(w, h)

proc initNoiseBuffer(samples: int, freq: float32): AudioBuffer =
  var b = audioContext.createBuffer(1, samples, sampleRate.int)
  var data = b.getChannelData(0)

  var nextClick = 0

  var outputValue = 0.0

  var lfsr = 0xfeed
  for i in 0..<samples:
    let lsb: uint = (lfsr and 1).uint
    lfsr = lfsr shr 1
    if lsb == 1:
      lfsr = lfsr xor 0xb400
    outputValue = if lsb == 1: 1.0 else: -1.0
    nextClick -= 1
    if nextClick <= 0:
      nextClick = ((1.0 / freq) * sampleRate).int

    data[i] = outputValue

  return b

proc loadSfx*(sfxId: SfxId, filename: string) =
  if audioContext == nil:
    return
  loading += 1
  var xhr = newXMLHttpRequest()
  xhr.open("GET", assetPath & filename, true)
  xhr.responseType = "arraybuffer"
  xhr.onreadystatechange = proc(e: dom.Event) =
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
  if audioContext == nil:
    return
  loading += 1
  var xhr = newXMLHttpRequest()
  xhr.open("GET", assetPath & filename, true)
  xhr.responseType = "arraybuffer"
  xhr.onreadystatechange = proc(e: dom.Event) =
    if xhr.readyState == rsDone:
      loading -= 1
      if xhr.status == 200:
        audioContext.decodeAudioData(xhr.response, proc(buffer: AudioBuffer) =
          musicData[musicId] = buffer
        , proc() =
          debug("loaded music")
        )
  xhr.send()

proc mute*() {.exportc:"mute".} =
  if audioContext == nil:
    return
  if masterGain.gain.value != 0.0:
    echo "muting audio"
    masterGain.gain.value = 0.0
  else:
    echo "unmuting audio"
    masterGain.gain.value = 1.0

proc sfx*(channel: AudioChannelId = audioChannelAuto, sfxId: SfxId, loop: int = 0) =
  if audioContext == nil:
    return
  if sfxData[sfxId] != nil:
    if audioChannels[channel].source != nil:
      audioChannels[channel].resetChannel()

    var source = audioContext.createBufferSource()
    source.buffer = sfxData[sfxId]
    source.connect(sfxGain)
    source.start()
    audioChannels[channel].source = source

proc getMusic*(channel: AudioChannelId): int =
  if audioContext == nil:
    return -1
  return audioChannels[channel].musicId

proc music*(channel: AudioChannelId, musicId: MusicId, loop: int = -1) =
  if audioContext == nil:
    return
  if audioChannels[channel].source != nil:
    audioChannels[channel].source.stop()
    audioChannels[channel].source = nil
    audioChannels[channel].musicId = -1


  if musicId != -1 and musicData[musicId] != nil:
    var source = audioContext.createBufferSource()
    source.buffer = musicData[musicId]
    source.loop = true
    source.connect(musicGain)
    source.start()
    audioChannels[channel].source = source
    audioChannels[channel].musicId = musicId

proc volume*(channel: AudioChannelId, volume: int) =
  if audioContext == nil:
    return

  audioChannels[channel].gain.gain.value = (volume.float32 / 255.0)

proc pitchbend*(channel: AudioChannelId, changeSpeed: range[-128..128]) =
  if audioContext == nil:
    return

  audioChannels[channel].pchange = changeSpeed

proc vibrato*(channel: AudioChannelId, speed: range[1..15], amount: range[0..15]) =
  if audioContext == nil:
    return

  audioChannels[channel].vibspeed = speed
  audioChannels[channel].vibamount = amount

proc glide*(channel: AudioChannelId, glide: range[0..15]) =
  if audioContext == nil:
    return

  audioChannels[channel].glide = glide

proc wavData*(channel: AudioChannelId): array[32, uint8] =
  if audioContext == nil:
    return

  return audioChannels[channel].wavData

proc wavData*(channel: AudioChannelId, data: array[32, uint8]) =
  if audioContext == nil:
    return

  audioChannels[channel].wavData = data

proc pitch*(channel: AudioChannelId, freq: float32) =
  if audioContext == nil:
    return

  audioChannels[channel].targetFreq = freq

proc synthShape*(channel: AudioChannelId, newShape: SynthShape) =
  if audioContext == nil:
    return

  audioChannels[channel].shape = newShape

proc synthSetOsc(self: var Channel) =
  if audioContext == nil:
    return

  if self.source != nil:
    self.source.stop()

  if self.shape == synNoise or self.shape == synNoise2:
    when true:
      var osc = audioContext.createBufferSource()

      if self.shape == synNoise:
        if noiseBuffer == nil:
          noiseBuffer = initNoiseBuffer(4096, 1000.0)
        osc.buffer = noiseBuffer
      elif self.shape == synNoise2:
        if noiseBuffer2 == nil:
          noiseBuffer2 = initNoiseBuffer(128, 1000.0)
        osc.buffer = noiseBuffer2

      self.source = osc
      osc.loop = true
  else:
    var osc = audioContext.createOscillator();
    osc.`type` = case self.shape:
    of synSin: "sine"
    of synSqr: "square"
    #of synP12: "custom"
    #of synP25: "custom"
    of synSaw: "sawtooth"
    of synTri: "triangle"
    else:
      "sine"

    osc.frequency.value = self.freq

    if self.shape == synP12:
      let d = 0.125
      var real: array[32, float]
      var imag: array[32, float]
      real[0] = d
      imag[0] = 0.0
      for i in 1..<32:
        real[i] = (2.0 / (i.float * PI)) * sin(i.float * PI * d)
        imag[i] = 0.0
      var p = audioContext.createPeriodicWave(real, imag)
      osc.setPeriodicWave(p)

    elif self.shape == synP25:
      let d = 0.25
      var real: array[32, float]
      var imag: array[32, float]
      real[0] = d
      imag[0] = 0.0
      for i in 1..<32:
        real[i] = (2.0 / (i.float * PI)) * sin(i.float * PI * d)
        imag[i] = 0.0
      var p = audioContext.createPeriodicWave(real, imag)
      osc.setPeriodicWave(p)

    self.source = osc

  self.source.start()
  connect(self.source, self.gain)
  connect(self.gain, sfxGain)

proc synth*(channel: AudioChannelId, shape: SynthShape, freq: float32, init: range[0..15], env: range[-7..7], length: range[0..255] = 0) =
  if audioContext == nil:
    return

  if channel > audioChannels.high:
    raise newException(KeyError, "invalid channel: " & $channel)

  audioChannels[channel].resetChannel()

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
  audioChannels[channel].nextClick = 0
  audioChannels[channel].vibamount = 0
  audioChannels[channel].vibspeed = 1
  audioChannels[channel].synthDataIndex = -1

  audioChannels[channel].synthSetOsc()


proc synth*(channel: AudioChannelId, synthData: SynthData) =
  if channel > audioChannels.high:
    raise newException(KeyError, "invalid channel: " & $channel)
  audioChannels[channel].kind = channelSynth
  audioChannels[channel].synthData = synthData
  audioChannels[channel].synthDataIndex = 0
  audioChannels[channel].loop = synthData.loop.int
  audioChannels[channel].trigger = true
  audioChannels[channel].synthSetOsc()

proc synth*(channel: AudioChannelId, synthString: string) =
  let sd = synthDataFromString(synthString)
  synth(channel, sd)
  audioChannels[channel].synthSetOsc()

proc synthIndex*(channel: AudioChannelId): int =
  return audioChannels[channel].synthDataIndex div (audioChannels[channel].synthData.speed.int+1)

proc synthUpdate*(channel: AudioChannelId, shape: SynthShape, freq: float32) =
  if audioContext == nil:
    return

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
  interval = dom.window.setInterval(step, (timeStep * 1000.0).int)

proc setScreenSize*(w,h: int) =
  discard

proc setWindowTitle*(title: string) =
  document.title = title

proc setFullscreen*(fullscreen: bool) =
  discard

proc getFullscreen*(): bool =
  return false

proc addKeyListener*(f: KeyListener) =
  return

proc removeKeyListener*(f: KeyListener) =
  return

proc hideMouse*() =
  canvas.style.cursor = "none"

proc showMouse*() =
  canvas.style.cursor = "default"

proc errorPopup*(title: string, message: string) =
  echo "ERROR: ", title," : ", message
  dom.window.alert(title & "\n" & message)

when not declared(dom.window.document.ClipboardEvent):
  type ClipboardEvent {.importc.} = ref object of dom.Event

  proc newClipboardEvent(kind: string, options: JsObject = nil): ClipboardEvent {.importjs:"new ClipboardEvent(@)".}

proc setClipboardText*(text: string) =
  var options = newJsObject()
  options["dataType"] = "text/plain"
  options["data"] = text
  let copyEvent = newClipboardEvent("copy", options)
  dom.window.document.dispatchEvent(copyEvent)
