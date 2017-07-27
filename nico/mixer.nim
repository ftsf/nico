when defined(js):
  import webaudio

import sndfile
import math
import random

import sdl2.sdl


{.this:self.}

# simple audio mixer for nico

const musicBufferSize = 4096

type
  SfxBuffer = ref object
    data: seq[float32]
    rate: float
    channels: range[1..2]
    length: int

type
  Node = ref object of RootObj
    sampleId: uint32
    output: float32
  Effect = ref object of Node
  Source = ref object of Node
  Sink = ref object of Node
    inputs: seq[Node]
  GainNode = ref object of Sink
    gain: float
  FilterKind = enum
    Lowpass
    Highpass
    Bandpass
    Notch
  FilterNode = ref object of Sink
    kind: FilterKind
    freq: float
    resonance: float
  SfxSource = ref object of Source
    buffer: SfxBuffer
    position: float
    speed: float
    loop: int
    finished: bool
  MusicSource = ref object of Source
    handle: ptr TSNDFILE
    buffers: array[2,seq[float32]]
    buffer: int
    rate: float
    channels: range[1..2]
    length: int
    position: float
    bufferPosition: float
    speed: float
    canFill: bool
    loop: int
    finished: bool
  NoiseSource = ref object of Source
    freq: float
    start: int
    lfsr: int
    period: uint
    outvalue: float32
    nextClick: int
  SynthShape* = enum
    synSin
    synSqr
    synSaw
    synTri
    synNoise
  SynthSource = ref object of Source
    freq: float
    phase: float
    shape: SynthShape
    width: float
  AudioOutputNode = ref object of Sink
    sampleBuffer: seq[float32]

var audioSampleId: uint32
var audioOutputNode: AudioOutputNode

var invSampleRate: float

proc newSfxBuffer(filename: string): SfxBuffer =
  echo "loading sfx: ", filename
  result = new(SfxBuffer)
  var info: Tinfo
  zeroMem(info.addr, sizeof(Tinfo))
  var fp = sndfile.open(filename.cstring, READ, info.addr)
  echo "file opened"
  if fp == nil:
    raise newException(IOError, "unable to open file for reading: " & filename)

  result.data = newSeq[float32](info.frames * info.channels)
  result.rate = info.samplerate.float
  result.channels = info.channels
  result.length = info.frames.int * info.channels.int

  var loaded = 0
  while loaded < result.length:
    let count = fp.read_float(result.data[loaded].addr, min(result.length - loaded,1024))
    loaded += count.int

  discard fp.close()

  echo "loaded sfx: " & filename & " frames: " & $result.length
  echo result.channels
  echo result.rate

proc cleanupMusicSource(self: MusicSource) =
  if self.handle != nil:
    discard self.handle.close()

proc fill*(self: MusicSource) =
  let otherbuffer = (buffer + 1) mod 2
  discard handle.read_float(buffers[otherbuffer][0].addr, musicBufferSize)
  canFill = false

proc newMusicSource(filename: string, loop: int = 0): MusicSource =
  new(result, cleanupMusicSource)
  var info: Tinfo
  var snd = sndfile.open(filename.cstring, READ, info.addr)
  if snd == nil:
    raise newException(IOError, "unable to open file for reading: " & filename)

  result.handle = snd
  result.buffers[0] = newSeq[float32](musicBufferSize)
  result.buffers[1] = newSeq[float32](musicBufferSize)
  result.buffer = 1
  result.rate = info.samplerate.float
  result.channels = info.channels
  result.length = info.frames.int * info.channels.int
  result.canFill = true
  result.fill()
  result.loop = loop

proc newNoiseSource(freq: float, seed = 0xfeed): NoiseSource =
  result = new(NoiseSource)
  result.lfsr = seed
  result.freq = freq

proc shutdownMixer() =
  echo "closing mixer"
  discard

proc connect*(a: Node, b: Sink) =
  assert(b != nil)
  assert(a != nil)
  b.inputs.safeAdd(a)

proc lerp[T](a,b: T, t: float): T =
  return a + (b - a) * t

proc interpolatedLookup[T](a: seq[T], s: float): T =
  let alpha = s mod 1.0
  if s.int < a.len - 1:
    result = lerp(a[s.int],a[s.int+1],alpha)

method process(self: Node) {.base.} =
  output = 0.0

method process(self: SfxSource) =
  if buffer != nil:
    let s = position.int
    if s >= 0 and s < buffer.data.len:
      output = buffer.data.interpolatedLookup(position)
    if buffer.channels == 2 or sampleId mod 2 == 1:
      position += speed

