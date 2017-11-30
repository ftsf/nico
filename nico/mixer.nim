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
const nChannels = 16

type AudioChannelId* = range[-2..nChannels.high]

var tickFunc: proc() = nil

var currentBpm: Natural = 128
var currentTpb: Natural = 4
var sampleRate = 44100.0
var nextTick = 0
var clock: bool
var nextClock = 0

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
  FilterKind = enum
    Lowpass
    Highpass
    Bandpass
    Notch

  ChannelKind = enum
    channelNone
    channelSynth
    channelWave
    channelMusic
    channelCallback

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
    synNoise = "noi"
    synNoise2 = "met"
    synWav = "wav" # use custom waveform

  Table = object
    gain: array[16,uint8]
    note: array[16,uint8]
    commands: array[2,array[16,tuple[command: uint8, value: uint8]]]

  Channel = object
    kind: ChannelKind
    buffer: SfxBuffer
    callback: proc(samples: seq[float32])
    musicFile: ptr TSNDFILE
    musicIndex: int
    musicBuffer: int
    musicBuffers: array[2,array[musicBufferSize,float32]]

    table: uint8

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
    fxKind: FXKind
    fxData1: float
    fxData2: float
    fxData3: float

    priority: float

    wavData: array[32, uint8]


var sfxBufferLibrary: array[64,SfxBuffer]
var musicFileLibrary: array[64,string]

var audioSampleId: uint32
var audioChannels: array[nChannels, Channel]

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

proc loadSfx*(index: range[-1..63], filename: string) =
  if index < 0 or index > 63:
    return
  sfxBufferLibrary[index] = newSfxBuffer(assetPath & filename)

proc loadMusic*(index: int, filename: string) =
  if index < 0 or index > 63:
    return
  musicFileLibrary[index] = assetPath & filename

proc getMusic*(index: AudioChannelId): int =
  if audioChannels[index].kind != channelMusic:
    return -1
  return audioChannels[index].musicIndex

proc findFreeChannel(priority: float): int =
  for i,c in audioChannels:
    if c.kind == channelNone:
      return i
  var lowestPriority: float = Inf
  var bestChannel: AudioChannelId = -2
  for i,c in audioChannels:
    if c.priority < lowestPriority:
      lowestPriority = c.priority
      bestChannel = i
  if lowestPriority > priority or bestChannel < 0:
    return -2
  return bestChannel

proc sfx*(index: range[-1..63], channel: AudioChannelId = -1, loop: int = 1, gain: float = 1.0, pitch: float = 1.0, priority: float = Inf) =
  let channel = if channel == -1: findFreeChannel(priority) else: channel
  if channel == -2:
    return

  echo "sfx: ", index, " channel: ", channel

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
  if musicFileLibrary[index] == nil:
    raise newException(IOError, "no music loaded in index: " & $index)

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

  block:
    let read = snd.read_float(audioChannels[channel].musicBuffers[0][0].addr, musicBufferSize)
  block:
    let read = snd.read_float(audioChannels[channel].musicBuffers[1][0].addr, musicBufferSize)

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

proc shutdownMixer() =
  echo "closing mixer"
  discard

proc lerp[T](a,b: T, t: float): T =
  return a + (b - a) * t

proc interpolatedLookup[T](a: openarray[T], s: float): T =
  let alpha = s mod 1.0
  let sample = s.int mod a.len
  let nextSample = (sample + 1) mod a.len
  result = lerp(a[sample],a[nextSample],alpha)

proc noteToNoteStr(value: int): string =
  let oct = value div 12 - 1
  case value mod 12:
  of 0:
    return "C-" & $oct
  of 1:
    return "C#" & $oct
  of 2:
    return "D-" & $oct
  of 3:
    return "D#" & $oct
  of 4:
    return "E-" & $oct
  of 5:
    return "F-" & $oct
  of 6:
    return "F#" & $oct
  of 7:
    return "G-" & $oct
  of 8:
    return "G#" & $oct
  of 9:
    return "A-" & $oct
  of 10:
    return "A#" & $oct
  of 11:
    return "B-" & $oct
  else:
    return "???"

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

