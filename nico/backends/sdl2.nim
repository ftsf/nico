import common
import json

import strutils
import times

import nico/ringbuffer

import math

import sdl2/sdl

import nimPNG

when defined(gif):
  import gifenc

import os
import osproc
import ospaths

import parseCfg

export Scancode
import streams
import strutils

import sndfile
import math
import random

# Types

type
  SfxBuffer = ref object
    data: seq[float32]
    rate: float32
    channels: range[1..2]
    length: int

type
  Channel = object
    kind: ChannelKind
    buffer: SfxBuffer
    callback: proc(samples: seq[float32])
    musicFile: ptr TSNDFILE
    musicIndex: int
    musicBuffer: int
    musicBuffers: array[2,array[musicBufferSize,float32]]

    arp: uint16
    arpSpeed: uint8

    loop: int
    phase: float32 # or position
    freq: float32 # or speed
    basefreq: float32
    targetFreq: float32
    width: float32
    pan: float32
    shape: SynthShape
    gain: float32

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
    lfsr: uint
    lfsr2: uint
    nextClick: int
    outvalue: float32

    priority: float32

    wavData: array[32, uint8]

when defined(android):
  type LogPriority = enum
    ANDROID_LOG_UNKNOWN = 0.cint
    ANDROID_LOG_DEFAULT
    ANDROID_LOG_VERBOSE
    ANDROID_LOG_DEBUG
    ANDROID_LOG_INFO
    ANDROID_LOG_WARN
    ANDROID_LOG_ERROR
    ANDROID_LOG_FATAL
    ANDROID_LOG_SILENT

  proc android_log(priority: LogPriority, tag: cstring, text: cstring) {.header: "android/log.h", importc: "__android_log_write".}

  proc debug*(args: varargs[string, `$`]) =
    android_log(ANDROID_LOG_INFO, "NICO", join(args, ", ").cstring)
else:
  proc debug*(args: varargs[string, `$`]) =
    for i, s in args:
      write(stderr, s)
      if i != args.high:
        write(stderr, ", ")
    write(stderr, "\n")
    flushFile(stderr)

# Globals

var keyListeners = newSeq[KeyListener]()

var audioDeviceId: AudioDeviceID

var window: Window

var nextTick = 0
var clock: bool
var nextClock = 0

var eventFunc: proc(event: Event): bool
var render: Renderer
var hwCanvas: Texture
var swCanvas32: sdl.Surface
var srcRect: sdl.Rect
var dstRect: sdl.Rect

var current_time = getTicks()
var acc = 0.0
var next_time: uint32

var config: Config

when defined(gif):
  var recordFrame: common.Surface
var recordFrames: RingBuffer[common.Surface]

var sfxBufferLibrary: array[64,SfxBuffer]
var musicFileLibrary: array[64,string]

var audioSampleId: uint32
var audioChannels: array[nAudioChannels, Channel]

import nico/controller

# map of scancodes to NicoButton

converter toScancode(x: int): Scancode =
  x.Scancode

converter toInt(x: Scancode): int =
  x.int

keymap = [
  @[SCANCODE_LEFT.int,  SCANCODE_A.int], # left
  @[SCANCODE_RIGHT.int, SCANCODE_D.int], # right
  @[SCANCODE_UP.int,    SCANCODE_W.int], # up
  @[SCANCODE_DOWN.int,  SCANCODE_S.int], # down
  @[SCANCODE_Z.int], # A
  @[SCANCODE_X.int], # B
  @[SCANCODE_LSHIFT.int, SCANCODE_RSHIFT.int], # X
  @[SCANCODE_C.int], # Y
  @[SCANCODE_F.int], # L1
  @[SCANCODE_G.int], # L2
  @[SCANCODE_V.int], # R1
  @[SCANCODE_B.int], # R2
  @[SCANCODE_RETURN.int], # Start
  @[SCANCODE_ESCAPE.int, SCANCODE_BACKSPACE.int], # Back
]

proc createRecordBuffer(forceClear: bool = false) =
  if window == nil:
    # this can happen later
    return

  when defined(gif):
    if recordFrame.data == nil or screenWidth != recordFrame.w and screenHeight != recordFrame.h:
      recordFrame = newSurface(screenWidth,screenHeight)

    if recordSeconds <= 0:
      recordFrames = newRingBuffer[common.Surface](1)
    else:
      recordFrames = newRingBuffer[common.Surface](if fullSpeedGif: recordSeconds * frameRate.int else: recordSeconds * int(frameRate / 2))


