import common

import std/json
import std/tables
import std/hashes
import std/strutils
import std/sequtils
import std/times
import std/math
import std/streams
import std/random
import std/os
import std/osproc
import std/parsecfg

when defined(android):
  import std/strformat
when defined(opengl):
  import std/opengl

import nimPNG
when defined(gif):
  import gifenc

import sdl2_nim/sdl

import nico/ringbuffer
import nico/stb_vorbis
import nico/controller

proc toNicoKeycode(x: sdl.Keycode): common.Keycode =
  return cast[common.Keycode](x)

proc toNicoScancode(x: sdl.Scancode): common.Scancode =
  return cast[common.Scancode](x)

proc hash(x: common.Keycode): Hash =
  var h: Hash = 0
  h = h !& hash(x.int)
  result = !$h

proc errorPopup*(title: string, message: string)

# Types

type
  SfxBuffer = ref object
    data: seq[float32]
    rate: float32
    channels: int
    length: int

type
  Channel = object
    kind: ChannelKind
    buffer: SfxBuffer
    callback: proc(input: float32): float32
    callbackStereo: bool
    musicFile: Vorbis
    musicIndex: int
    musicBuffer: int
    musicStereo: bool
    musicSampleRate: float32
    musicBuffers: array[2,array[musicBufferSize,float32]]

    loop: int
    phase: float32 # or position
    freq: float32 # or speed
    basefreq: float32
    targetFreq: float32
    width: float32
    pan: float32
    shape: SynthShape
    gain: float32

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
    lfsr: uint32
    lfsr2: uint32
    nextClick: int
    outvalue: float32

    priority: float32

    wavData: array[32, uint8]
    outputBuffer: RingBuffer[float32]

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

  when defined(debug):
    proc debug*(args: varargs[string, `$`]) =
      android_log(ANDROID_LOG_INFO, "NICO", join(args, ", ").cstring)
  else:
    template debug*(args: varargs[string, `$`]) =
      discard
else:
  when defined(debug):
    when defined(emscripten):
      proc debug*(args: varargs[string, `$`]) =
        for i, s in args:
          write(stdout, s)
          if i != args.high:
            write(stdout, ", ")
        write(stdout, "\n")
        flushFile(stdout)

    else:
      proc debug*(args: varargs[string, `$`]) =
        for i, s in args:
          write(stderr, s)
          if i != args.high:
            write(stderr, ", ")
        write(stderr, "\n")
        flushFile(stderr)
  else:
    template debug*(args: varargs[string, `$`]) =
      discard

# Globals

var linearFilter = false

var audioDeviceId: sdl.AudioDeviceID
var audioInDeviceId: sdl.AudioDeviceID
var window: sdl.Window

var noAudio = true
var audioInSample*: float32
var audioBufferSize = 1024*2

var displayWidth,displayHeight: int

var inputSamples: seq[float32]
var outputSamples: seq[float32]

var nextTick = 0
var audioClock: bool
var nextAudioClock = 0
var vsyncEnabled: bool

when defined(opengl):
  var glContext: GLContext
  var hwCanvas: GLuint
  var quadVAO: GLuint
  var quadVBO: GLuint
  var shaderProgram: GLuint
  var lutTexture: GLuint
else:
  var render: sdl.Renderer
  var hwCanvas: sdl.Texture

var swCanvas32: sdl.Surface
var srcRect: sdl.Rect
var dstRect: sdl.Rect

var current_time = sdl.getTicks()
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

# map of scancodes to NicoButton

converter toScancode(x: int): sdl.Scancode =
  cast[sdl.Scancode](x)

proc resetChannel*(channel: var Channel)

proc loadConfig*()

proc createRecordBuffer(forceClear: bool = false) =
  if window == nil:
    # this can happen later
    return

  when defined(gif):
    recordFrame = newSurface(screenWidth,screenHeight)

    if recordSeconds <= 0:
      recordFrames = initRingBuffer[common.Surface](1)
    else:
      recordFrames = initRingBuffer[common.Surface](if fullSpeedGif: recordSeconds * frameRate.int else: recordSeconds * int(frameRate / 2))


proc resize*(w,h: int) =
  debug "nico resize: display: ", w, h
  if w == 0 or h == 0:
    return
  # calculate screenScale based on size

  displayWidth = w
  displayHeight = h

  when defined(opengl):
    discard
  else:
    if render != nil:
      sdl.destroyRenderer(render)

  if window == nil:
    debug "window is null, cannot resize"
    return


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

    # add padding
    screenPaddingX = ((w.int - displayW.int)) div 2
    screenPaddingY = ((h.int - displayH.int)) div 2

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
    else:
      screenWidth = (displayW.float32 / screenScale).int
      screenHeight = (displayH.float32 / screenScale).int

  # resize the buffers
  debug "screenPadding ", screenPaddingX, screenPaddingY

  srcRect = sdl.Rect(x:0,y:0,w:screenWidth,h:screenHeight)
  dstRect = sdl.Rect(x:screenPaddingX,y:screenPaddingY,w:displayW, h:displayH)

  clipMinX = 0
  clipMinY = 0
  clipMaxX = screenWidth - 1
  clipMaxY = screenHeight - 1

  swCanvas = newSurface(screenWidth,screenHeight)

  if swCanvas32 != nil:
    sdl.freeSurface(swCanvas32)

  swCanvas32 = sdl.createRGBSurface(0, screenWidth, screenHeight, 32, 0x000000ff'u32, 0x0000ff00'u32, 0x00ff0000'u32, 0xff000000'u32)
  if swCanvas32 == nil:
    debug "error creating swCanvas32"
    raise newException(Exception, "error creating RGB surface")

  stencilBuffer = newSurface(screenWidth, screenHeight)

  when defined(opengl):
    glViewport(dstRect.x, dstRect.y, dstRect.w, dstRect.h)

    glGenVertexArrays(1, quadVAO.addr)
    glBindVertexArray(quadVAO)
    glGenBuffers(1, quadVBO.addr)
    glBindBuffer(GL_ARRAY_BUFFER, quadVBO)

    var hw = 1.0'f
    var hh = 1.0'f

    var vertices = [
      -hw,  hh, 0'f, 0'f,
       hw,  hh, 1'f, 0'f,
      -hw, -hh, 0'f, 1'f,
       hw, -hh, 1'f, 1'f,
    ]

    glBufferData(GL_ARRAY_BUFFER, sizeof(float32) * vertices.len, vertices[0].addr, GL_STATIC_DRAW)
    glVertexAttribPointer(0.GLuint, 4.GLint, cGL_FLOAT, false, (4 * sizeof(float32)).GLsizei, cast[pointer](0))
    glEnableVertexAttribArray(0)

    glBindBuffer(GL_ARRAY_BUFFER, 0)
    glBindVertexArray(0)

    if hwCanvas != 0:
      glDeleteTextures(1, hwCanvas.addr)

    glGenTextures(1, hwCanvas.addr)
    glBindTexture(GL_TEXTURE_2D, hwCanvas)
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA.GLint, screenWidth.GLsizei, screenHeight.GLsizei, 0, GL_RGBA, GL_UNSIGNED_BYTE, nil)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE.GLint)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE.GLint)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, if linearFilter: GL_LINEAR.GLint else: GL_NEAREST.GLint)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, if linearFilter: GL_LINEAR.GLint else: GL_NEAREST.GLint)

    if existsFile(joinPath(assetPath, "LUT.png")):
      if lutTexture != 0:
        glDeleteTextures(1, lutTexture.addr)


      glGenTextures(1, lutTexture.addr)
      glBindTexture(GL_TEXTURE_2D, lutTexture)

      var lutPng = readFile(joinPath(assetPath,"LUT.png"))
      let ss = newStringStream(lutPng)
      let png = decodePNG(ss, LCT_RGBA, 8)

      glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA.GLint, png.width.GLsizei, png.height.GLsizei, 0, GL_RGBA, GL_UNSIGNED_BYTE, png.data[0].addr)
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE.GLint)
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE.GLint)
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST.GLint)
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST.GLint)

      glActiveTexture(GL_TEXTURE1)
      glBindTexture(GL_TEXTURE_2D, lutTexture)

      glActiveTexture(GL_TEXTURE0)
      glBindTexture(GL_TEXTURE_2D, 0)

      let lutID = glGetUniformLocation(shaderProgram, "LUT")
      if lutID != -1:
        glUniform1i(lutID, 1.int)

      debug "loaded LUT ", png.width, "x", png.height

    else:
      debug "no LUT.png found"

    let texID = glGetUniformLocation(shaderProgram, "tex")
    if texID != -1:
      glUniform1i(texID, 0.int)

    let canvasResID = glGetUniformLocation(shaderProgram, "canvasResolution")
    if canvasResID != -1:
      glUniform2f(canvasResID, screenWidth.float32, screenHeight.float32)
    debug "canvasResolution ", screenWidth.float32, " ", screenHeight.float32

    let displayResID = glGetUniformLocation(shaderProgram, "displayResolution")
    if displayResID != -1:
      glUniform2f(displayResID, w.float32, h.float32)
    debug "displayResolution ", w.float32, " ", h.float32

    let scaleID = glGetUniformLocation(shaderProgram, "scale")
    if scaleID != -1:
      glUniform2f(scaleID, screenScale.float32, screenScale.float32)
    debug "screenScale ", screenScale.float32, " ", screenScale.float32

  else:
    render = sdl.createRenderer(window, -1, sdl.Renderer_Accelerated or sdl.Renderer_PresentVsync)
    var rendererInfo: sdl.RendererInfo
    discard render.getRendererInfo(rendererInfo.addr)
    vsyncEnabled = (rendererInfo.flags and sdl.Renderer_PresentVsync) != 0
    debug "vsync: ", vsyncEnabled
    debug "created renderer"

    hwCanvas = render.createTexture(PIXELFORMAT_RGBA8888, TEXTUREACCESS_STREAMING, screenWidth, screenHeight)
    discard render.setRenderTarget(hwCanvas)
  createRecordBuffer(true)

  for rf in resizeFuncs:
    rf(screenWidth,screenHeight)

  debug "resize done"

