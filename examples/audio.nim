import nico

var buffer: seq[float32]

proc gameInit() =
  var s = synth(synSaw, 44.0)
  connect(s, getAudioOutput())

proc gameUpdate(dt: float) =
  buffer = getAudioBuffer()

proc gameDraw() =
  cls()
  setColor(7)
  for x in 1..<128:
    line(x-1,buffer[x-1] * 64.0,x,buffer[x] * 64.0)


nico.init("nico", "audio")
integerScale(true)
fixedSize(true)
initMixer(16)
nico.createWindow("audio", 128, 128, 4)
nico.run(gameInit, gameUpdate, gameDraw)