proc resize*(w,h: int) =
  debug "resize", w, h
  if w == 0 or h == 0:
    return
  # calculate screenScale based on size

  debug "target", targetScreenWidth, targetScreenHeight

  if render != nil:
    destroyRenderer(render)

  render = createRenderer(window, -1, Renderer_Accelerated or Renderer_PresentVsync or Renderer_TargetTexture)

  if integerScreenScale:
    screenScale = max(1.0, min(
      (w.float32 / targetScreenWidth.float32).floor,
      (h.float32 / targetScreenHeight.float32).floor,
    ))
  else:
    screenScale = max(1.0, min(
      (w.float32 / targetScreenWidth.float32),
      (h.float32 / targetScreenHeight.float32),
    ))

  var displayW,displayH: int

  if fixedScreenSize:
    displayW = (targetScreenWidth.float32 * screenScale).int
    displayH = (targetScreenHeight.float32 * screenScale).int
    debug "display", displayW, displayH

    # add padding
    screenPaddingX = ((w.int - displayW.int)) div 2
    screenPaddingY = ((h.int - displayH.int)) div 2
    debug "add padding", w, h, screenPaddingX, screenPaddingY

    screenWidth = targetScreenWidth
    screenHeight = targetScreenHeight
  else:
    screenPaddingX = 0
    screenPaddingY = 0

    displayW = w
    displayH = h

    if integerScreenScale:
      screenWidth = displayW div screenScale
      screenHeight = displayH div screenScale
      debug "screen", screenWidth, screenHeight
    else:
      screenWidth = (displayW.float32 / screenScale).int
      screenHeight = (displayH.float32 / screenScale).int
      debug "screen", screenWidth, screenHeight

  debug "resize event: scale: ", screenScale, ": ", displayW, " x ", displayH, " ( ", screenWidth, " x ", screenHeight, " )"
  # resize the buffers
  debug screenPaddingX, screenPaddingY

  srcRect = sdl.Rect(x:0,y:0,w:screenWidth,h:screenHeight)
  dstRect = sdl.Rect(x:screenPaddingX,y:screenPaddingY,w:displayW, h:displayH)

  debug "srcRect: ", srcRect
  debug "dstRect: ", dstRect

  clipMinX = 0
  clipMinY = 0
  clipMaxX = screenWidth - 1
  clipMaxY = screenHeight - 1

  hwCanvas = render.createTexture(PIXELFORMAT_RGBA8888, TEXTUREACCESS_STREAMING, screenWidth, screenHeight)
  swCanvas = newSurface(screenWidth,screenHeight)

  swCanvas32 = createRGBSurface(0, screenWidth, screenHeight, 32, 0x000000ff'u32, 0x0000ff00'u32, 0x00ff0000'u32, 0xff000000'u32)
  if swCanvas32 == nil:
    debug "error creating RGB surface"
    quit(1)
  discard render.setRenderTarget(hwCanvas)
  createRecordBuffer()

  if resizeFunc != nil:
    resizeFunc(screenWidth,screenHeight)

proc resize*() =
  if window == nil:
    return
  debug "resize() called"
  var windowW, windowH: cint
  window.getWindowSize(windowW.addr, windowH.addr)
  resize(windowW,windowH)

proc createWindow*(title: string, w,h: int, scale: int = 2, fullscreen: bool = false) =
  debug "Creating window"
  when defined(android):
    window = createWindow(title.cstring, WINDOWPOS_UNDEFINED, WINDOWPOS_UNDEFINED, (w * scale).cint, (h * scale).cint, WINDOW_FULLSCREEN)
  else:
    window = createWindow(title.cstring, WINDOWPOS_CENTERED, WINDOWPOS_CENTERED, (w * scale).cint, (h * scale).cint, 
      (WINDOW_RESIZABLE or (if fullscreen: WINDOW_FULLSCREEN_DESKTOP else: 0)).uint32)

  if window == nil:
    debug "error creating window"

  targetScreenWidth = w
  targetScreenHeight = h

  discard setHint("SDL_HINT_RENDER_VSYNC", "1")
  discard setHint("SDL_RENDER_SCALE_QUALITY", "0")

  var displayW, displayH: cint
  window.getWindowSize(displayW.addr, displayH.addr)
  debug "initial resize: ", displayW, displayH
  resize(displayW,displayH)

  discard showCursor(1)

  window.raiseWindow()

proc readFile*(filename: string): string =
  var fp = rwFromFile(filename, "r")

  if fp == nil:
    raise newException(IOError, "Unable to open file: " & filename)

  let size = rwSize(fp)
  var buffer = newSeq[uint8](size)

  var offset = 0
  while offset < size:
    let r = rwRead(fp, buffer[offset].addr, 1, 1.csize)
    offset += r
    if r == 0:
      break

  if rwClose(fp) != 0:
    debug getError()

  result = cast[string](buffer)

proc loadSurfaceIndexed*(filename: string, callback: proc(surface: common.Surface)) =
  var buffer = readFile(filename)
  let ss = newStringStream(buffer)
  let png = decodePNG(ss, LCT_PALETTE, 8)
  debug("read image", filename, png.width, png.height)

  var surface: common.Surface
  surface.w = png.width
  surface.h = png.height
  surface.channels = 1
  surface.data = cast[seq[uint8]](png.data)
  callback(surface)

proc loadSurfaceRGBA*(filename: string, callback: proc(surface: common.Surface)) =
  var buffer = readFile(filename)
  let ss = newStringStream(buffer)
  let png = decodePNG(ss, LCT_RGBA, 8)
  debug("read image", filename, png.width, png.height)

  var surface: common.Surface
  surface.w = png.width
  surface.h = png.height
  surface.channels = 4
  surface.data = cast[seq[uint8]](png.data)
  callback(surface)

proc readJsonFile*(filename: string): JsonNode =
  return parseJson(readFile(filename))