proc setShaderBool*(uniformName: string, value: bool) =
  when defined(opengl):
    let loc = glGetUniformLocation(shaderProgram, uniformName)
    if loc != -1:
      glUniform1i(loc, value.int)
  else:
    discard

proc setShaderFloat*(uniformName: string, value: float32) =
  when defined(opengl):
    let loc = glGetUniformLocation(shaderProgram, uniformName)
    if loc != -1:
      glUniform1f(loc, value.float32)
  else:
    discard

proc resize*() =
  if window == nil:
    return


  if defined(emscripten):
    var r: sdl.Rect
    discard getDisplayUsableBounds(0, r.addr)
    resize(r.w,r.h)

  else:
    var windowW, windowH: cint
    window.getWindowSize(windowW.addr, windowH.addr)
    resize(windowW,windowH)

when defined(opengl):
  proc compileShader(shaderString: string, shaderType: GLenum): GLuint =
    result = glCreateShader(shaderType)

    var shaderSource = allocCStringArray([
      shaderString
    ])
    glShaderSource(result, 1, shaderSource, nil)
    glCompileShader(result)

    var res: GLint = 0
    var logLength: GLint

    glGetShaderiv(result, GL_COMPILE_STATUS, res.addr)
    glGetShaderiv(result, GL_INFO_LOG_LENGTH, logLength.addr)
    if logLength > 0:
      var i = 1
      for line in shaderString.splitLines:
        echo i, ": ", line
        i += 1
      var log = newString(logLength+1)
      glGetShaderInfoLog(result, logLength, nil, log[0].addr)
      echo log

    if res != GL_TRUE.GLint:
      raise newException(Exception, "Error compling shader")

  proc linkShader(vertexShader, fragmentShader: GLuint): GLuint =
    result = glCreateProgram()

    glAttachShader(result, vertexShader)
    glAttachShader(result, fragmentShader)
    glBindAttribLocation(result, 0, "position")
    glLinkProgram(result)

    var res: GLint = 0
    var logLength: GLint
    glGetProgramiv(result, GL_LINK_STATUS, res.addr)

    glGetProgramiv(result, GL_INFO_LOG_LENGTH, logLength.addr)
    if logLength > 0:
      var log = newString(logLength+1)
      glGetProgramInfoLog(result, logLength, nil, log[0].addr)
      echo log

    if res != GL_TRUE.GLint:
      raise newException(Exception, "Error linking shader")

    glDetachShader(result, vertexShader)
    glDetachShader(result, fragmentShader)

    glDeleteShader(vertexShader)
    glDeleteShader(fragmentShader)

    assert(glIsProgram(result) == true)

