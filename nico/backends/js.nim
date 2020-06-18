import dom
import jsconsole
import ajax
import html5_canvas
import math

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
  gain: GainNode

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

  @[90], # A = z
  @[88], # B = x
  @[67], # X = c
  @[86], # Y = v

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

proc present*() =
  # copy swCanvas to canvas
  for i,v in swCanvas.data.mpairs:
    swCanvas32.data[i*4] = currentPalette.data[paletteMapDisplay[v]][0]
    swCanvas32.data[i*4+1] = currentPalette.data[paletteMapDisplay[v]][1]
    swCanvas32.data[i*4+2] = currentPalette.data[paletteMapDisplay[v]][2]
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

  canvas.onmousemove = proc(e: dom.Event) =
    let e = e.MouseEvent
    mouseDetected = true
    let scale = canvas.clientWidth.float / screenWidth.float
    mouseX = (e.offsetX.float / scale).int
    mouseY = (e.offsetY.float / scale).int

  canvas.onmousedown = proc(e: dom.Event) =
    let e = e.MouseEvent
    mouseButtonsDown[e.button] = true
    e.preventDefault()

  canvas.onmouseup = proc(e: dom.Event) =
    let e = e.MouseEvent
    mouseButtonsDown[e.button] = false
    e.preventDefault()

  canvas.addEventListener("contextmenu") do(e: dom.Event):
    e.preventDefault()

  canvas.addEventListener("touchstart") do(e: dom.Event):
    let e = e.TouchEvent
    mouseButtonsDown[0] = true
    let scale = canvas.clientWidth.float / screenWidth.float
    mouseX = ((e.touches[0].pageX - e.target.offsetLeft).float / scale).int
    mouseY = ((e.touches[0].pageY - e.target.offsetTop).float / scale).int

    e.preventDefault()

  canvas.addEventListener("touchmove") do(e: dom.Event):
    let e = e.TouchEvent
    let scale = canvas.clientWidth.float / screenWidth.float
    mouseX = ((e.touches[0].pageX - e.target.offsetLeft).float / scale).int
    mouseY = ((e.touches[0].pageY - e.target.offsetTop).float / scale).int
    e.preventDefault()

  canvas.addEventListener("touchend") do(e: dom.Event):
    mouseButtonsDown[0] = false
    e.preventDefault()


  var holder = dom.document.getElementById("nicogame")
  if holder != nil:
    holder.appendChild(canvas)
  ctx = canvas.getContext2D()
  swCanvas32 = ctx.getImageData(0,0,w.float,h.float)

  stencilBuffer = newSurface(w, h)

  frame = 0

  dom.window.onkeydown = proc(event: dom.Event) =
    let event = event.KeyboardEvent
    for btn,keys in keymap:
      for key in keys:
        if event.keyCode == key:
          if controllers[0].buttons[btn] <= 0:
            controllers[0].setButtonState(btn, true)
          event.preventDefault()
    if keysDown[toNicoKeycode(event.keyCode)] == 0.uint32:
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
    var imgData = ctx.getImageData(0,0, w.float,h.float)
    var surface = newSurfaceRGBA(w,h)
    surface.filename = filename
    surface.data = imgData.data
    callback(surface)
  img.src = filename

proc loadSurfaceIndexed*(filename: string, callback: proc(surface: Surface)) =
  loadSurfaceRGBA(filename) do(surface: Surface):
    callback(surface.convertToIndexed())

proc stop(self: var Channel) =
  if self.source != nil:
    self.source.disconnect()
    try:
      self.source.stop()
    except:
      discard
    self.source = nil
  self.kind = channelNone