proc saveJsonFile*(filename: string, data: JsonNode) =
  var fp = open(filename, fmWrite)
  fp.write(data.pretty())
  fp.close()

proc present*() =
  discard render.setRenderTarget(nil)
  # copy swCanvas to hwCanvas

  convertToABGR(swCanvas, swCanvas32.pixels, swCanvas32.pitch, screenWidth, screenHeight)

  if updateTexture(hwCanvas, nil, swCanvas32.pixels, swCanvas32.pitch) != 0:
    debug(sdl.getError())

  # copy hwCanvas to screen
  discard render.setRenderDrawColor(5,5,10,255)
  discard render.renderClear()
  if render.renderCopy(hwCanvas, srcRect.addr, dstRect.addr) != 0:
    debug(sdl.getError())
  render.renderPresent()

proc flip*() =
  present()

  when defined(gif):
    if recordSeconds > 0:
      if fullSpeedGif or frame mod 2 == 0:
        if recordFrame.data != nil:
          copyMem(recordFrame.data[0].addr, swCanvas.data[0].addr, swCanvas.w * swCanvas.h)
          recordFrames.add([recordFrame])

  #delay(0)

proc saveScreenshot*() =
  createDir(writePath & "/screenshots")
  var frame = recordFrames[recordFrames.size-1]
  var abgr = newSeq[uint8](screenWidth*screenHeight*4)
  # convert RGBA to BGRA
  convertToRGBA(frame, abgr[0].addr, screenWidth*4, screenWidth, screenHeight)
  let filename = writePath & "/screenshots/screenshot-$1T$2.png".format(getDateStr(), getClockStr())
  debug "saved screenshot to: ", filename

proc saveRecording*() =
  # TODO: do this in another thread?
  when defined(gif):
    debug "saveRecording"
    try:
      createDir(writePath & "/video")
    except OSError:
      debug "unable to create video output directory"
      return

    var palette: array[maxPaletteSize,array[3,uint8]]
    for i in 0..<maxPaletteSize:
      palette[i] = [colors[i].r, colors[i].g, colors[i].b]

    let filename = writePath & "/video/video-$1T$2.gif".format(getDateStr(), getClockStr().replace(":","-"))

    var gif = newGIF(
      filename.cstring,
      (screenWidth*gifScale).uint16,
      (screenHeight*gifScale).uint16,
      palette[0][0].addr, if paletteSize <= 16: 4 else: 8, 0
    )

    if gif == nil:
      debug "unable to create gif: ", filename
      return

    debug "created gif: ", filename
    var pixels: ptr[array[int32.high, uint8]]

    for j in 0..recordFrames.size:
      var frame = recordFrames[j]
      if frame.data == nil:
        debug "empty frame. breaking."
        break

      pixels = cast[ptr array[int32.high, uint8]](gif.frame)

      if gifScale != 1:
        for y in 0..<screenHeight*gifScale:
          for x in 0..<screenWidth*gifScale:
            let sx = x div gifScale
            let sy = y div gifScale
            pixels[y*screenWidth*gifScale+x] = frame.data[sy*frame.w+sx]
      else:
        copyMem(gif.frame, frame.data[0].addr, screenWidth*screenHeight)
      gif.add_frame(if fullSpeedGif: 2 else: 3)

    gif.close()

proc getKeyNamesForBtn*(btn: NicoButton): seq[string] =
  result = newSeq[string]()
  for scancode in keymap[btn]:
    result.add($(getKeyFromScancode(scancode).getKeyName()))

proc getKeyMap*(): string =
  result = ""
  for btn,scancodes in keymap:
    result.add($btn & ":")
    for i,scancode in scancodes:
      result.add(getKeyFromScancode(scancode).getKeyName())
      if i < scancodes.high:
        result.add(",")
    if btn != NicoButton.high:
      result.add(";")

proc setKeyMap*(mapstr: string) =
  for btnkeysstr in mapstr.split(";"):
    var b = btnkeysstr.split(":",1)
    var btnstr = b[0]
    var keysstr = b[1]
    var btn: NicoButton
    try:
      btn = parseEnum[NicoButton](btnstr)
    except ValueError:
      debug "invalid button name: ", btnstr
      return
    keymap[btn] = @[]
    for keystr in keysstr.split(","):
      let scancode = getKeyFromName(keystr).getScancodeFromKey()
      keymap[btn].add(scancode)

proc setFullscreen*(fullscreen: bool) =
  if fullscreen:
    debug "setting fullscreen"
    discard window.setWindowFullscreen(WINDOW_FULLSCREEN_DESKTOP)
  else:
    debug "setting windowed"
    discard window.setWindowFullscreen(0)

proc getFullscreen*(): bool =
  return (window.getWindowFlags() and WINDOW_FULLSCREEN_DESKTOP) != 0