proc createWindow*(title: string, w,h: int, scale: int = 2, fullscreen: bool = false) =
  when defined(opengl):
    when defined(emscripten):
      var r: sdl.Rect
      discard getDisplayUsableBounds(0, r.addr)

      window = createWindow(title.cstring, r.x, r.y, r.w, r.h, (WINDOW_RESIZABLE or WINDOW_OPENGL).uint32)
    else:
      window = createWindow(title.cstring, WINDOWPOS_CENTERED, WINDOWPOS_CENTERED, (w * scale).cint, (h * scale).cint, 
        (WINDOW_RESIZABLE or (if fullscreen: WINDOW_FULLSCREEN_DESKTOP else: 0) or WINDOW_OPENGL.cint).uint32)

    discard glSetAttribute(GLattr.GL_CONTEXT_PROFILE_MASK, GL_CONTEXT_PROFILE_ES)
    discard glSetAttribute(GL_CONTEXT_MAJOR_VERSION, 2)
    discard glSetAttribute(GL_CONTEXT_MINOR_VERSION, 0)

    glContext = window.glCreateContext()

    when not defined(emscripten):
      loadExtensions()

    discard glSetSwapInterval(1)

    var fragSrc: string
    if existsFile(joinPath(assetPath, "frag.glsl")):
      fragSrc = readFile(joinPath(assetPath, "frag.glsl"))
      echo "using custom fragment shader"
    else:
      echo "using built in fragment shader"
      fragSrc = """
precision mediump float;

varying vec2 TexCoords;

uniform bool useCRT;
uniform sampler2D tex;
uniform vec2 canvasResolution;
uniform vec2 displayResolution;
uniform vec2 scale;

const float darkAmount = 0.8;
const float brightAmount = 1.0;
const float scanlineColor = 0.5;
const float sharpness = 2.0;

const vec4 mask1 = vec4(brightAmount, darkAmount, darkAmount, 1);
const vec4 mask2 = vec4(darkAmount, brightAmount, darkAmount , 1);
const vec4 mask3 = vec4(darkAmount, darkAmount, brightAmount, 1);

float sharpen(float pix_coord) {
    float norm = (fract(pix_coord) - 0.5) * 2.0;
    float norm2 = norm * norm;
    return floor(pix_coord) + norm * pow(norm2, sharpness) / 2.0 + 0.5;
}

vec4 ContrastSaturationBrightness(vec4 color, float brt, float sat, float con)
{
    // Increase or decrease theese values to adjust r, g and b color channels seperately
    const float AvgLumR = 0.5;
    const float AvgLumG = 0.5;
    const float AvgLumB = 0.5;

    const vec3 LumCoeff = vec3(0.2125, 0.7154, 0.0721);

    vec3 AvgLumin = vec3(AvgLumR, AvgLumG, AvgLumB);
    vec3 intensity = vec3(dot(color.rgb, LumCoeff));
    vec3 satColor = mix(intensity, color.rgb, sat);
    vec3 conColor = mix(AvgLumin, satColor, con);
    vec3 brtColor = conColor * brt;
    return vec4(brtColor.rgb,color.a);
}

void main() {
     vec2 uv = TexCoords;
     vec4 color = texture2D(tex, vec2(sharpen(uv.x * canvasResolution.x) / canvasResolution.x, sharpen(uv.y * canvasResolution.y) / canvasResolution.y));

     if(useCRT) {
       vec2 pixel = gl_FragCoord.xy / (ceil(scale)) * 3.0;
       color = ContrastSaturationBrightness(color, 1.5, 1.2, 1.0);

       float pp = mod(pixel.x, 3.0);
       if(pp <= 1.0) {
         gl_FragColor = color * mask1;
       } else if(pp <= 2.0) {
         gl_FragColor = color * mask2;
       } else {
         gl_FragColor = color * mask3;
       }
       if(mod(pixel.y, 3.0) <= 1.0) {
         gl_FragColor.rgb *= scanlineColor;
       } else {
         gl_FragColor = color;
       }
    }
}
"""
    let fs = compileShader(fragSrc, GL_FRAGMENT_SHADER)

    var vertSrc: string
    if existsFile(joinPath(assetPath, "vert.glsl")):
      vertSrc = readFile(joinPath(assetPath, "vert.glsl"))
      echo "using custom vertex shader"
    else:
      echo "using built-in vertex shader"
      vertSrc = """
precision mediump float;

attribute vec4 posUV;

varying vec2 TexCoords;

void main() {
    gl_Position = vec4(posUV.xy, 0, 1);
    TexCoords = posUV.zw;
}
"""

    let vs = compileShader(vertSrc, GL_VERTEX_SHADER)
    shaderProgram = linkShader(vs, fs)

    glUseProgram(shaderProgram)

  else:
    when defined(android):
      try:
        discard sdl.init(INIT_VIDEO)
        var dm: DisplayMode
        discard getCurrentDisplayMode(0, dm.addr)
        window = createWindow(title.cstring, WINDOWPOS_UNDEFINED, WINDOWPOS_UNDEFINED, dm.w, dm.h, WINDOW_FULLSCREEN)
        debug "created window ", dm.w, dm.h
      except Exception as e:
        echo e.getStackTrace()
        errorPopup(&"Error: {e.name}", e.msg)
        sdl.quit()
        return

    elif defined(emscripten):
      var r: sdl.Rect
      discard getDisplayUsableBounds(0, r.addr)

      window = createWindow(title.cstring, r.x, r.y, r.w, r.h, (WINDOW_RESIZABLE).uint32)

    else:
      window = createWindow(title.cstring, WINDOWPOS_CENTERED, WINDOWPOS_CENTERED, (w * scale).cint, (h * scale).cint, 
        (WINDOW_RESIZABLE or (if fullscreen: WINDOW_FULLSCREEN_DESKTOP else: 0)).uint32)

  if window == nil:
    raise newException(Exception, "Could not create window")

  targetScreenWidth = w
  targetScreenHeight = h

  discard setHint("SDL_HINT_RENDER_VSYNC", "1")
  discard setHint("SDL_RENDER_SCALE_QUALITY", "0")

  var displayW, displayH: cint
  window.getWindowSize(displayW.addr, displayH.addr)

  resize(displayW,displayH)

  window.raiseWindow()

  debug "nico.createWindow finished"

proc readFile*(filename: string): string =
  debug "readFile ", filename
  var fp = rwFromFile(filename, "rb")

  if fp == nil:
    raise newException(IOError, "Unable to open file: " & filename)

  let size = rwSize(fp).int
  var buffer = newSeq[uint8](size)

  var offset = 0
  while offset < size:
    let r = rwRead(fp, buffer[offset].addr, 1.csize_t, 1.csize_t)
    offset += r.int
    if r == 0:
      break

  if rwClose(fp) != 0:
    debug getError()

  result = cast[string](buffer)

proc loadSurfaceFromPNG*(filename: string, callback: proc(surface: common.Surface)) =
  var buffer = readFile(filename)
  let ss = newStringStream(buffer)

  let png = decodePNG(ss, nil)

  let pngInfo = getInfo(png)

  debug "loadSurfaceFromPNG ", filename, " size: ", pngInfo.width, "x", pngInfo.height, " type: ", pngInfo.mode.colorType

  var surface = newSurface(pngInfo.width, pngInfo.height)
  surface.filename = filename
  surface.w = pngInfo.width
  surface.h = pngInfo.height

  if pngInfo.mode.colorType == LCT_RGBA:
    debug "loading RGBA image, converting to indexed using current palette ", filename
    surface.channels = 4
    surface.data = cast[seq[uint8]](png.pixels)
    callback(surface.convertToIndexed())

  elif pngInfo.mode.colorType == LCT_RGB:
    debug "loading RGB image, converting to indexed using current palette ", filename
    surface.channels = 3
    surface.data = cast[seq[uint8]](png.pixels)
    callback(surface.convertToIndexed())

  elif pngInfo.mode.colorType == LCT_PALETTE:
    debug "loading paletted image ", filename
    surface.channels = 1
    surface.palette = @[]
    for i, c in pngInfo.mode.palette:
      surface.palette.add((c.r.uint8, c.g.uint8, c.b.uint8))
    surface.data = cast[seq[uint8]](png.pixels)
    callback(surface)

proc loadSurfaceFromPNGNoConvert*(filename: string, callback: proc(surface: common.Surface)) =
  var buffer = readFile(filename)
  let ss = newStringStream(buffer)

  let png = decodePNG(ss, nil)

  let pngInfo = getInfo(png)

  debug "loadSurfaceFromPNGNoConvert ", filename, " size: ", pngInfo.width, "x", pngInfo.height, " type: ", pngInfo.mode.colorType

  var surface = newSurface(pngInfo.width, pngInfo.height)
  surface.filename = filename
  surface.w = pngInfo.width
  surface.h = pngInfo.height

  if pngInfo.mode.colorType == LCT_RGBA:
    debug "loading RGBA image ", filename
    surface.channels = 4
    surface.data = cast[seq[uint8]](png.pixels)
    callback(surface)

  elif pngInfo.mode.colorType == LCT_PALETTE:
    debug "loading paletted image ", filename
    surface.channels = 1
    surface.palette = @[]
    for i, c in pngInfo.mode.palette:
      surface.palette.add((c.r.uint8, c.g.uint8, c.b.uint8))
    surface.data = cast[seq[uint8]](png.pixels)
    callback(surface)


proc refreshSpritesheets*() =
  for i in 0..<spriteSheets.len:
    if spriteSheets[i] != nil and spriteSheets[i].filename != "":
      loadSurfaceFromPNG(joinPath(assetPath,spriteSheets[i].filename)) do(surface: common.Surface):
        debug "refreshed spritesheet", spriteSheets[i].filename, surface.w, surface.h, spriteSheets[i].tw, spriteSheets[i].th
        spriteSheets[i].data = surface.data
        spriteSheets[i].w = surface.w
        spriteSheets[i].h = surface.h
        spriteSheets[i].channels = surface.channels

proc readJsonFile*(filename: string): JsonNode =
  return parseJson(readFile(filename))

proc saveJsonFile*(filename: string, data: JsonNode) =
  var fp = rwFromFile(filename, "w")
  var str = data.pretty()
  discard rwWrite(fp, str[0].addr, 1.csize_t, str.len.csize_t)
  discard fp.close(fp)