method process(self: MusicSource) =
  if finished:
    output = 0.0
    return
  let s = bufferPosition.int
  if s >= 0 and s < buffers[buffer].len:
    output = buffers[buffer].interpolatedLookup(bufferPosition)
  if channels == 2 or sampleId mod 2 == 1:
    position += speed
    bufferPosition += speed
    if position.int >= length:
      # reached end of file
      if loop > 0 or loop == -1:
        if loop > 0:
          loop -= 1
          if loop == -1:
            finished = true
            output = 0.0
            return
        discard handle.seek(0, SEEK_SET)
        position = 0
        canFill = true
      else:
        finished = true
        output = 0.0
        return
    if bufferPosition.int >= buffers[buffer].len:
      buffer = (buffer + 1) mod 2
      canFill = true
      bufferPosition = 0

proc tick(self: NoiseSource) =
  let lsb: uint = (lfsr and 1)
  lfsr = lfsr shr 1
  if lsb == 1:
    lfsr = lfsr xor 0xb400
  output = if lsb == 1: 1.0 else: -1.0

method process(self: NoiseSource) =
  nextClick -= 1
  if nextClick <= 0:
    tick()
    nextClick = ((1.0 / freq) * 44100.0).int
  output = outvalue

method process(self: Sink) =
  if self.sampleId != audioSampleId:
    output = 0.0
    for input in inputs:
      input.process()
      output += input.output
    self.sampleId = audioSampleId

proc getAudioOutput*(): AudioOutputNode =
  return audioOutputNode

proc getAudioBuffer*(): seq[float32] =
  return audioOutputNode.sampleBuffer

proc synth*(shape: SynthShape, freq: float): SynthSource =
  var s = new(SynthSource)
  s.freq = freq
  s.shape = shape
  s.width = 0.5
  s.phase = 0.0
  return s

method process(self: SynthSource) =
  if self.sampleId != audioSampleId:
    phase += freq * invSampleRate
    phase = phase mod 1.0
    case self.shape:
    of synSin:
      output = sin(phase)
    of synSqr:
      output = (if phase < width: -1.0 else: 1.0)
    of synTri:
      output = (1.0/width) * (width - abs(phase mod (2.0*width) - width))
    of synSaw:
      output = (phase mod 1.0) * 2.0 - 1.0
    of synNoise:
      output = random(1.0)
    self.sampleId = audioSampleId

proc audioCallback(userdata: pointer, stream: ptr uint8, bytes: cint) {.cdecl.} =
  setupForeignThreadGc()
  var samples = cast[ptr array[int32.high,float32]](stream)
  let nSamples = bytes div sizeof(float32)
  for i in 0..<nSamples:
    audioOutputNode.process()
    samples[i] = audioOutputNode.output
    audioOutputNode.sampleBuffer[i] = audioOutputNode.output
    audioSampleId += 1

proc getMusic*(): int =
  return 0

proc initMixer*(nChannels: Natural = 16) =
  when defined(js):
    # use web audio
    discard
  else:
    echo "initMixer"
    if sdl.init(INIT_AUDIO) != 0:
      raise newException(Exception, "Unable to initialize audio")

    var audioSpec: AudioSpec
    audioSpec.freq = 44100.cint
    audioSpec.format = AUDIO_F32
    audioSpec.channels = 2
    audioSpec.samples = musicBufferSize
    audioSpec.padding = 0
    audioSpec.callback = audioCallback
    audioSpec.userdata = nil

    var obtained: AudioSpec
    if openAudio(audioSpec.addr, obtained.addr) != 0:
      raise newException(Exception, "Unable to open audio device: " & $getError())

    invSampleRate = 1.0 / obtained.freq.float

    echo obtained

    audioOutputNode = new(AudioOutputNode)
    audioOutputNode.sampleBuffer = newSeq[float32](obtained.samples * obtained.channels)

    # start the audio thread
    pauseAudio(0)

    echo "audio initialised"

  addQuitProc(proc() {.noconv.} =
    shutdownMixer()
  )

when isMainModule:
  initMixer(16)
  var music = newMusicSource("test.ogg", -1)
  music.speed = 1.0
  music.play()
  var nz = newNoiseSource(440.0)
  nz.play()
  while true:
    if music.canFill:
      music.fill()
    delay(0)
    nz.freq -= 0.01
    if nz.freq < 0.01:
      nz.freq = 4096.0