proc appHandleEvent(evt: Event) =
  if evt.kind == Quit:
    keepRunning = false

  elif evt.kind == APP_WILLENTERBACKGROUND:
    debug "pausing"
    focused = false

  elif evt.kind == APP_DIDENTERFOREGROUND:
    debug "resumed"
    var w,h: cint
    window.getWindowSize(w.addr,h.addr)
    resize(w,h)
    current_time = getTicks()
    focused = true

  elif evt.kind == MouseWheel:
    mouseWheelState = evt.wheel.y

  elif evt.kind == MouseButtonDown:
    discard captureMouse(true)
    if evt.button.button < 4:
      mouseButtonsDown[evt.button.button-1] = true
      mouseButtons[evt.button.button-1] = 1

  elif evt.kind == MouseButtonUp:
    if evt.button.button < 4:
      discard captureMouse(false)
      mouseButtonsDown[evt.button.button-1] = false

  elif evt.kind == MouseMotion:
    if evt.motion.which != TOUCH_MOUSEID:
      mouseDetected = true
    mouseX = ((evt.motion.x - screenPaddingX).float32 / screenScale.float32).int
    mouseY = ((evt.motion.y - screenPaddingY).float32 / screenScale.float32).int

  elif evt.kind == ControllerDeviceAdded:
    for v in controllers:
      if v.id == evt.cdevice.which:
        debug "controller already exists"
        return
    try:
      var controller = newNicoController(evt.cdevice.which)
      controllers.add(controller)
      debug "added controller"
      if controllerAddedFunc != nil:
        controllerAddedFunc(controller)
    except:
      discard

  elif evt.kind == ControllerDeviceRemoved:
    var indexToRemove = -1
    for i,v in mpairs(controllers):
      if v.id == evt.cdevice.which:
        if v.sdlController != nil:
          v.sdlController.gameControllerClose()
        indexToRemove = i
        break
    if indexToRemove > -1:
      if controllerRemovedFunc != nil:
        controllerRemovedFunc(controllers[indexToRemove])
      controllers.del(indexToRemove)

  elif evt.kind == ControllerButtonDown or evt.kind == ControllerButtonUp:
    let down = evt.kind == ControllerButtonDown
    for controller in mitems(controllers):
      if controller.id == evt.cbutton.which:
        case evt.cbutton.button.GameControllerButton:
        of CONTROLLER_BUTTON_A:
          controller.setButtonState(pcA, down)
        of CONTROLLER_BUTTON_B:
          controller.setButtonState(pcB, down)
        of CONTROLLER_BUTTON_X:
          controller.setButtonState(pcX, down)
        of CONTROLLER_BUTTON_Y:
          controller.setButtonState(pcY, down)
        of CONTROLLER_BUTTON_START:
          controller.setButtonState(pcStart, down)
        of CONTROLLER_BUTTON_BACK:
          controller.setButtonState(pcBack, down)
        of CONTROLLER_BUTTON_LEFTSHOULDER:
          controller.setButtonState(pcL1, down)
        of CONTROLLER_BUTTON_RIGHTSHOULDER:
          controller.setButtonState(pcR1, down)
        of CONTROLLER_BUTTON_DPAD_UP:
          controller.setButtonState(pcUp, down)
        of CONTROLLER_BUTTON_DPAD_DOWN:
          controller.setButtonState(pcDown, down)
        of CONTROLLER_BUTTON_DPAD_LEFT:
          controller.setButtonState(pcLeft, down)
        of CONTROLLER_BUTTON_DPAD_RIGHT:
          controller.setButtonState(pcRight, down)
        else:
          discard
        break

  elif evt.kind == ControllerAxisMotion:
    for controller in mitems(controllers):
      if controller.id == evt.caxis.which:
        let value = evt.caxis.value.float32 / int16.high.float32
        case evt.caxis.axis.GameControllerAxis:
        of CONTROLLER_AXIS_LEFTX:
          controller.setAxisValue(pcXAxis, value)
        of CONTROLLER_AXIS_LEFTY:
          controller.setAxisValue(pcYAxis, value)
        of CONTROLLER_AXIS_RIGHTX:
          controller.setAxisValue(pcXAxis2, value)
        of CONTROLLER_AXIS_RIGHTY:
          controller.setAxisValue(pcYAxis2, value)
        of CONTROLLER_AXIS_TRIGGERLEFT:
          controller.setAxisValue(pcLTrigger, value)
        of CONTROLLER_AXIS_TRIGGERRIGHT:
          controller.setAxisValue(pcRTrigger, value)
        else:
          discard
        break

  elif evt.kind == WindowEvent:
    if evt.window.event == WindowEvent_Resized:
      resize(evt.window.data1, evt.window.data2)
      discard render.setRenderTarget(nil)
      discard render.setRenderDrawColor(0,0,0,255)
      discard render.renderClear()
    elif evt.window.event == WindowEvent_Size_Changed:
      discard
    elif evt.window.event == WindowEvent_FocusLost:
      focused = false
    elif evt.window.event == WindowEvent_FocusGained:
      focused = true

  elif evt.kind == KeyDown or evt.kind == KeyUp:
    let sym = evt.key.keysym.sym
    let mods = evt.key.keysym.mods
    let scancode = evt.key.keysym.scancode
    let down = evt.kind == Keydown

    for listener in keyListeners:
      if listener(sym.int, mods.uint16, scancode.int, down.bool):
        return

    if sym == K_AC_BACK:
      controllers[0].setButtonState(pcBack, down)

    elif sym == K_q and down and (mods and uint16(KMOD_CTRL)) != 0:
      # ctrl+q to quit
      keepRunning = false

    elif sym == K_f and not down and (mods and uint16(KMOD_CTRL)) != 0:
      if getFullscreen():
        setFullscreen(false)
      else:
        setFullscreen(true)
      return

    elif sym == K_return and not down and (mods and uint16(KMOD_ALT)) != 0:
      if getFullscreen():
        setFullscreen(false)
      else:
        setFullscreen(true)
      return

    elif sym == K_F8 and down:
      # restart recording from here
      createRecordBuffer(true)

    elif sym == K_F9 and down:
      saveRecording()

    elif sym == K_F10 and down:
      saveScreenshot()

    elif sym == K_F11 and down:
      when system.hostOS == "windows":
        discard startProcess("explorer", writePath, [writePath], nil, {poUsePath})
      elif system.hostOS == "macosx":
        discard startProcess("open", writePath, [writePath], nil, {poUsePath})
      elif system.hostOS == "linux":
        discard startProcess("xdg-open", writePath, [writePath], nil, {poUsePath})

    if evt.key.repeat == 0:
      for btn,btnScancodes in keymap:
        for btnScancode in btnScancodes:
          if scancode == btnScancode:
            controllers[0].setButtonState(btn, down)