proc present*() =

  when defined(opengl):
    convertToRGBA(swCanvas, swCanvas32.pixels, swCanvas32.pitch, screenWidth, screenHeight)

    glClearColor(0,0,0,0)
    glClear(GL_COLOR_BUFFER_BIT)

    # copy swCanvas32 to texture
    glActiveTexture(GL_TEXTURE0)
    glBindTexture(GL_TEXTURE_2D, hwCanvas)
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, swCanvas32.w, swCanvas32.h, GL_RGBA, GL_UNSIGNED_BYTE, swCanvas32.pixels)

    # draw to screen
    glBindVertexArray(quadVAO)
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4)

    window.glSwapWindow()
  else:
    convertToABGR(swCanvas, swCanvas32.pixels, swCanvas32.pitch, screenWidth, screenHeight)
    discard render.setRenderTarget(nil)
    # copy swCanvas to hwCanvas

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
        copyMem(recordFrame.data[0].addr, swCanvas.data[0].addr, swCanvas.w * swCanvas.h)
        recordFrames.add([recordFrame])
        recordFrame = newSurface(swCanvas.w, swCanvas.h)

proc saveScreenshot*() =
  createDir(writePath & "/screenshots")
  var frame = recordFrames[recordFrames.size-1]
  var abgr = newSeq[uint8](screenWidth*screenHeight*4)
  # convert RGBA to BGRA
  convertToRGBA(frame, abgr[0].addr, screenWidth*4, screenWidth, screenHeight)
  let filename = joinPath(writePath, joinPath("screenshots", "screenshot-$1T$2.png".format(getDateStr(), getClockStr())))
  debug "saved screenshot to: ", filename

proc saveRecording*() =
  # TODO: do this in another thread?
  when defined(gif):
    try:
      createDir(writePath & "/video")
    except OSError:
      debug "unable to create video output directory"
      return

    var palette: array[maxPaletteSize,array[3,uint8]]
    for i in 0..<maxPaletteSize:
      palette[i] = cast[array[3,uint8]](currentPalette.data[i])

    let filename = joinPath(writePath, joinPath("video", "video-$1T$2.gif".format(getDateStr(), getClockStr().replace(":","-"))))

    var gif = newGIF(
      filename.cstring,
      (screenWidth*gifScale).uint16,
      (screenHeight*gifScale).uint16,
      palette[0][0].addr, if currentPalette.size <= 16: 4 else: 8, 0
    )

    if gif == nil:
      debug "unable to create gif: ", filename
      return

    debug "created gif: ", filename
    var pixels: ptr[UncheckedArray[uint8]]

    var frames = 0
    block exportFrames:
      for j in 0..<recordFrames.size:
        var frame = recordFrames[j]

        pixels = cast[ptr UncheckedArray[uint8]](gif.frame)

        if gifScale != 1:
          for y in 0..<screenHeight*gifScale:
            for x in 0..<screenWidth*gifScale:
              let sx = x div gifScale
              let sy = y div gifScale
              if sy*frame.w+sx > frame.data.len - 1:
                debug "went past end of input data on frame ", j, " of ", recordFrames.size
                break exportFrames
              pixels[y*screenWidth*gifScale+x] = frame.data[sy*frame.w+sx]
        else:
          copyMem(gif.frame, frame.data[0].addr, screenWidth*screenHeight)
        gif.add_frame(if fullSpeedGif: 2 else: 3)
        frames += 1

    gif.close()
    echo "completed saving gif ", filename, " frames: ", frames

proc getKeyNamesForBtn*(btn: NicoButton): seq[string] =
  result = newSeq[string]()
  for scancode in keymap[btn]:
    result.add($(getKeyFromScancode(cast[sdl.Scancode](scancode)).getKeyName()))

proc getKeyMap*(): string =
  result = ""
  for btn,scancodes in keymap:
    result.add($btn & ":")
    for i,scancode in scancodes:
      result.add(getKeyFromScancode(cast[sdl.Scancode](scancode)).getKeyName())
      if i < scancodes.high:
        result.add(",")
    if btn != NicoButton.high:
      result.add(";")

proc setKeyMap*(mapstr: string) =
  if mapstr.len == 0:
    echo "setKeyMap: empty string"
    return
  debug "setKeyMap: ", mapstr
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
      let scancode = getKeyFromName(keystr.cstring).getScancodeFromKey().toNicoScancode()
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