proc process(self: var Channel) =
  case self.kind:
  of channelNone:
    discard
  of channelSynth:
    if self.length > 0:
      self.length -= 1
      if self.length == 0:
        self.stop()
        return

    if self.glide == 0:
      self.freq = self.targetFreq
    else:
      self.freq = lerp(self.freq, self.targetFreq, 1.0 - (self.glide.float32 / 16.0))

    self.envPhase += 1

    if self.pchange != 0:
      self.targetFreq = self.targetFreq + self.targetFreq * self.pchange.float / 128.0

      if self.targetFreq > sampleRate / 2.0:
        self.targetFreq = sampleRate / 2.0

      self.basefreq = self.targetFreq
      self.freq = self.targetFreq


    if self.vibamount > 0:
      self.targetFreq = self.basefreq + sin(self.envPhase.float / self.vibspeed.float) * self.basefreq * 0.03 * self.vibamount.float

    if self.arp != 0:
      let a0 = (self.arp and 0x000f)
      let a1 = (self.arp and 0x00f0) shr 4
      let a2 = (self.arp and 0x0f00) shr 8
      let a3 = (self.arp and 0xf000) shr 12
      var arpSteps = 0
      if a3 != 0:
        arpSteps = 5
      elif a2 != 0:
        arpSteps = 4
      elif a1 != 0:
        arpSteps = 3
      elif a0 != 0:
        arpSteps = 2
      else:
        arpSteps = 1

      if arpSteps > 0:
        if (self.envPhase / self.arpSpeed.int) mod arpSteps == 1:
          self.targetFreq = self.basefreq + self.basefreq * 0.06 * a0.float
        elif (self.envPhase / self.arpSpeed.int) mod arpSteps == 2:
          self.targetFreq = self.basefreq + self.basefreq * 0.06 * a1.float
        elif (self.envPhase / self.arpSpeed.int) mod arpSteps == 3:
          self.targetFreq = self.basefreq + self.basefreq * 0.06 * a2.float
        elif (self.envPhase / self.arpSpeed.int) mod arpSteps == 4:
          self.targetFreq = self.basefreq + self.basefreq * 0.06 * a3.float
        else:
          self.targetFreq = self.basefreq

    if self.source != nil:
      try:
        OscillatorNode(self.source).frequency.value = self.freq
      except:
        try:
          AudioBufferSourceNode(self.source).playbackRate.value = self.freq / 1000.0
        except:
          discard
    if self.env < 0:
      self.envValue = clamp(lerp(self.init.float / 15.0, 0, self.envPhase / (-self.env * 4)), 0.0, 1.0)
      if self.envValue <= 0:
        self.stop()
        return
    elif self.env > 0:
      # attack
      self.envValue = clamp(lerp(self.init.float / 15.0, 1.0, self.envPhase / (self.env * 4)), 0.0, 1.0)
    elif self.env == 0:
      self.envValue = self.init.float / 15.0

    self.gain.gain.value = clamp(lerp(self.gain.gain.value, self.envValue, 0.9), 0.0, 1.0)
  else:
    discard

proc audioClock() =
  sfxGain.gain.value = sfxVolume
  musicGain.gain.value = musicVolume
  masterGain.gain.value = masterVolume

  for channel in mitems(audioChannels):
    channel.process()

proc step() =
  if loading > 0:
    debug("loading...", loading)
    # copy swCanvas to canvas
    present()

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
    updateFunc(timeStep)

  if drawFunc != nil:
    drawFunc()

  for k,v in keysDown:
    if v > 0:
      keysDown[k] += 1

  present()

  audioClock()

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

  audioContext = newAudioContext()
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

proc flip*() =
  present()

proc resize*() =
  discard

proc resize*(w,h: int) =
  # TODO adjust canvas size
  discard

proc initNoiseBuffer(samples: int, freq: float): AudioBuffer =
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
  if masterGain.gain.value != 0.0:
    echo "muting audio"
    masterGain.gain.value = 0.0
  else:
    echo "unmuting audio"
    masterGain.gain.value = 1.0

proc sfx*(channel: AudioChannelId = audioChannelAuto, sfxId: SfxId, loop: int = 0) =
  if sfxData[sfxId] != nil:
    if audioChannels[channel].source != nil:
      audioChannels[channel].stop()

    var source = audioContext.createBufferSource()
    source.buffer = sfxData[sfxId]
    source.connect(sfxGain)
    source.start()
    audioChannels[channel].source = source

proc getMusic*(channel: int): int =
  ## returns the id of the music currently being played on `channel` or -1 if no music is playing
  return -1