proc checkInput() =
  var evt: Event
  while pollEvent(evt.addr) == 1:
    if eventFunc != nil:
      let handled = eventFunc(evt)
      if handled:
        continue
    appHandleEvent(evt)

proc setScreenSize*(w,h: int) =
  window.setWindowSize(w,h)
  resize()

proc queueMixerAudio*(nSamples: int)

proc queuedAudioSize*(): int =
  return getQueuedAudioSize(audioDeviceId).int div 4

proc step*() {.cdecl.} =
  checkInput()

  next_time = getTicks()
  var diff = float32(next_time - current_time)/1000.0 * frameMult.float32
  if diff > timeStep * 2.0:
    diff = timeStep
  acc += diff
  current_time = next_time

  while acc > timeStep:

    for controller in mitems(controllers):
      controller.update()

    updateFunc(timeStep)

    for controller in mitems(controllers):
      controller.postUpdate()

    frame += 1
    if acc > timeStep and acc < timeStep+timeStep:
      drawFunc()
      flip()

    for i,b in mouseButtonsDown:
      if b:
        mouseButtons[i] += 1
      else:
        mouseButtons[i] = 0

    mouseWheelState = 0

    acc -= timeStep

    when not compileOption("threads"):
      if queuedAudioSize() < 8192:
        queueMixerAudio(4096)

proc getPerformanceCounter*(): uint64 {.inline.} =
  return sdl.getPerformanceCounter()

proc getPerformanceFrequency*(): uint64 {.inline.} =
  return sdl.getPerformanceFrequency()

proc setWindowTitle*(title: string) =
  window.setWindowTitle(title)

proc getUnmappedJoysticks*(): seq[Joystick] =
  result = newSeq[Joystick]()
  let n = numJoysticks()
  for i in 0..<n:
    if not isGameController(i):
      var j = joystickOpen(i)
      result.add(j)

proc loadConfig*() =
  try:
    config = loadConfig(writePath & "/config.ini")
    debug "loaded config from " & writePath & "/config.ini"
  except IOError:
    try:
      config = loadConfig(basePath & "/config.ini")
      debug "loaded config from " & basePath & "/config.ini"
    except IOError:
      debug "no config file loaded"
      config = newConfig()

proc saveConfig*() =
  debug "saving config to " & writePath & "/config.ini"
  assert(config != nil)
  try:
    config.writeConfig(writePath & "/config.ini")
    debug "saved config to " & writePath & "/config.ini"
  except IOError:
    debug "error saving config"

proc updateConfigValue*(section, key, value: string) =
  debug "updateConfigValue", key, value
  config.setSectionKey(section, key, value)

proc getConfigValue*(section, key: string): string =
  result = config.getSectionValue(section, key)
  debug "getConfigValue", section, key, result

proc queueAudio*(samples: var seq[float32]) =
  let ret = queueAudio(audioDeviceId, samples[0].addr, (samples.len * 4).uint32)
  if ret != 0:
    raise newException(Exception, "error queueing audio: " & $getError())