proc appHandleEvent(evt: sdl.Event) =
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
    current_time = sdl.getTicks()
    focused = true

  elif evt.kind == FingerDown:
    if evt.tfinger.touchId == MOUSE_TOUCHID:
      return
    let sx = evt.tfinger.x.float32 * displayWidth.float32
    let sy = evt.tfinger.y.float32 * displayHeight.float32
    let scale = displayWidth.float32 / screenWidth.float32

    touches.add(common.Touch(
      state: tsStarted,
      id: evt.tfinger.fingerId.int,
      sx: sx,
      sy: sy,
      x: (sx / scale).int,
      y: (sy / scale).int,
      xrel: evt.tfinger.dx,
      yrel: evt.tfinger.dy,
      xrelraw: evt.tfinger.dx,
      yrelraw: evt.tfinger.dy,
    ))
    return

  elif evt.kind == FingerUp:
    if evt.tfinger.touchId == MOUSE_TOUCHID:
      return

    let sx = evt.tfinger.x.float32 * displayWidth.float32
    let sy = evt.tfinger.y.float32 * displayHeight.float32
    let scale = displayWidth.float32 / screenWidth.float32

    for t in touches.mitems:
      if t.id == evt.tfinger.fingerId.int:
        t.state = tsEnded
        t.xrel = (sx - t.sx) / scale
        t.yrel = (sy - t.sy) / scale
        t.xrelraw = sx - t.sx
        t.yrelraw = sy - t.sy
        t.sx = sx
        t.sy = sy
        t.x = (sx / scale).int
        t.y = (sy / scale).int
        return

  elif evt.kind == FingerMotion:
    if evt.tfinger.touchId == MOUSE_TOUCHID:
      return

    let sx = evt.tfinger.x.float32 * displayWidth.float32
    let sy = evt.tfinger.y.float32 * displayHeight.float32
    let scale = displayWidth.float32 / screenWidth.float32

    for t in touches.mitems:
      if t.id == evt.tfinger.fingerId.int:
        t.state = tsMoved
        t.xrel = (sx - t.sx) / scale
        t.yrel = (sy - t.sy) / scale
        t.xrelraw = sx - t.sx
        t.yrelraw = sy - t.sy
        t.sx = sx
        t.sy = sy
        t.x = (sx / scale).int
        t.y = (sy / scale).int
        return

  elif evt.kind == MouseWheel:
    mouseWheelState = evt.wheel.y

  elif evt.kind == MouseButtonDown:
    if touchMouseEmulation == false and evt.motion.which == TOUCH_MOUSEID:
      return

    discard captureMouse(true)
    if evt.button.button < 4:
      mouseButtonsDown[evt.button.button-1] = true
      mouseButtons[evt.button.button-1] = 1

  elif evt.kind == MouseButtonUp:
    if touchMouseEmulation == false and evt.motion.which == TOUCH_MOUSEID:
      return

    if evt.button.button < 4:
      discard captureMouse(false)
      mouseButtonsDown[evt.button.button-1] = false
      mouseButtons[evt.button.button-1] = -1

  elif evt.kind == MouseMotion:
    if touchMouseEmulation == false and evt.motion.which == TOUCH_MOUSEID:
      return

    if evt.motion.which != TOUCH_MOUSEID:
      mouseDetected = true

    mouseRawX = evt.motion.x - screenPaddingX
    mouseRawY = evt.motion.y - screenPaddingY
    mouseX = (mouseRawX.float32 / screenScale.float32).int
    mouseY = (mouseRawY.float32 / screenScale.float32).int

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
        case evt.cbutton.button:
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
        of CONTROLLER_BUTTON_LEFTSTICK:
          controller.setButtonState(pcL3, down)
        of CONTROLLER_BUTTON_RIGHTSTICK:
          controller.setButtonState(pcR3, down)
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
        case evt.caxis.axis:
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
      debug "Resize Event ", evt.window.data1, " x ", evt.window.data2
      resize(evt.window.data1, evt.window.data2)
      when not defined(opengl):
        discard render.setRenderTarget(nil)
        discard render.setRenderDrawColor(0,0,0,255)
        discard render.renderClear()
    elif evt.window.event == WindowEvent_Size_Changed:
      debug "Size Changed Event ", evt.window.data1, " x ", evt.window.data2
      discard
    elif evt.window.event == WindowEvent_FocusLost:
      focused = false
    elif evt.window.event == WindowEvent_FocusGained:
      focused = true
      refreshSpritesheets()
    elif evt.window.event == WindowEvent_Shown:
      focused = true
      refreshSpritesheets()
      pauseAudioDevice(audioDeviceId, 0)
    elif evt.window.event == WindowEvent_Hidden:
      focused = false
      pauseAudioDevice(audioDeviceId, 1)

  elif evt.kind == KeyDown or evt.kind == KeyUp:
    let sym = evt.key.keysym.sym
    let mods = evt.key.keysym.mods
    let scancode = evt.key.keysym.scancode
    let down = evt.kind == Keydown

    for listener in keyListeners:
      if listener(sym.int, mods.uint16, scancode.int, down.bool):
        return

    if sym == sdl.Keycode.K_AC_BACK:
      controllers[0].setButtonState(pcBack, down)

    elif sym == (sdl.Keycode.K_q) and down and (mods and uint16(KMOD_CTRL)) != 0:
      # ctrl+q to quit
      keepRunning = false

    elif sym == (sdl.Keycode.K_f) and not down and (mods and uint16(KMOD_CTRL)) != 0:
      if getFullscreen():
        setFullscreen(false)
        resize()
      else:
        setFullscreen(true)
        resize()
      return

    elif sym == (sdl.Keycode.K_return) and not down and (mods and uint16(KMOD_ALT)) != 0:
      if getFullscreen():
        setFullscreen(false)
        resize()
      else:
        setFullscreen(true)
        resize()
      return

    elif sym == (sdl.Keycode.K_F8) and down:
      # restart recording from here
      createRecordBuffer(true)

    elif sym == (sdl.Keycode.K_F9) and down:
      saveRecording()

    elif sym == (sdl.Keycode.K_F10) and down:
      saveScreenshot()

    elif sym == (sdl.Keycode.K_F11) and down:
      when system.hostOS == "windows":
        discard startProcess("explorer", writePath, [writePath], nil, {poUsePath})
      elif system.hostOS == "macosx":
        discard startProcess("open", writePath, [writePath], nil, {poUsePath})
      elif system.hostOS == "linux":
        discard startProcess("xdg-open", writePath, [writePath], nil, {poUsePath})

    if evt.key.repeat == 0:
      for btn,btnScancodes in keymap:
        for btnScancode in btnScancodes:
          if scancode.toNicoScancode() == btnScancode:
            controllers[0].setButtonState(btn, down)

proc checkInput() =
  var evt: sdl.Event

  while pollEvent(evt.addr) == 1:
    var handled = false
    if evt.kind in [MouseButtonDown, MouseButtonUp, MouseMotion, KeyDown, KeyUp, MouseWheel, TextInput, ControllerButtonUp, ControllerButtonDown, ControllerAxisMotion]:
      # convert to NicoEvent
      var e: common.Event
      e.kind = case evt.kind:
      of MouseButtonDown:
        ekMouseButtonDown
      of MouseButtonUp:
        ekMouseButtonUp
      of MouseMotion:
        ekMouseMotion
      of KeyDown:
        ekKeyDown
      of KeyUp:
        ekKeyUp
      of MouseWheel:
        ekMouseWheel
      of TextInput:
        ekTextInput
      of ControllerButtonDown:
        ekButtonDown
      of ControllerButtonUp:
        ekButtonUp
      of ControllerAxisMotion:
        ekAxisMotion
      else:
        ekMouseButtonDown

      case evt.kind:
      of MouseButtonUp,MouseButtonDown:
        e.button = evt.button.button
        e.x = evt.button.x.int div screenScale
        e.y = evt.button.y.int div screenScale
        e.clicks = evt.button.clicks
      of MouseWheel:
        e.ywheel = evt.wheel.y
      of MouseMotion:
        e.x = evt.motion.x.int div screenScale
        e.y = evt.motion.y.int div screenScale
        e.xrel = evt.motion.xrel.float32 / screenScale.float32
        e.yrel = evt.motion.yrel.float32 / screenScale.float32
      of KeyDown, KeyUp:
        e.keycode = toNicoKeycode(evt.key.keysym.sym)
        e.scancode = toNicoScancode(evt.key.keysym.scancode)
        e.mods = evt.key.keysym.mods
        e.repeat = evt.key.repeat

        let down = evt.kind == Keydown
        if down:
          keysDown[toNicoKeycode(evt.key.keysym.sym)] = 1.uint32
          aKeyWasPressed = true
        else:
          keysDown[toNicoKeycode(evt.key.keysym.sym)] = 0.uint32
          aKeyWasReleased = true

      of ControllerButtonDown, ControllerButtonUp:
        e.which = evt.cbutton.which.uint8
        e.button = evt.cbutton.button.uint8
      of ControllerAxisMotion:
        e.which = evt.caxis.which.uint8
        e.button = evt.caxis.axis.uint8
        e.xrel = evt.caxis.value.float32 / 32767'f
      of TextInput:
        e.text = $evt.text.text
      else:
        discard

      for el in eventListeners:
        let ret = el(e)
        if ret:
          handled = true
          break
    if not handled:
      appHandleEvent(evt)

proc setScreenSize*(w,h: int) =
  window.setWindowSize(w,h)
  resize()

proc queueMixerAudio*()

proc queuedAudioSize*(): int =
  return getQueuedAudioSize(audioDeviceId).int div sizeof(float32)

var realDt: float32

proc getRealDt*(): float32 =
  return realDt

proc step*() {.cdecl.} =
  checkInput()

  next_time = sdl.getTicks()
  var diff = float32(next_time - current_time)/1000f * frameMult.float32
  if diff > timeStep * 2f:
    diff = timeStep
  acc += diff
  current_time = next_time

  if acc > timeStep:
    realDt = acc

  while acc > timeStep:
    when defined(profile):
      profileStartFrame()

    for controller in mitems(controllers):
      controller.update()

    profileBegin("update")
    updateFunc(timeStep)
    profileEnd()

    for controller in mitems(controllers):
      controller.postUpdate()

    for touch in touches.mitems:
      if touch.state == tsStarted or touch.state == tsMoved:
        touch.state = tsHeld

    touches.keepItIf(it.state notin [tsEnded, tsCancelled])

    frame += 1
    if acc > timeStep and acc < timeStep+timeStep:
      if window != nil:
        profileBegin("draw")
        drawFunc()
        profileEnd()
        flip()

    for i,b in mouseButtonsDown:
      if b:
        mouseButtons[i] += 1
      else:
        mouseButtons[i] = 0

    for k,v in keysDown:
      if v != 0:
        keysDown[k] += 1

    when defined(profile):
      profileEndFrame()

    mouseWheelState = 0

    mouseRelX = (mouseRawX - lastMouseRawX).float32 / screenScale.float32
    mouseRelY = (mouseRawY - lastMouseRawY).float32 / screenScale.float32

    lastMouseRawX = mouseRawX
    lastMouseRawY = mouseRawY
    lastMouseX = mouseX
    lastMouseY = mouseY

    acc -= timeStep

    if not noAudio and queuedAudioSize() < audioBufferSize * 4:
      profileBegin("audio")
      queueMixerAudio()
      profileEnd()

    realDt = 0

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

