when defined(js):
  import webaudio
else:
  import sdl2.sdl
  var audioDeviceId: AudioDeviceID

const hasThreads = compileOption("threads")

import backends.common

import sndfile
import math
import random
import strutils

{.this:self.}

# high level audio for nico
# features
# SDL and JS backends
# each channel can play back either a PCM sample, streaming music or chip synth
# chip synth features
#  sin, saw, pulse, tri, noise
#  FX: fade in, fade out, pitch down, pitch up, vibrato
#  arp table:
# each channel can also be sent to an FX
# set a tick function to be called back at BPM for doing music type stuff

const musicBufferSize = 4096

var tickFunc: proc() = nil

var currentBpm: Natural = 128
var currentTpb: Natural = 4
var sampleRate = 44100.0
var nextTick = 0

var masterVolume = 1.0
var sfxVolume = 1.0
var musicVolume = 1.0

proc masterVol*(newVol: int) =
  masterVolume = newVol.float / 255.0

proc sfxVol*(newVol: int) =
  sfxVolume = newVol.float / 255.0

proc musicVol*(newVol: int) =
  musicVolume = newVol.float / 255.0

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

  AudioOutputNode = ref object of Sink
    sampleBuffer: seq[float32]

  ChannelKind = enum
    channelNone
    channelSynth
    channelWave
    channelMusic

  FXKind* = enum
    fxDelay
    fxReverb
    fxLP
    fxHP
    fxBP
    fxClip
    fxWrap

  SynthShape* = enum
    synSame = "-"
    synSin = "sin"
    synSqr = "sqr"
    synP12 = "p12"
    synP25 = "p25"
    synSaw = "saw"
    synTri = "tri"
    synNoise = "rnd"

  Channel = object
    kind: ChannelKind
    buffer: SfxBuffer
    musicFile: ptr TSNDFILE
    musicBuffer: int
    musicBuffers: array[2,array[musicBufferSize,float32]]
    loop: int
    phase: float # or position
    freq: float # or speed
    targetFreq: float
    width: float
    pan: float
    shape: SynthShape
    gain: float

    vinit: float
    vchange: float

    pchange: float

    trigger: bool
    lfsr: int
    nextClick: int
    outvalue: float32
    fxKind: FXKind
    fxData1: float
    fxData2: float
    fxData3: float


var sfxBufferLibrary: array[64,SfxBuffer]

var audioSampleId: uint32
var audioOutputNode: AudioOutputNode
var audioChannels: seq[Channel]

var invSampleRate: float

proc setTickFunc*(f: proc()) =
  tickFunc = f

proc newSfxBuffer(filename: string): SfxBuffer =
  echo "loading sfx: ", filename
  result = new(SfxBuffer)
  var info: Tinfo
  when defined(js):
    discard
  else:
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

proc loadSfx*(index: int, filename: string) =
  if index < 0 or index > 63:
    return
  sfxBufferLibrary[index] = newSfxBuffer(assetPath & filename)

proc findFreeChannel(): int =
  for i,c in audioChannels:
    if c.kind == channelNone:
      return i
  return 0

proc sfx*(index: int, channel: int = -1, loop: int = 1, pitch: float = 1.0) =
  let channel = if channel == -1: findFreeChannel() else: channel
  if channel >= audioChannels.len:
    echo "invalid channel", channel
    return
  if index < 0:
    audioChannels[channel].kind = channelNone
    return
  if sfxBufferLibrary[index] == nil:
    echo "invalid sfx", index
    return
  audioChannels[channel].kind = channelWave
  audioChannels[channel].buffer = sfxBufferLibrary[index]
  audioChannels[channel].phase = 0.0
  audioChannels[channel].freq = pitch
  audioChannels[channel].gain = 1.0
  audioChannels[channel].loop = loop

proc music*(filename: string, channel: int, loop: int = 1) =
  var info: Tinfo
  var snd = sndfile.open((assetPath & filename).cstring, READ, info.addr)
  if snd == nil:
    raise newException(IOError, "unable to open file for reading: " & filename)

  if channel >= audioChannels.len:
    echo "invalid channel ", channel
    return

  audioChannels[channel].kind = channelMusic
  audioChannels[channel].musicFile = snd
  audioChannels[channel].phase = 0.0
  audioChannels[channel].freq = 1.0
  audioChannels[channel].gain = 1.0
  audioChannels[channel].loop = loop
  audioChannels[channel].musicBuffer = 0

  block:
    let read = snd.read_float(audioChannels[channel].musicBuffers[0][0].addr, musicBufferSize)
  block:
    let read = snd.read_float(audioChannels[channel].musicBuffers[1][0].addr, musicBufferSize)