proc process(self: var Channel): float32 =
  case self.kind:
  of channelNone:
    return 0.0
  of channelSynth:
    if audioSampleId mod 2 == 0:
      if self.glide == 0:
        self.freq = self.targetFreq
      elif clock:
        self.freq = lerp(self.freq, self.targetFreq, 1.0 - (self.glide.float32 / 16.0))
      self.phase += (self.freq * invSampleRate) * TAU
      self.phase = self.phase mod TAU
    var o: float32 = 0.0
    case self.shape:
    of synSin:
      o = sin(self.phase)
    of synSqr:
      o = ((if self.phase mod TAU < (TAU * 0.5): 1.0 else: -1.0) * 0.577).float32
    of synP12:
      o = ((if self.phase mod TAU < (TAU * 0.125): 1.0 else: -1.0) * 0.577).float32
    of synP25:
      o = ((if self.phase mod TAU < (TAU * 0.25): 1.0 else: -1.0) * 0.577).float32
    of synTri:
      o = ((abs((self.phase mod TAU) / TAU * 2.0 - 1.0)*2.0 - 1.0) * 0.7).float32
    of synSaw:
      o = ((((self.phase mod TAU) - PI) / PI) * 0.5).float32
    of synNoise:
      if self.freq != 0.0:
        if self.nextClick <= 0:
          let lsb: uint = (self.lfsr and 1).uint
          self.lfsr = self.lfsr shr 1
          if lsb == 1:
            self.lfsr = self.lfsr xor 0xb400
          self.outvalue = if lsb == 1: 1.0 else: -1.0
          self.nextClick = ((1.0 / self.freq) * sampleRate).int
        self.nextClick -= 1
      o = self.outvalue
    of synNoise2:
      if self.freq != 0.0:
        if self.nextClick <= 0:
          let lsb: uint = (self.lfsr2 and 1)
          self.lfsr2 = self.lfsr2 shr 1
          if lsb == 1:
            self.lfsr2 = self.lfsr2 xor 0x0043
          self.outvalue = if lsb == 1: 1.0 else: -1.0
          self.nextClick = ((1.0 / self.freq) * sampleRate).int
        self.nextClick -= 1
      o = self.outvalue
    of synWav:
      if self.freq != 0.0:
        o = self.wavData[(self.phase mod 1.0 * 32.0).int].float32 / 16.0
    else:
      o = 0.0
    o = o * self.gain

    if audioSampleId mod 2 == 0:
      if clock:
        if self.length > 0:
          self.length -= 1
          if self.length == 0:
            self.kind = channelNone

        self.envPhase += 1

        if self.vibamount > 0:
          self.freq = self.basefreq + sin(self.envPhase.float32 / self.vibspeed.float32) * self.basefreq * 0.03 * self.vibamount.float32

        if self.pchange != 0:
          self.targetFreq = self.targetFreq + self.targetFreq * self.pchange.float32 / 128.0
          self.basefreq = self.targetFreq
          self.freq = self.targetFreq
          if self.targetFreq > sampleRate / 2.0:
            self.targetFreq = sampleRate / 2.0

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
              self.targetFreq = self.basefreq + self.basefreq * 0.06 * a0.float32
            elif (self.envPhase / self.arpSpeed.int) mod arpSteps == 2:
              self.targetFreq = self.basefreq + self.basefreq * 0.06 * a1.float32
            elif (self.envPhase / self.arpSpeed.int) mod arpSteps == 3:
              self.targetFreq = self.basefreq + self.basefreq * 0.06 * a2.float32
            elif (self.envPhase / self.arpSpeed.int) mod arpSteps == 4:
              self.targetFreq = self.basefreq + self.basefreq * 0.06 * a3.float32
            else:
              self.targetFreq = self.basefreq

        # determine the env value
        if self.env < 0:
          # decay
          self.envValue = clamp(lerp(self.init.float32 / 15.0, 0, self.envPhase / (-self.env * 4)), 0.0, 1.0)
          if self.envValue <= 0:
            self.kind = channelNone
        elif self.env > 0:
          # attack
          self.envValue = clamp(lerp(self.init.float32 / 15.0, 1.0, self.envPhase / (self.env * 4)), 0.0, 1.0)
        elif self.env == 0:
          self.envValue = self.init.float32 / 15.0

        self.gain = clamp(lerp(self.gain, self.envValue, 0.9), 0.0, 1.0)

    return o * sfxVolume

  of channelWave:
    var o: float32 = 0.0
    o = self.buffer.data.interpolatedLookup(self.phase) * self.gain
    if audioSampleId mod 2 == 0:
      self.phase += self.freq
      if self.phase >= self.buffer.data.len:
        self.phase = self.phase mod self.buffer.data.len.float32
        if self.loop > 0:
          self.loop -= 1
          if self.loop == 0:
            self.kind = channelNone
    return o * sfxVolume
  of channelMusic:
    var o: float32
    o = self.musicBuffers[self.musicBuffer].interpolatedLookup(self.phase) * self.gain
    self.phase += self.freq / TAU
    if self.phase >= musicBufferSize:
      # end of buffer, switch buffers and fill
      self.phase = 0.0
      let read = self.musicFile.read_float(self.musicBuffers[self.musicBuffer][0].addr, musicBufferSize)
      self.musicBuffer = (self.musicBuffer + 1) mod 2
      if read != musicBufferSize:
        if self.loop != 0:
          if self.loop > 0:
            self.loop -= 1
          discard self.musicFile.seek(0, SEEK_SET)
        else:
          self.reset()

    return o * musicVolume
  else:
    return 0.0


when compileOption("threads"):
  proc audioCallback(userdata: pointer, stream: ptr uint8, bytes: cint) {.cdecl.} =
    when compileOption("threads"):
      setupForeignThreadGc()

    var samples = cast[ptr array[int32.high,float32]](stream)
    let nSamples = bytes div sizeof(float32)

    for i in 0..<nSamples:

      if i mod 2 == 0:
        nextClock -= 1
        if nextClock <= 0:
          clock = true
          nextClock = (sampleRate div 60)
        else:
          clock = false

        nextTick -= 1
        if nextTick <= 0 and tickFunc != nil:
          tickFunc()
          nextTick = (sampleRate / (currentBpm.float32 / 60.0 * currentTpb.float32)).int

      samples[i] = 0
      for j in 0..<audioChannels.len:
        samples[i] += audioChannels[j].process() * masterVolume
      audioSampleId += 1

