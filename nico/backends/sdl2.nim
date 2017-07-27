import common
import json

import strutils
import times

import nico.ringbuffer

import math

import sdl2.sdl

import stb_image/read as stbi
import stb_image/write as stbiw

when defined(gif):
  import gifenc

import os
import osproc

import parseCfg

export Scancode
import streams
import strutils

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

when defined(sdlmixer):
  import sdl2.sdl_mixer


import nico.controller

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

var window: Window

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

var recordFrame: common.Surface
var recordFrames: RingBuffer[common.Surface]

var musicVolume: int
var sfxVolume: int

proc mute*()
proc unmute*()

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
      (w.float / targetScreenWidth.float).floor,
      (h.float / targetScreenHeight.float).floor,
    ))
  else:
    screenScale = max(1.0, min(
      (w.float / targetScreenWidth.float),
      (h.float / targetScreenHeight.float),
    ))

  var displayW,displayH: int

  if fixedScreenSize:
    displayW = (targetScreenWidth.float * screenScale).int
    displayH = (targetScreenHeight.float * screenScale).int
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
      screenWidth = (displayW.float / screenScale).int
      screenHeight = (displayH.float / screenScale).int
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
    window = createWindow(title.cstring, WINDOWPOS_UNDEFINED, WINDOWPOS_UNDEFINED, (w * scale).cint, (h * scale).cint, 
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

  discard showCursor(0)

proc readFile*(filename: string): string =
  debug "readFile: ", filename
  var fp = rwFromFile(filename, "r")

  if fp == nil:
    raise newException(IOError, "Unable to open file: " & filename)

  let size = rwSize(fp)
  debug size
  var buffer = newSeq[uint8](size)

  var offset = 0
  while offset < size:
    let r = rwRead(fp, buffer[offset].addr, 1, 1.csize)
    offset += r
    if r == 0:
      break
  discard rwClose(fp)

  result = cast[string](buffer)


proc loadSurface*(filename: string, callback: proc(surface: common.Surface)) =
  debug "loadSurface", filename
  var w,h,components: int
  var pixels: seq[uint8]

  var buffer = readFile(filename)

  try:
    pixels = stbi.load_from_memory(cast[seq[uint8]](buffer), w, h, components, 4)
  except STBIException:
    raise newException(IOError, "Unable to load surface: " & filename)

  debug("read image", w, h, components)

  var surface: common.Surface
  surface.w = w
  surface.h = h
  surface.channels = components
  surface.data = pixels
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
  discard stbiw.writePNG(filename, screenWidth, screenHeight, 4, abgr, screenWidth*4)
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

    var palette: array[16,array[3,uint8]]
    for i in 0..15:
      palette[i] = [colors[i].r, colors[i].g, colors[i].b]

    let filename = writePath & "/video/video-$1T$2.gif".format(getDateStr(), getClockStr().replace(":","-"))

    var gif = newGIF(
      filename.cstring,
      (screenWidth*gifScale).uint16,
      (screenHeight*gifScale).uint16,
      palette[0][0].addr, 4, 0
    )

    if gif == nil:
      debug "unable to create gif"
      return

    debug "created gif"
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
    mouseX = ((evt.motion.x - screenPaddingX).float / screenScale.float).int
    mouseY = ((evt.motion.y - screenPaddingY).float / screenScale.float).int

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
        let value = evt.caxis.value.float / int16.high.float
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
      debug "resize event"
      debug("padding", evt.window.padding1.int, evt.window.padding2.int, evt.window.padding3.int, evt.window.data1, evt.window.data2)
      resize(evt.window.data1, evt.window.data2)
      discard render.setRenderTarget(nil)
      discard render.setRenderDrawColor(0,0,0,255)
      discard render.renderClear()
    elif evt.window.event == WindowEvent_Size_Changed:
      debug "size changed event"
    elif evt.window.event == WindowEvent_FocusLost:
      focused = false
    elif evt.window.event == WindowEvent_FocusGained:
      focused = true

  elif evt.kind == KeyDown or evt.kind == KeyUp:
    let sym = evt.key.keysym.sym
    let scancode = evt.key.keysym.scancode
    let down = evt.kind == Keydown

    if sym == K_AC_BACK:
      controllers[0].setButtonState(pcBack, down)

    elif sym == K_q and down and (int16(evt.key.keysym.mods) and int16(KMOD_CTRL)) != 0:
      # ctrl+q to quit
      keepRunning = false

    elif sym == K_f and not down and (int16(evt.key.keysym.mods) and int16(KMOD_CTRL)) != 0:
      if getFullscreen():
        setFullscreen(false)
      else:
        setFullscreen(true)
      return

    elif sym == K_return and not down and (int16(evt.key.keysym.mods) and int16(KMOD_ALT)) != 0:
      if getFullscreen():
        setFullscreen(false)
      else:
        setFullscreen(true)
      return

    elif sym == K_m and down:
      when not defined(emscripten):
        if (int16(evt.key.keysym.mods) and int16(KMOD_CTRL)) != 0:
          muteAudio = not muteAudio
          if muteAudio:
            mute()
          else:
            unmute()

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

    if not evt.key.repeat != 0:
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

proc step*() {.cdecl.} =
  checkInput()

  next_time = getTicks()
  var diff = float(next_time - current_time)/1000.0 * frameMult.float
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
    #delay(if focused: 0 else: 10)

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
  # TODO check for config file in user config directioy, use that first
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

proc init*(org: string, app: string) =
  discard setHint("SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS", "1")

  if sdl.init(INIT_EVERYTHING) != 0:
    debug sdl.getError()
    quit(1)

  debug "SDL initialized"

  #addQuitProc(proc() {.noconv.} =
  #  sdl.quit()
  #)

  # add keyboard controller
  debug "adding controllers"
  when not defined(android):
    controllers.add(newNicoController(-1))

    debug "get base path: "
    basePath = $sdl.getBasePath()
    debug "basePath: ", basePath

    assetPath = basePath & "/assets/"

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

proc setEventFunc*(ef: proc(event: Event): bool) =
  eventFunc = ef

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

when defined(sdlmixer):
  var musicLibrary: array[64,Music]
  var sfxLibrary: array[64,Chunk]

  proc loadMusic*(musicId: MusicId, filename: string) =
    if mixerChannels > 0:
      var music = loadMUS(assetPath & filename)
      if music != nil:
        musicLibrary[musicId] = music
        debug "loaded music[" & $musicId & ": " & $filename
      else:
        debug "Warning: error loading ", filename

  proc music*(musicId: MusicId) =
    if mixerChannels > 0:
      var music = musicLibrary[musicId]
      if music != nil:
        currentMusicId = musicId
        discard playMusic(music, -1)
        discard volumeMusic(musicVolume)

  proc getMusic*(): MusicId =
    if mixerChannels > 0:
      return currentMusicId
    return 0

  proc loadSfx*(sfxId: SfxId, filename: string) =
    if mixerChannels > 0:
      var sfx = loadWAV(assetPath & filename)
      if sfx != nil:
        sfxLibrary[sfxId] = sfx
      else:
        debug "Warning: error loading ", filename

  proc sfx*(sfxId: SfxId, channel: range[-1..15] = -1, loop = 0) =
    if mixerChannels > 0:
      if sfxId == -1:
        discard haltChannel(channel)
      else:
        var sfx = sfxLibrary[sfxId]
        if sfx != nil:
          discard playChannel(channel, sfx, loop)
        else:
          debug "Warning: playing invalid sfx: " & $sfxId

  proc musicVol*(value: int) =
    musicVolume = value
    if mixerChannels > 0:
      discard volumeMusic(value)

  proc musicVol*(): int =
    if mixerChannels > 0:
      return volumeMusic(-1)
    return 0

  proc sfxVol*(value: int) =
    sfxVolume = value
    if mixerChannels > 0:
      discard volume(-1, value)

  proc sfxVol*(): int =
    if mixerChannels > 0:
      return volume(-1, -1)
    return 0

  proc mute*() =
    musicVolume = 0
    sfxVolume = 0
    discard volume(-1, 0)
    discard volumeMusic(0)

  proc unmute*() =
    musicVolume = 255
    sfxVolume = 255
    discard volume(-1, 255)
    discard volumeMusic(255)

else:
  # no sound implementation
  proc loadSfx*(sfxId: SfxId, filename: string) =
    discard

  proc loadMusic*(musicId: MusicId, filename: string) =
    discard

  proc musicVol*(value: int) =
    discard

  proc musicVol*(): int =
    discard

  proc sfxVol*(value: int) =
    discard

  proc sfxVol*(): int =
    discard

  proc mute*() =
    discard

  proc unmute*() =
    discard

  proc sfx*(sfxId: SfxId, channel: range[-1..15] = -1, loop: int = 0) =
    discard

  proc music*(musicId: MusicId) =
    discard

when defined(sdlmixer):
  proc initMixer*(channels: Pint) =
    when not defined(js):
      if sdl_mixer.init(INIT_OGG) == -1:
        debug sdl_mixer.getError()
      if openAudio(44100, AUDIO_S16, DEFAULT_CHANNELS, 1024) == -1:
        debug "Error initialising audio: " & $sdl_mixer.getError()
      else:
        addQuitProc(proc() {.noconv.} =
          debug "closing audio"
          sdl_mixer.closeAudio()
        )
        discard allocateChannels(channels)
        mixerChannels = channels

proc run*() =
  while keepRunning:
    step()

proc saveMap*(filename: string) =
  createDir(assetPath & "/maps")
  var fs = newFileStream(assetPath & "/maps/" & filename, fmWrite)
  if fs == nil:
    debug "error opening map for writing: ", filename
    return
  fs.write(currentTilemap.w.int32)
  fs.write(currentTilemap.h.int32)
  for y in 0..<currentTilemap.h:
    for x in 0..<currentTilemap.w:
      let t = currentTilemap.data[y * currentTilemap.w + x]
      fs.write(t.uint8)
  fs.close()
  debug "saved map: ", filename

proc loadMapBinary*(filename: string) =
  var tm: Tilemap
  var fs = newFileStream(assetPath & "/maps/" & filename, fmRead)
  if fs == nil:
    raise newException(IOError, "Unable to open " & filename & " for reading")

  discard fs.readData(tm.w.addr, sizeof(int32)).int32
  discard fs.readData(tm.h.addr, sizeof(int32)).int32
  tm.data = newSeq[uint8](tm.w*tm.h)
  var r = fs.readData(tm.data[0].addr, tm.w * tm.h * sizeof(uint8))
  debug "read ", r, " tiles: ", tm.w, " x", tm.h
  fs.close()
  currentTilemap = tm