proc fade*(channel: int, init, target: int, time: float) =
  audioChannels[channel].gain = init.float / 255.0
  audioChannels[channel].vchange = ((target - init).float / 255.0) / time

proc volume*(channel: int, volume: int) =
  audioChannels[channel].gain = (volume.float / 255.0)

proc pitchbend*(channel: int, targetFreq: float, time: float) =
  audioChannels[channel].pchange = (targetFreq - audioChannels[channel].freq) / time
  audioChannels[channel].targetFreq = targetFreq

proc pitch*(channel: int, freq: float) =
  audioChannels[channel].freq = freq
  audioChannels[channel].targetFreq = freq
  audioChannels[channel].pchange = 0.0

proc synthShape*(channel: int, newShape: SynthShape) =
  audioChannels[channel].shape = newShape

proc shutdownMixer() =
  echo "closing mixer"
  discard

proc connect*(a: Node, b: Sink) =
  assert(b != nil)
  assert(a != nil)
  b.inputs.safeAdd(a)

proc lerp[T](a,b: T, t: float): T =
  return a + (b - a) * t

proc interpolatedLookup[T](a: openarray[T], s: float): T =
  let alpha = s mod 1.0
  let sample = s.int mod a.len
  let nextSample = (sample + 1) mod a.len
  result = lerp(a[sample],a[nextSample],alpha)

proc getAudioOutput*(): AudioOutputNode =
  return audioOutputNode

proc getAudioBuffer*(): seq[float32] =
  return audioOutputNode.sampleBuffer

proc noteStrToNote(s: string): int =
  let noteChar = s[0]
  let note = case noteChar
    of 'C': 0
    of 'D': 2
    of 'E': 4
    of 'F': 5
    of 'G': 7
    of 'A': 9
    of 'B': 11
    else: 0
  let sharp = s[1] == '#'
  let octave = parseInt($s[2])
  return 12 * octave + note + (if sharp: 1 else: 0)

proc note*(n: int): float =
  # takes a note integer and converts it to a frequency float
  # synth(0, sin, note(48))
  return pow(2.0, ((n.float - 69.0) / 12.0)) * 440.0

proc note*(n: string): float =
  return note(noteStrToNote(n))

proc synth*(channel: int, shape: SynthShape, freq: float, init: int = 256, vchange: float = 0.0) =
  if channel > audioChannels.high:
    raise newException(KeyError, "invalid channel: " & $channel)
  audioChannels[channel].kind = channelSynth
  audioChannels[channel].shape = shape
  audioChannels[channel].freq = freq
  audioChannels[channel].trigger = true
  audioChannels[channel].gain = (init.float / 256.0)
  audioChannels[channel].vchange = vchange
  audioChannels[channel].pchange = 0.0
  audioChannels[channel].loop = -1
  #if shape == synNoise:
  #  audioChannels[channel].lfsr = 0xfeed

proc synthUpdate*(channel: int, shape: SynthShape, freq: float) =
  if channel > audioChannels.high:
    raise newException(KeyError, "invalid channel: " & $channel)
  if shape != synSame:
    audioChannels[channel].shape = shape
  audioChannels[channel].freq = freq

proc channelfx*(channel: int, fxKind: FXKind, data1, data2, data3: float = 0.0) =
  if channel > audioChannels.high:
    raise newException(KeyError, "invalid channel: " & $channel)
  # sets the audio FX for the specified channel
  audioChannels[channel].fxKind = fxKind
  audioChannels[channel].fxData1 = data1
  audioChannels[channel].fxData2 = data2
  audioChannels[channel].fxData3 = data3