proc queueMixerAudio*(nSamples: int) =
  var samples = newSeq[float32](nSamples)

  for i in 0..<nSamples:

    if i mod 2 == 0:
      nextClock -= 1
      if nextClock <= 0:
        clock = true
        nextClock = (sampleRate div 60)
      else:
        clock = false

      nextTick -= 1
      if nextTick <= 0 and tickFunc != nil:
        tickFunc()
        nextTick = (sampleRate / (currentBpm.float32 / 60.0 * currentTpb.float32)).int

    samples[i] = 0
    for j in 0..<audioChannels.len:
      samples[i] += audioChannels[j].process()
    audioSampleId += 1

  queueAudio(samples)

proc initMixer*() =
  when defined(js):
    # use web audio
    discard
  else:
    debug "initMixer"
    if sdl.init(INIT_AUDIO) != 0:
      raise newException(Exception, "Unable to initialize audio")

    var audioSpec: AudioSpec
    audioSpec.freq = sampleRate.cint
    audioSpec.format = AUDIO_F32
    audioSpec.channels = 2
    audioSpec.samples = musicBufferSize
    audioSpec.padding = 0
    when compileOption("threads"):
      audioSpec.callback = audioCallback
    else:
      audioSpec.callback = nil
    audioSpec.userdata = nil

    var obtained: AudioSpec
    audioDeviceId = openAudioDevice(nil, 0, audioSpec.addr, obtained.addr, AUDIO_ALLOW_FORMAT_CHANGE)
    if audioDeviceId == 0:
      raise newException(Exception, "Unable to open audio device: " & $getError())

    sampleRate = obtained.freq.float32
    invSampleRate = 1.0 / obtained.freq.float32

    for c in audioChannels.mitems:
      c.lfsr = 0xfeed
      c.lfsr2 = 0x00fe
      c.glide = 0
      for j in 0..<32:
        c.wavData[j] = rand(16).uint8

    # start the audio thread
    when compileOption("threads"):
      pauseAudioDevice(audioDeviceId, 0)
      if obtained.callback != audioCallback:
        debug "wtf no callback"
      debug "audio initialised using audio thread"
    else:
      queueMixerAudio(4096)
      pauseAudioDevice(audioDeviceId, 0)
      debug "audio initialised using main thread"

proc init*(org: string, app: string) =
  discard setHint("SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS", "1")

  if sdl.init(INIT_EVERYTHING) != 0:
    debug sdl.getError()
    quit(1)

  # add keyboard controller
  when not defined(android):
    controllers.add(newNicoController(-1))

    basePath = $sdl.getBasePath()
    debug "basePath: ", basePath

    assetPath = joinPath(basePath, "assets")
    debug "assetPath: ", assetPath

    writePath = $sdl.getPrefPath(org,app)
    debug "writePath: ", writePath

    discard gameControllerAddMappingsFromFile(basePath & "/assets/gamecontrollerdb.txt")
    discard gameControllerAddMappingsFromFile(writePath & "/gamecontrollerdb.txt")

    for i in 0..numJoysticks():
      if isGameController(i):
        try:
          var controller = newNicoController(i)
          controllers.add(controller)
        except:
          discard
  else:
    basePath = ""
    assetPath = ""
    writePath = $sdl.getPrefPath(org, app)
    debug "writePath: ", writePath
    controllers.add(newNicoController(-1))

  initMixer()

proc setEventFunc*(ef: proc(event: Event): bool) =
  eventFunc = ef

proc addKeyListener*(f: KeyListener) =
  keyListeners.add(f)

proc removeKeyListener*(f: KeyListener) =
  let i = keyListeners.find(f)
  keyListeners.del(i)

proc setTextFunc*(text: (proc(text: string): bool)) =
  if text == nil:
    stopTextInput()
  else:
    startTextInput()
  textFunc = text

proc hasTextFunc*(): bool =
  return textFunc != nil

proc setFullSpeedGif*(enabled: bool) =
  when defined(gif):
    fullSpeedGif = enabled
    createRecordBuffer(true)

proc getFullSpeedGif*(): bool =
  when defined(gif):
    return fullSpeedGif
  else:
    return false

proc setRecordSeconds*(seconds: int) =
  when defined(gif):
    recordSeconds = seconds
    createRecordBuffer()

proc getRecordSeconds*(): int =
  when defined(gif):
    return recordSeconds
  else:
    return 0

proc run*() =
  while keepRunning:
    step()

proc saveMap*(filename: string) =
  createDir(joinPath(assetPath,"maps"))
  var fs = newFileStream(joinPath(assetPath,"maps",filename), fmWrite)
  if fs == nil:
    debug "error opening map for writing: ", filename
    return
  fs.write(currentTilemap.w.int32)
  fs.write(currentTilemap.h.int32)
  for y in 0..<currentTilemap.h:
    for x in 0..<currentTilemap.w:
      let t = currentTilemap.data[y * currentTilemap.w + x]
      fs.write(t.char)
  fs.close()
  debug "saved map: ", filename