proc reset*(channel: int) =
  if channel > audioChannels.high:
    raise newException(KeyError, "invalid channel: " & $channel)
  audioChannels[channel].kind = channelNone
  audioChannels[channel].freq = 1.0
  audioChannels[channel].gain = 0.0
  audioChannels[channel].loop = 0
  audioChannels[channel].musicIndex = 0

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
      if glide == 0:
        freq = targetFreq
      elif clock:
        freq = lerp(freq, targetFreq, 1.0 - (glide.float32 / 16.0))
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
    of synNoise2:
      if freq != 0.0:
        if nextClick <= 0:
          let lsb: uint = (lfsr2 and 1)
          lfsr2 = lfsr2 shr 1
          if lsb == 1:
            lfsr2 = lfsr2 xor 0x0043
          outvalue = if lsb == 1: 1.0 else: -1.0
          nextClick = ((1.0 / freq) * sampleRate).int
        nextClick -= 1
      o = outvalue
    of synWav:
      if freq != 0.0:
        o = wavData[(phase mod 1.0 * 32.0).int].float32 / 16.0
    else:
      o = 0.0
    o = o * gain

    if audioSampleId mod 2 == 0:
      if clock:
        if length > 0:
          length -= 1
          if length == 0:
            kind = channelNone

        envPhase += 1

        if vibamount > 0:
          freq = basefreq + sin(envPhase.float / vibspeed.float) * basefreq * 0.03 * vibamount.float

        if pchange != 0:
          targetFreq = targetFreq + targetFreq * pchange.float / 128.0
          basefreq = targetFreq
          if targetFreq > sampleRate / 2.0:
            targetFreq = sampleRate / 2.0

        if arp != 0:
          let a0 = (arp and 0x000f)
          let a1 = (arp and 0x00f0) shr 4
          let a2 = (arp and 0x0f00) shr 8
          let a3 = (arp and 0xf000) shr 12
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
            if (envPhase / arpSpeed.int) mod arpSteps == 1:
              targetFreq = basefreq + basefreq * 0.06 * a0.float
            elif (envPhase / arpSpeed.int) mod arpSteps == 2:
              targetFreq = basefreq + basefreq * 0.06 * a1.float
            elif (envPhase / arpSpeed.int) mod arpSteps == 3:
              targetFreq = basefreq + basefreq * 0.06 * a2.float
            elif (envPhase / arpSpeed.int) mod arpSteps == 4:
              targetFreq = basefreq + basefreq * 0.06 * a3.float
            else:
              targetFreq = basefreq

        # determine the env value
        if env < 0:
          # decay
          envValue = clamp(lerp(init.float / 15.0, 0, envPhase / (-env * 4)), 0.0, 1.0)
          if envValue <= 0:
            kind = channelNone
        elif env > 0:
          # attack
          envValue = clamp(lerp(init.float / 15.0, 1.0, envPhase / (env * 4)), 0.0, 1.0)
        elif env == 0:
          envValue = init.float / 15.0

        gain = clamp(lerp(gain, envValue, 0.9), 0.0, 1.0)

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
    return o * sfxVolume * masterVolume
  of channelMusic:
    var o: float32
    o = self.musicBuffers[self.musicBuffer].interpolatedLookup(phase) * gain
    phase += freq
    if phase >= musicBufferSize:
      # end of buffer, switch buffers and fill
      phase = 0.0
      let read = musicFile.read_float(self.musicBuffers[self.musicBuffer][0].addr, musicBufferSize)
      self.musicBuffer = (self.musicBuffer + 1) mod 2
      if read != musicBufferSize:
        if loop != 0:
          if loop > 0:
            loop -= 1
          discard musicFile.seek(0, SEEK_SET)
        else:
          self.reset()

    return o * musicVolume * masterVolume
  else:
    return 0.0

proc bpm*(newBpm: Natural) =
  currentBpm = newBpm

proc tpb*(newTpb: Natural) =
  currentTpb = newTpb

proc queueAudio*(samples: var seq[float32]) =
  when not defined(js):
    let ret = queueAudio(audioDeviceId, samples[0].addr, (samples.len * 4).uint32)
    if ret != 0:
      raise newException(Exception, "error queueing audio: " & $getError())

when not defined(js):
  proc queuedAudioSize*(): int =
    return getQueuedAudioSize(audioDeviceId).int div 4

proc audioCallback(userdata: pointer, stream: ptr uint8, bytes: cint) {.cdecl.} =
  when hasThreads:
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
        nextTick = (sampleRate / (currentBpm.float / 60.0 * currentTpb.float)).int

    samples[i] = 0
    for j in 0..<audioChannels.len:
      samples[i] += audioChannels[j].process()
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
        nextTick = (sampleRate / (currentBpm.float / 60.0 * currentTpb.float)).int

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
    echo "initMixer"
    if sdl.init(INIT_AUDIO) != 0:
      raise newException(Exception, "Unable to initialize audio")

    var audioSpec: AudioSpec
    #audioSpec.freq = 44100.cint
    audioSpec.freq = sampleRate.cint
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
    audioDeviceId = openAudioDevice(nil, 0, audioSpec.addr, obtained.addr, AUDIO_ALLOW_FORMAT_CHANGE)
    if audioDeviceId == 0:
      raise newException(Exception, "Unable to open audio device: " & $getError())

    sampleRate = obtained.freq.float
    invSampleRate = 1.0 / obtained.freq.float

    echo obtained

    for c in audioChannels.mitems:
      c.lfsr = 0xfeed
      c.lfsr2 = 0x00fe
      c.glide = 0
      for j in 0..<32:
        c.wavData[j] = random(16).uint8

    # start the audio thread
    when hasThreads:
      pauseAudioDevice(audioDeviceId, 0)
      if obtained.callback != audioCallback:
        echo "wtf no callback"
      echo "audio initialised using audio thread"
    else:
      queueMixerAudio(4096)
      pauseAudioDevice(audioDeviceId, 0)
      echo "audio initialised using main thread"

  when not defined(js):
    addQuitProc(proc() {.noconv.} =
      shutdownMixer()
    )