var configInitialised = false

when defined(emscripten):
  {.emit:"""
  #include <emscripten.h>
  """.}

when defined(emscripten):
  proc initConfigDone*() {.exportc,cdecl.} =
    configInitialised = true
    debug "initConfigDone"

  proc initConfig() =
    debug "initConfig"
    configInitialised = false
    {.emit:"""
    EM_ASM(
       //create your directory where we keep our persistent data
       FS.mkdir('/IDBFS'); 

       //mount persistent directory as IDBFS
       FS.mount(IDBFS,{},'/IDBFS');

       Module.print("start file sync..");
       //flag to check when data are synchronized
       Module.syncdone = 0;

       //populate persistent_data directory with existing persistent source data 
      //stored with Indexed Db
      //first parameter = "true" mean synchronize from Indexed Db to 
      //Emscripten file system,
      // "false" mean synchronize from Emscripten file system to Indexed Db
      //second parameter = function called when data are synchronized
      FS.syncfs(true, function(err) {
                       Module.print("syncfs done");
                       Module.print(err);
                       assert(!err);
                       ccall("initConfigDone", "v");
                       Module.print("end file sync..");
                       Module.syncdone = 1;
      });
    );
    """.}

  proc syncIDBFS() =
    {.emit:"""
    EM_ASM(
      Module.syncdone = 0;
      FS.syncfs(false, function(err) {
                       assert(!err);
                       Module.print("end file sync..");
                       Module.syncdone = 1;
      });
    );
    """.}

else:
  proc initConfig() =
    configInitialised = true

proc loadConfig*() =
  debug "loadConfig"
  let defaultPath = joinPath(assetPath, "config.ini")
  let path = joinPath(writePath, "config.ini")
  try:
    config = loadConfig(path)
    debug "loaded config from " & path
  except IOError:
    try:
      config = loadConfig(defaultPath)
      debug "loaded config from " & defaultPath
    except IOError:
      debug "no config file loaded"
      config = newConfig()

proc saveConfig*() =
  let path = joinPath(writePath, "config.ini")
  debug "saving config to " & path
  assert(config != nil)
  try:
    config.writeConfig(path)
    debug "saved config to " & path

    when defined(emscripten):
      syncIDBFS()

  except IOError:
    debug "error saving config"


proc updateConfigValue*(section, key, value: string) =
  if config == nil:
    debug "updateConfigValue but config is nil"
    return

  debug "updateConfigValue", key, value
  config.setSectionKey(section, key, value)

proc getConfigValue*(section, key: string, default: string = ""): string =
  if config == nil:
    debug "getConfigValue ", section, " ", key, " but config is nil, returning default ", default
    return default

  result = config.getSectionValue(section, key)
  if result == "":
    result = default
  debug "getConfigValue", section, key, result

proc queueAudio*(samples: var seq[float32]) =
  let ret = queueAudio(audioDeviceId, samples[0].addr, (samples.len * sizeof(float32)).uint32)
  if ret != 0:
    raise newException(Exception, "error queueing audio: " & $getError())