proc loadMapBinary*(filename: string) =
  var tm: Tilemap
  var fs = newFileStream(joinPath(assetPath,"maps",filename), fmRead)
  if fs == nil:
    raise newException(IOError, "Unable to open " & filename & " for reading")

  discard fs.readData(tm.w.addr, sizeof(int32)).int32
  discard fs.readData(tm.h.addr, sizeof(int32)).int32
  tm.data = newSeq[uint8](tm.w*tm.h)
  var r = fs.readData(tm.data[0].addr, tm.w * tm.h * sizeof(uint8))
  debug "read ", r, " tiles: ", tm.w, " x", tm.h
  fs.close()
  currentTilemap = tm

proc newSfxBuffer(filename: string): SfxBuffer =
  debug "loading sfx: ", filename
  result = new(SfxBuffer)
  var info: Tinfo
  when defined(js):
    discard
  else:
    zeroMem(info.addr, sizeof(Tinfo))
  var fp = sndfile.open(filename.cstring, READ, info.addr)
  debug "file opened"
  if fp == nil:
    raise newException(IOError, "unable to open file for reading: " & filename)

  result.data = newSeq[float32](info.frames * info.channels)
  result.rate = info.samplerate.float32
  result.channels = info.channels
  result.length = info.frames.int * info.channels.int

  var loaded = 0
  while loaded < result.length:
    let count = fp.read_float(result.data[loaded].addr, min(result.length - loaded,1024))
    loaded += count.int

  discard fp.close()

  debug "loaded sfx: " & filename & " frames: " & $result.length

proc loadSfx*(index: range[-1..63], filename: string) =
  if index < 0 or index > 63:
    return
  sfxBufferLibrary[index] = newSfxBuffer(joinPath(assetPath, filename))

proc loadMusic*(index: int, filename: string) =
  if index < 0 or index > 63:
    return
  musicFileLibrary[index] = joinPath(assetPath, filename)

proc getMusic*(index: AudioChannelId): int =
  if audioChannels[index].kind != channelMusic:
    return -1
  return audioChannels[index].musicIndex

proc findFreeChannel(priority: float32): int =
  for i,c in audioChannels:
    if c.kind == channelNone:
      return i
  var lowestPriority: float32 = Inf
  var bestChannel: AudioChannelId = -2
  for i,c in audioChannels:
    if c.priority < lowestPriority:
      lowestPriority = c.priority
      bestChannel = i
  if lowestPriority > priority or bestChannel < 0:
    return -2
  return bestChannel

proc sfx*(index: range[-1..63], channel: AudioChannelId = -1, loop: int = 1, gain: Pfloat = 1.0, pitch: Pfloat = 1.0, priority: Pfloat = Inf) =
  let channel = if channel == -1: findFreeChannel(priority) else: channel
  if channel == -2:
    return

  if index < 0:
    audioChannels[channel].reset()
    return

  if index > 63:
    return

  if sfxBufferLibrary[index] == nil:
    return

  audioChannels[channel].kind = channelWave
  audioChannels[channel].buffer = sfxBufferLibrary[index]
  audioChannels[channel].phase = 0.0
  audioChannels[channel].freq = pitch
  audioChannels[channel].gain = gain
  audioChannels[channel].loop = loop

proc music*(index: int, channel: AudioChannelId = -1, loop: int = 1) =
  var info: Tinfo
  var snd = sndfile.open(musicFileLibrary[index], READ, info.addr)
  if snd == nil:
    raise newException(IOError, "unable to open file for reading: " & musicFileLibrary[index])

  audioChannels[channel].kind = channelMusic
  audioChannels[channel].musicFile = snd
  audioChannels[channel].musicIndex = index
  audioChannels[channel].phase = 0.0
  audioChannels[channel].freq = 1.0
  audioChannels[channel].gain = 1.0
  audioChannels[channel].loop = loop
  audioChannels[channel].musicBuffer = 0

  discard snd.read_float(audioChannels[channel].musicBuffers[0][0].addr, musicBufferSize)
  discard snd.read_float(audioChannels[channel].musicBuffers[1][0].addr, musicBufferSize)

proc volume*(channel: int, volume: int) =
  audioChannels[channel].gain = (volume.float32 / 255.0)

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

proc pitch*(channel: int, freq: Pfloat) =
  audioChannels[channel].targetFreq = freq

proc synthShape*(channel: int, newShape: SynthShape) =
  audioChannels[channel].shape = newShape

proc reset*(channel: int) =
  if channel > audioChannels.high:
    raise newException(KeyError, "invalid channel: " & $channel)
  audioChannels[channel].kind = channelNone
  audioChannels[channel].freq = 1.0
  audioChannels[channel].gain = 0.0
  audioChannels[channel].loop = 0
  audioChannels[channel].musicIndex = 0

proc synth*(channel: int, shape: SynthShape, freq: Pfloat, init: range[0..15], env: range[-7..7], length: range[0..255] = 0) =
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

proc synthUpdate*(channel: int, shape: SynthShape, freq: Pfloat) =
  if channel > audioChannels.high:
    raise newException(KeyError, "invalid channel: " & $channel)
  if shape != synSame:
    audioChannels[channel].shape = shape
  audioChannels[channel].freq = freq