proc music*(channel: AudioChannelId, musicId: MusicId, loop: int = -1) =
  if audioChannels[channel].source != nil:
    audioChannels[channel].source.stop()
    audioChannels[channel].source = nil
    audioChannels[channel].musicId = -1

  if musicData[musicId] != nil:
    var source = audioContext.createBufferSource()
    source.buffer = musicData[musicId]
    source.loop = true
    source.connect(musicGain)
    source.start()
    audioChannels[channel].source = source
    audioChannels[channel].musicId = musicId

proc volume*(channel: AudioChannelId, volume: int) =
  audioChannels[channel].gain.gain.value = (volume.float / 255.0)

proc pitchbend*(channel: AudioChannelId, changeSpeed: range[-128..128]) =
  audioChannels[channel].pchange = changeSpeed

proc vibrato*(channel: AudioChannelId, speed: range[1..15], amount: range[0..15]) =
  audioChannels[channel].vibspeed = speed
  audioChannels[channel].vibamount = amount

proc glide*(channel: AudioChannelId, glide: range[0..15]) =
  audioChannels[channel].glide = glide

proc wavData*(channel: AudioChannelId): array[32, uint8] =
  return audioChannels[channel].wavData

proc wavData*(channel: AudioChannelId, data: array[32, uint8]) =
  audioChannels[channel].wavData = data

proc pitch*(channel: AudioChannelId, freq: float) =
  audioChannels[channel].targetFreq = freq

proc synthShape*(channel: AudioChannelId, newShape: SynthShape) =
  audioChannels[channel].shape = newShape

proc synth*(channel: int, shape: SynthShape, freq: float, init: range[0..15], env: range[-7..7], length: range[0..255] = 0) =
  if channel > audioChannels.high:
    raise newException(KeyError, "invalid channel: " & $channel)

  audioChannels[channel].stop()

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

  if shape == synNoise or shape == synNoise2:
    when true:
      var n = audioContext.createBufferSource()

      if shape == synNoise:
        if noiseBuffer == nil:
          noiseBuffer = initNoiseBuffer(4096, 1000.0)
        n.buffer = noiseBuffer
      elif shape == synNoise2:
        if noiseBuffer2 == nil:
          noiseBuffer2 = initNoiseBuffer(128, 1000.0)
        n.buffer = noiseBuffer2

      audioChannels[channel].source = n
      n.loop = true
      connect(n, audioChannels[channel].gain)
      connect(audioChannels[channel].gain, sfxGain)
      n.start()
    when false:
      var gen = audioContext.createScriptProcessor(16384, 0, 1);

      var nextClick = 0
      var outputValue = 0.0
      var lfsr = 0xfeed

      gen.onaudioprocess = proc(e: AudioProcessingEvent) =
        console.log("audio process", nextClick)
        var output = e.outputBuffer;
        var data = output.getChannelData(0)
        for i in 0..<output.length:
          if nextClick <= 0:
            nextClick = ((1.0 / freq) * sampleRate).int
            let lsb: uint = (lfsr and 1)
            lfsr = lfsr shr 1
            if lsb == 1:
              lfsr = lfsr xor 0xb400
            outputValue = if lsb == 1: 1.0 else: -1.0
          nextClick -= 1
          data[i] = outputValue

      audioChannels[channel].source = gen

      connect(gen, audioChannels[channel].gain)
      connect(audioChannels[channel].gain, sfxGain)
  else:
    var osc = audioContext.createOscillator();
    osc.`type` = case shape:
    of synSin: "sine"
    of synSqr: "square"
    #of synP12: "custom"
    #of synP25: "custom"
    of synSaw: "sawtooth"
    of synTri: "triangle"
    else:
      "sine"

    osc.frequency.value = freq

    if shape == synP12:
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

    elif shape == synP25:
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

    osc.start()
    audioChannels[channel].source = osc

    connect(audioChannels[channel].source, audioChannels[channel].gain)
    connect(audioChannels[channel].gain, sfxGain)


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
  interval = dom.window.setInterval(step, (timeStep * 1000.0).int)

proc setScreenSize*(w,h: int) =
  discard

proc setWindowTitle*(title: string) =
  discard

proc setFullscreen*(fullscreen: bool) =
  discard

proc getFullscreen*(): bool =
  return false

proc addKeyListener*(f: KeyListener) =
  return

proc removeKeyListener*(f: KeyListener) =
  return