proc process(self: var Channel): float32 =
  case kind:
  of channelNone:
    return 0.0
  of channelSynth:
    if audioSampleId mod 2 == 0:
      phase += (freq * invSampleRate) * TAU
      phase = phase mod TAU
    var o: float32 = 0.0
    case self.shape:
    of synSin:
      o = sin(phase)
    of synSqr:
      o = ((if phase mod TAU < (TAU * 0.5): 1.0 else: -1.0) * 0.577).float32
    of synP12:
      o = ((if phase mod TAU < (TAU * 0.125): 1.0 else: -1.0) * 0.577).float32
    of synP25:
      o = ((if phase mod TAU < (TAU * 0.25): 1.0 else: -1.0) * 0.577).float32
    of synTri:
      o = ((abs((phase mod TAU) / TAU * 2.0 - 1.0)*2.0 - 1.0) * 0.7).float32
    of synSaw:
      o = ((((phase mod TAU) - PI) / PI) * 0.5).float32
    of synNoise:
      if freq != 0.0:
        if nextClick <= 0:
          let lsb: uint = (lfsr and 1)
          lfsr = lfsr shr 1
          if lsb == 1:
            lfsr = lfsr xor 0xb400
          outvalue = if lsb == 1: 1.0 else: -1.0
          nextClick = ((1.0 / freq) * sampleRate).int
        nextClick -= 1
      o = outvalue
    else:
      o = 0.0
    o = o * gain
    if audioSampleId mod 2 == 0:
      if vchange > 0:
        gain += vchange * invSampleRate
        if gain >= 1.0:
          gain = 1.0
          vchange = 0.0
      if vchange < 0:
        gain += vchange * invSampleRate
        if gain <= 0.0:
          vchange = 0.0
          gain = 0.0
      if pchange != 0:
        freq += (pchange * invSampleRate)
        if freq == targetFreq:
          pchange = 0.0
        if freq <= invSampleRate:
          freq = invSampleRate
          pchange = 0.0
        if freq > sampleRate / 2.0:
          freq = sampleRate / 2.0
          pchange = 0.0
    return o * sfxVolume * masterVolume
  of channelWave:
    var o: float32 = 0.0
    o = buffer.data.interpolatedLookup(phase) * gain
    if audioSampleId mod 2 == 0:
      phase += freq
      if phase >= buffer.data.len:
        phase = phase mod buffer.data.len.float
        if loop > 0:
          loop -= 1
          if loop == 0:
            kind = channelNone
      if vchange > 0:
        gain += vchange * invSampleRate
        if gain >= 1.0:
          gain = 1.0
          vchange = 0.0
      if vchange < 0:
        gain += vchange * invSampleRate
        if gain <= 0.0:
          vchange = 0.0
          gain = 0.0
    return o * sfxVolume * masterVolume
  of channelMusic:
    var o: float32
    #echo "buffer ", self.musicBuffer
    o = self.musicBuffers[self.musicBuffer].interpolatedLookup(phase) * gain
    phase += freq
    if phase >= musicBufferSize:
      #echo "filling buffer ", self.musicBuffer
      phase = 0.0
      let read = musicFile.read_float(self.musicBuffers[self.musicBuffer][0].addr, musicBufferSize)
      self.musicBuffer = (self.musicBuffer + 1) mod 2
      #echo "read ", read
      if read != musicBufferSize:
        # reached end
        if loop != 0:
          discard musicFile.seek(0, SEEK_SET)
    #echo phase, "/", o
    if audioSampleId mod 2 == 0:
      if vchange > 0:
        gain += vchange * invSampleRate
        if gain >= 1.0:
          gain = 1.0
          vchange = 0.0
      if vchange < 0:
        gain += vchange * invSampleRate
        if gain <= 0.0:
          vchange = 0.0
          gain = 0.0
    return o * musicVolume * masterVolume
  else:
    return 0.0

proc bpm*(newBpm: Natural) =
  currentBpm = newBpm

proc tpb*(newTpb: Natural) =
  currentTpb = newTpb

proc audioCallback(userdata: pointer, stream: ptr uint8, bytes: cint) {.cdecl.} =
  when hasThreads:
    setupForeignThreadGc()

  var samples = cast[ptr array[int32.high,float32]](stream)
  let nSamples = bytes div sizeof(float32)

  for i in 0..<nSamples:
    nextTick -= 1
    if nextTick <= 0 and tickFunc != nil:
      tickFunc()
      nextTick = (sampleRate / (currentBpm.float / 60.0 * currentTpb.float)).int

    samples[i] = 0
    for j in 0..<audioChannels.len:
      samples[i] += audioChannels[j].process()
    audioOutputNode.sampleBuffer[i] = samples[i]
    audioSampleId += 1

proc queueAudio*(samples: var seq[float32]) =
  when not defined(js):
    discard queueAudio(audioDeviceId, samples[0].addr, (samples.len div sizeof(float32)).uint32)

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
    when hasThreads:
      audioSpec.callback = audioCallback
    else:
      audioSpec.callback = nil
    audioSpec.userdata = nil

    var obtained: AudioSpec
    if openAudio(audioSpec.addr, obtained.addr) != 0:
      raise newException(Exception, "Unable to open audio device: " & $getError())

    sampleRate = obtained.freq.float
    invSampleRate = 1.0 / obtained.freq.float

    echo obtained

    audioOutputNode = new(AudioOutputNode)
    audioOutputNode.sampleBuffer = newSeq[float32](obtained.samples * obtained.channels)

    audioChannels = newSeq[Channel](nChannels)
    for c in audioChannels.mitems:
      c.lfsr = 0xfeed

    # start the audio thread
    when hasThreads:
      pauseAudio(0)
      echo "audio initialised using audio thread"
    else:
      echo "audio initialised using main thread"

  addQuitProc(proc() {.noconv.} =
    shutdownMixer()
  )