proc processSynth(self: var Channel): float32 =
  if audioSampleId mod 2 == 0:
    if audioClock:
      if self.synthDataIndex >= 0:
        let i = self.synthDataIndex div (self.synthData.speed.int + 1)
        if i < self.synthData.length.int:
          self.shape = self.synthData.steps[i].shape
          self.basefreq = note(self.synthData.steps[i].note)
          self.targetFreq = self.basefreq
          self.freq = self.basefreq
          self.trigger = true
          self.init = self.synthData.steps[i].volume
          self.env = 0
          self.envPhase = 0
          self.pchange = 0
          self.synthDataIndex += 1
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
    elif audioClock:
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
        let lsb: uint32 = (self.lfsr and 1).uint32
        self.lfsr = self.lfsr shr 1
        if lsb == 1:
          self.lfsr = self.lfsr xor 0xb400
        self.outvalue = if lsb == 1: 1.0 else: -1.0
        self.nextClick = ((1.0'f / self.freq) * sampleRate).int
      self.nextClick -= 1
    o = self.outvalue

  of synNoise2:
    if self.freq != 0.0:
      if self.nextClick <= 0:
        let lsb: uint32 = (self.lfsr2 and 1).uint32
        self.lfsr2 = self.lfsr2 shr 1
        if lsb == 1:
          self.lfsr2 = self.lfsr2 xor 0x0043
        self.outvalue = if lsb == 1: 1.0 else: -1.0
        self.nextClick = ((1.0'f / self.freq) * sampleRate).int
      self.nextClick -= 1
    o = self.outvalue

  of synWav:
    if self.freq != 0.0:
      o = self.wavData[(self.phase mod 1.0 * 32.0).int].float32 / 16.0

  else:
    o = 0.0
  o = o * self.gain

  if audioSampleId mod 2 == 0:
    if audioClock:
      if self.length > 0:
        self.length -= 1
        if self.length == 0:
          self.kind = channelNone

      self.envPhase += 1

      if self.vibamount > 0:
        self.freq = self.basefreq + sin(self.envPhase.float32 / self.vibspeed.float32) * self.basefreq * 0.03f * self.vibamount.float32

      if self.pchange != 0:
        self.targetFreq = self.targetFreq + self.targetFreq * self.pchange.float32 / 128.0f
        self.basefreq = self.targetFreq
        self.freq = self.targetFreq
        if self.targetFreq > sampleRate * 0.5f:
          self.targetFreq = sampleRate * 0.5f

      # determine the env value
      if self.env < 0:
        # decay
        self.envValue = clamp(lerp(self.init.float32 / 15.0f, 0.0f, self.envPhase / (-self.env * 4)), 0.0f, 1.0f)
        if self.envValue <= 0f:
          self.kind = channelNone
      elif self.env > 0:
        # attack
        self.envValue = clamp(lerp(self.init.float32 / 15.0f, 1.0f, self.envPhase / (self.env * 4)), 0.0f, 1.0f)
      elif self.env == 0:
        self.envValue = self.init.float32 / 15.0f

      self.gain = clamp(lerp(self.gain, self.envValue, 0.9f), 0.0f, 1.0f)

  return o * sfxVolume



proc process(self: var Channel): float32 =
  case self.kind:
  of channelNone:
    return 0.0
  of channelSynth:
    return self.processSynth()
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
    if audioSampleId mod 2 == 0 and not self.musicStereo:
      return self.outvalue
    var o: float32
    o = self.musicBuffers[self.musicBuffer].interpolatedLookup(self.phase) * self.gain
    self.phase += (self.musicSampleRate * invSampleRate)
    if self.phase >= musicBufferSize.float32:
      # end of buffer, switch buffers and fill
      self.phase = 0.0f
      var read = stb_vorbis_get_samples_float_interleaved(self.musicFile, if self.musicStereo: 2 else: 1, self.musicBuffers[self.musicBuffer][0].addr, musicBufferSize)
      if self.musicStereo:
        read *= 2
      self.musicBuffer = (self.musicBuffer + 1) mod 2
      if read != musicBufferSize:
        if self.loop != 0:
          if self.loop > 0:
            self.loop -= 1
          discard stb_vorbis_seek_frame(self.musicFile, 0)
        else:
          self.resetChannel()
    self.outvalue = o * musicVolume
    return o * musicVolume
  of channelCallback:
    if self.callbackStereo or audioSampleId mod 2 == 0:
      self.outvalue = self.callback(audioInSample) * self.gain
    return self.outvalue * self.gain

proc queueMixerAudio*() =
  var nDequeuedSamples = 0
  if audioInDeviceId != 0:
    nDequeuedSamples = dequeueAudio(audioInDeviceId, inputSamples[0].addr, (audioBufferSize * sizeof(float32)).uint32).int div sizeof(float32)

    if nDequeuedSamples < audioBufferSize:
      debug "didn't dequeue enough samples: ", nDequeuedSamples

  for i in 0..<audioBufferSize:

    if audioInDeviceId != 0:
      audioInSample = inputSamples[i]
    else:
      audioInSample = 0'f

    if i mod 2 == 0:
      nextAudioClock -= 1
      if nextAudioClock <= 0:
        audioClock = true
        nextAudioClock = (sampleRate div 60)
      else:
        audioClock = false

      nextTick -= 1
      if nextTick <= 0 and audioTickCallback != nil:
        audioTickCallback()
        nextTick = (sampleRate / (currentBpm.float32 / 60.0 * currentTpb.float32)).int

    outputSamples[i] = 0
    for j in 0..<audioChannels.len:
      let s = audioChannels[j].process()
      audioChannels[j].outputBuffer.add(s)
      outputSamples[i] += s * masterVolume

    audioSampleId += 1

  queueAudio(outputSamples)

proc initMixer*(wantsAudioIn = false) =
  debug "initMixer"
  if sdl.init(INIT_AUDIO) != 0:
    raise newException(Exception, "Unable to initialize audio")

  var audioSpec: AudioSpec
  audioSpec.freq = sampleRate.cint
  audioSpec.format = AUDIO_F32
  audioSpec.channels = 2
  audioSpec.samples = audioBufferSize.uint16
  audioSpec.padding = 0
  audioSpec.callback = nil
  audioSpec.userdata = nil

  var obtained: AudioSpec
  audioDeviceId = openAudioDevice(nil, 0, audioSpec.addr, obtained.addr, 0)
  if audioDeviceId == 0:
    noAudio = true
    debug "Unable to open audio device: " & $getError()
    return
  else:
    debug "opened audio output ", obtained.freq.int, " channels: ", obtained.channels.int, " format: ", obtained.format.toHex()
    noAudio = false

  sampleRate = obtained.freq.float32
  invSampleRate = 1.0 / obtained.freq.float32

  if wantsAudioIn:
    var audioInSpec: AudioSpec
    audioInSpec.freq = 44100.cint
    audioInSpec.format = AUDIO_F32
    audioInSpec.channels = 2
    audioInSpec.samples = 1024
    audioInSpec.padding = 0
    audioInSpec.callback = nil
    audioInSpec.userdata = nil

    let nAudioInDevices = getNumAudioDevices(1)

    debug "nAudioInDevices: ", nAudioInDevices
    for i in 0..<nAudioInDevices:
      debug "id: ", i, " = ", getAudioDeviceName(i, 1)

    if nAudioInDevices > 0:
      audioInDeviceId = openAudioDevice(nil, 1, audioInSpec.addr, obtained.addr, 0)
      if audioInDeviceId == 0:
        raise newException(Exception, "Unable to open audio input device: " & $getError())
      else:
        debug "opened audio input  ", obtained.freq.int, " channels: ", obtained.channels.int, " format: ", obtained.format.toHex()
      inputSamples = newSeq[float32](audioBufferSize)
      pauseAudioDevice(audioInDeviceId, 0)

  for c in audioChannels.mitems:
    c.lfsr = 0xfeed
    c.lfsr2 = 0x00fe
    c.glide = 0
    c.outputBuffer = initRingBuffer[float32](1024)
    for j in 0..<32:
      c.wavData[j] = rand(16).uint8

  outputSamples = newSeq[float32](audioBufferSize)

  queueMixerAudio()
  pauseAudioDevice(audioDeviceId, 0)
  debug "audio initialised using main thread"

proc init*(org: string, app: string) =
  discard setHint("SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS", "1")

  when defined(emscripten):
    if sdl.init(INIT_VIDEO or INIT_AUDIO or INIT_JOYSTICK or INIT_GAMECONTROLLER or INIT_EVENTS) != 0:
      debug sdl.getError()
      quit(1)
  else:
    if sdl.init(INIT_EVERYTHING) != 0:
      debug sdl.getError()
      quit(1)

  # add keyboard controller
  when not defined(android):
    controllers.add(newNicoController(-1))

    basePath = $sdl.getBasePath()
    debug "basePath: ", basePath

    assetPath = basePath / "assets"
    debug "assetPath: ", assetPath

    when defined(emscripten):
      writePath = "/IDBFS"
    else:
      writePath = $sdl.getPrefPath(org,app)

    debug "writePath: ", writePath

    discard gameControllerAddMappingsFromFile((assetPath / "gamecontrollerdb.txt").cstring)
    discard gameControllerAddMappingsFromFile((writePath / "gamecontrollerdb.txt").cstring)

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

  stopTextInput()

  initConfig()

  initMixer()

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

when defined(emscripten):
  type cbool* {.importc: "bool", nodecl.} = uint8
  type em_callback_func* = proc() {.cdecl.}
  {.push importc.}
  proc emscripten_set_main_loop*(f: em_callback_func, fps: cint, simulate_infinite_loop: cbool)
  proc emscripten_cancel_main_loop*()
  {.pop.}

  template mainLoop*(statement, actions: untyped): untyped =
    proc emscLoop {.cdecl.} =
      if not statement:
        debug "end main loop"
        emscripten_cancel_main_loop()
      else:
        actions

    emscripten_set_main_loop(emscLoop, 0 ,1)

proc stopLastRun*() =
  when defined(emscripten):
    debug "stopLastRun"
    emscripten_cancel_main_loop()

proc run*() =
  debug "backend.run"
  keepRunning = true

  when defined(emscripten):
    mainLoop keepRunning:
      if configInitialised and initFuncCalled == false:
        debug "calling initFunc"
        initFuncCalled = true
        debug "initFuncCalled = true"
        initFunc()

      if configInitialised:
        step()

  else:
    while keepRunning:
      var frameStartTime = getPerformanceCounter()
      if configInitialised and initFuncCalled == false:
        initFunc()
        initFuncCalled = true
        debug "initFuncCalled = true"

      if configInitialised:
        step()

      if not vsyncEnabled:
        # calculate how long we should sleep for to reduce cpu usage, if we have vsync this will do it for us
        let frameEndTime = getPerformanceCounter()
        let frameTime = ((frameEndTime - frameStartTime)*1000).float / getPerformanceFrequency().float
        let targetFrameTime = 1000.0 / frameRate.float
        let sleepTime = targetFrameTime - frameTime
        #echo "frame time: ", frameTime, " target: ", targetFrameTime, " sleep time: ", sleepTime
        if sleepTime > 0f:
          delay(sleepTime.uint32)
    sdl.quit()

when defined(emscripten):
  var wait = true

proc waitUntilReady*() =
  when defined(emscripten):
    mainLoop wait:
      debug "waiting..."
      if configInitialised:
        debug "ready to continue"
        wait = false

proc newSfxBuffer(filename: string): SfxBuffer =
  result = new(SfxBuffer)
  var data = readFile(filename)
  var v = stb_vorbis_open_memory(data[0].addr, data.len, nil, nil)
  if v == nil:
    raise newException(IOError, "error opening vorbis file: " & filename)

  let info = stb_vorbis_get_info(v)

  let nSamples = stb_vorbis_stream_length_in_samples(v).int

  result.data = newSeq[float32](nSamples * info.channels.int)
  result.rate = info.samplerate.float32
  result.channels = info.channels
  result.length = nSamples

  let count = stb_vorbis_get_samples_float_interleaved(v, info.channels, result.data[0].addr, nSamples * info.channels.int)
  if count < nSamples:
    debug "only loaded ", count, " samples from ", filename, " expected: ", nSamples

  stb_vorbis_close(v)

proc resetChannel*(channel: var Channel) =
  channel.kind = channelNone
  channel.synthDataIndex = -1
  if channel.musicFile != nil:
    stb_vorbis_close(channel.musicFile)
    channel.musicFile = nil

proc loadSfx*(index: SfxId, filename: string) =
  if index < 0 or index > 63:
    return
  sfxBufferLibrary[index] = newSfxBuffer(joinPath(assetPath, filename))

proc loadMusic*(index: int, filename: string) =
  if index < 0 or index > 63:
    return
  musicFileLibrary[index] = joinPath(assetPath, filename)

proc getMusic*(channel: AudioChannelId): int =
  if audioChannels[channel].kind != channelMusic:
    return -1
  return audioChannels[channel].musicIndex

proc findFreeChannel(priority: float32): AudioChannelId =
  for i,c in audioChannels:
    if c.kind == channelNone:
      return i
  var lowestPriority: float32 = Inf
  var bestChannel = audioChannelAuto
  for i,c in audioChannels:
    if c.priority < lowestPriority:
      lowestPriority = c.priority
      bestChannel = i
  if lowestPriority > priority or bestChannel < 0:
    return audioChannelAuto
  return bestChannel

proc sfx*(channel: AudioChannelId = -1, index: SfxId, loop: int = 1, gain: Pfloat = 1.0, pitch: Pfloat = 1.0, priority: Pfloat = Inf) =
  if index == -1 and channel == audioChannelAuto:
    debug "resetting all audio channels"
    # stop all audio
    for i in 0..<nAudioChannels:
      audioChannels[i].resetChannel()
    return

  let channel = if channel == audioChannelAuto: findFreeChannel(priority) else: channel
  if channel == audioChannelAuto:
    return

  if index < 0:
    audioChannels[channel].resetChannel()
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

proc music*(channel: AudioChannelId, index: int, loop: int = -1) =
  if index == -1:
    # stop music
    audioChannels[channel].resetChannel()
    return

  if index < 0 or index >= 64:
    raise newException(Exception, "invalid music index: " & $index)

  if musicFileLibrary[index] == "":
    raise newException(Exception, "no music loaded into index: " & $index)

  if audioChannels[channel].musicFile != nil:
    stb_vorbis_close(audioChannels[channel].musicFile)
    audioChannels[channel].musicFile = nil

  var fp = open(musicFileLibrary[index], fmRead)
  if fp == nil:
    raise newException(IOError, "unable to open music file for reading: " & musicFileLibrary[index])

  var v = stb_vorbis_open_file(fp, 1, nil, nil)
  if v == nil:
    fp.close()
    raise newException(IOError, "unable to open vorbis file: " & musicFileLibrary[index])

  let info = stb_vorbis_get_info(v)

  audioChannels[channel].kind = channelMusic
  audioChannels[channel].musicFile = v
  audioChannels[channel].musicIndex = index
  audioChannels[channel].phase = 0.0
  audioChannels[channel].freq = 1.0
  audioChannels[channel].gain = 1.0
  audioChannels[channel].loop = loop
  audioChannels[channel].musicBuffer = 0
  audioChannels[channel].musicStereo = info.channels == 2
  audioChannels[channel].musicSampleRate = info.samplerate.float32

proc musicSeek*(channel: AudioChannelId, pos: int) =
  if audioChannels[channel].musicFile != nil:
    discard stb_vorbis_seek(audioChannels[channel].musicFile, pos.cuint)

proc musicGetPos*(channel: AudioChannelId): int =
  if audioChannels[channel].musicFile != nil:
    return stb_vorbis_get_sample_offset(audioChannels[channel].musicFile).int
  else:
    return -1

proc volume*(channel: AudioChannelId, volume: int) =
  audioChannels[channel].gain = (volume.float32 / 255.0)

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

proc pitch*(channel: AudioChannelId, freq: Pfloat) =
  audioChannels[channel].targetFreq = freq

proc synthShape*(channel: AudioChannelId, newShape: SynthShape) =
  audioChannels[channel].shape = newShape

proc audioOut*(channel: AudioChannelId, index: int): float32 =
  if index > audioChannels[channel].outputBuffer.size:
    return 0
  return audioChannels[channel].outputBuffer[index]

proc synth*(channel: AudioChannelId, shape: SynthShape, freq: Pfloat, init: range[0..15], env: range[-7..7], length: range[0..255] = 0) =
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
  audioChannels[channel].vibamount = 0
  audioChannels[channel].vibspeed = 1
  audioChannels[channel].synthDataIndex = -1

proc synth*(channel: AudioChannelId, synthData: SynthData) =
  if channel > audioChannels.high:
    raise newException(KeyError, "invalid channel: " & $channel)
  audioChannels[channel].kind = channelSynth
  audioChannels[channel].synthData = synthData
  audioChannels[channel].synthDataIndex = 0
  audioChannels[channel].loop = synthData.loop
  audioChannels[channel].trigger = true

proc synth*(channel: AudioChannelId, synthString: string) =
  let sd = synthDataFromString(synthString)
  synth(channel, sd)

proc synthIndex*(channel: AudioChannelId): int =
  return audioChannels[channel].synthDataIndex div (audioChannels[channel].synthData.speed.int+1)

proc synthUpdate*(channel: AudioChannelId, shape: SynthShape, freq: Pfloat) =
  if channel > audioChannels.high:
    raise newException(KeyError, "invalid channel: " & $channel)
  if shape != synSame:
    audioChannels[channel].shape = shape
  audioChannels[channel].freq = freq

proc startTextInput*() =
  sdl.startTextInput()

proc stopTextInput*() =
  sdl.stopTextInput()

proc useRelativeMouse*(on: bool) =
  discard sdl.setRelativeMouseMode(on)

proc isTextInput*(): bool =
  return sdl.isTextInputActive()

# sets the audio callback for the channel
proc setAudioCallback*(channel: AudioChannelId, callback: proc(input: float32): float32, stereo: bool) =
  if channel > audioChannels.high:
    raise newException(KeyError, "invalid channel: " & $channel)
  audioChannels[channel].kind = channelCallback
  audioChannels[channel].callback = callback
  audioChannels[channel].callbackStereo = stereo
  audioChannels[channel].gain = 1.0

proc setAudioBufferSize*(samples: int) =
  audioBufferSize = samples
  inputSamples = newSeq[float32](samples)
  outputSamples = newSeq[float32](samples)

proc hideMouse*() =
  discard showCursor(0)

proc showMouse*() =
  discard showCursor(1)

proc setClipboardText*(text: string) =
  discard sdl.setClipboardText(text)

proc setLinearFilter*(on: bool) =
  linearFilter = on
  resize()

proc hasWindow*(): bool =
  return window != nil

proc setVSync*(on: bool) =
  vsyncEnabled = on
  discard setHint("SDL_HINT_RENDER_VSYNC", (if on: "1" else: "0").cstring)

proc getVSync*(): bool =
  return vsyncEnabled

proc errorPopup*(title: string, message: string) =
  echo "ERROR: ", title," : ", message
  discard showSimpleMessageBox(MessageBoxError, title, message, window)

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
