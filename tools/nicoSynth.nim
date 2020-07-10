import nico
import nico/gui
import strformat
import strutils

var data: SynthData
var editIndex = 0
var editMode = 0

var outputStr: string
var dirty = true

const minNote = 32
const maxNote = 32 + 64

const initData = synthDataFromString("0037A235C232D22FC22C82296227422422")

data = initData

proc gameInit() =
  masterVol(255)
  sfxVol(255)
  musicVol(255)

  for v in data.steps.mitems:
    if v.shape == synSame:
      v.shape = synSqr

proc play() =
  synth(0, outputStr)

var xval,yval: int

proc gameGui() =
  G.beginArea(4,4,screenWidth-8,20,gLeftToRight)
  var speed = data.speed.int
  if G.slider("speed", speed, 0, 15):
    data.speed = speed.uint8
  var loop = data.loop.int
  if G.slider("loop", loop, 0, 15):
    data.loop = loop.uint8
  if G.button("-"):
    for v in data.steps.mitems:
      v.note -= 12
  if G.button("+"):
    for v in data.steps.mitems:
      v.note += 12
  G.endArea()

  let playIndex = synthIndex(0)

  let (mx,my) = mouse()

  # pitch
  let pitchHeight = 64
  if G.xyarea(xval,yval,4, 24, screenWidth - 8, pitchHeight, proc(G: Gui, x,y,w,h: int, style: GuiStyle, ta,va: TextAlign) =
    for i in 0..<data.steps.len:
      let x0 = x + i * 4
      let x1 = x + i * 4 + 2
      let bottom = y + h - 1

      let yrange = h

      setColor(if editIndex == i: 10 elif data.steps[i].volume == 0: 1 else: 6)
      let noteRel = clamp01(invLerp(minNote, maxNote, data.steps[i].note.float32))
      rectfill(x0, bottom, x1, bottom - noteRel * yrange.float32)
      if playIndex == i:
        setColor(7)
        rect(x0, bottom - noteRel * yrange.float32, x1, bottom)

      if editIndex == i and G.downElement == G.element:
        setColor(10)
        printc(noteToNoteStr(data.steps[editIndex].note.int), x0, bottom - noteRel * yrange.float32 - 10)

    setColor(7)
    printr("pitch", x + w - 1, y)
    setColor(10)
    printr(noteToNoteStr(data.steps[editIndex].note.int), x + w - 1, y + 10)


  ):
    let ix = xval div 4
    if ix >= 0 and ix < data.steps.len:
      editMode = 0
      editIndex = ix
      data.steps[ix].note = clamp(minNote + pitchHeight - yval, minNote, maxNote).uint8

  # volume
  let volumeHeight = 32
  if G.xyarea(xval,yval,4, 24 + pitchHeight + 4, screenWidth - 8, volumeHeight, proc(G: Gui, x,y,w,h: int, style: GuiStyle, ta,va: TextAlign) =
    for i in 0..<data.steps.len:
      let x0 = x + i * 4
      let x1 = x + i * 4 + 2
      let bottom = y + h - 1

      let yrange = h

      setColor(if editIndex == i: 10 elif data.steps[i].volume == 0: 1 else: 6)
      let volumeRel = clamp01(invLerp(0, 15, data.steps[i].volume.float32))
      rectfill(x0, bottom, x1, bottom - volumeRel * yrange.float32)

      if playIndex == i:
        setColor(7)
        rect(x0, bottom - volumeRel * yrange.float32, x1, bottom)

      if editIndex == i and G.downElement == G.element:
        setColor(10)
        printc($data.steps[editIndex].volume.int, x0, bottom - volumeRel * yrange.float32 - 10)


    setColor(7)
    printr("volume", x + w - 1, y)
    setColor(10)
    printr($data.steps[editIndex].volume.int, x + w - 1, y + 10)

  ):
    let yrange = volumeHeight
    let ix = xval div 4
    if ix >= 0 and ix < data.steps.len:
      editMode = 1
      editIndex = ix

      var vol = lerp(0'f, 15'f, (yrange - yval).float32 / yrange.float32)

      data.steps[ix].volume = clamp(vol, 0, 15).uint8

  # shape
  let shapeHeight = 32
  if G.xyarea(xval,yval,4, 24 + pitchHeight + 4 + volumeHeight + 4, screenWidth - 8, shapeHeight, proc(G: Gui, x,y,w,h: int, style: GuiStyle, ta,va: TextAlign) =
    for i in 0..<data.steps.len:
      let x0 = x + i * 4
      let x1 = x + i * 4 + 2
      let bottom = y + h - 1

      let yrange = h

      setColor(if editIndex == i: 10 elif data.steps[i].volume == 0: 1 else: 6)
      let shapeRel = clamp01(invLerp(synSin.float32, synNoise2.float32, data.steps[i].shape.float32))
      rectfill(x0, bottom, x1, bottom - shapeRel * yrange.float32)

      if playIndex == i:
        setColor(7)
        rect(x0, bottom - shapeRel * yrange.float32, x1, bottom)

      if editIndex == i and G.downElement == G.element:
        setColor(10)
        printc($data.steps[editIndex].shape, x0, bottom - shapeRel * yrange.float32 - 10)

    setColor(7)
    printr("shape", x + w - 1, y)
    setColor(10)
    printr($data.steps[editIndex].shape, x + w - 1, y + 10)

  ):
    let yrange = shapeHeight
    let ix = xval div 4
    if ix >= 0 and ix < data.steps.len:
      editMode = 2
      editIndex = ix
      var shape = lerp(synSin.int.float32 - 0.5'f, synNoise2.float32 + 0.5'f, (yrange - yval).float32 / yrange.float32)
      data.steps[ix].shape = clamp(shape.int, synSin.int, synNoise2.int).SynthShape

  G.beginArea(0,screenHeight - 20, screenWidth, 20,gLeftToRight)
  if G.button("PLAY"):
    play()
  if G.button("COPY CODE"):
    echo fmt("synth(channel, \"{outputStr}\")")
    setClipboardText(outputStr)
  G.endArea()

proc gameUpdate(dt: float32) =
  G.update(gameGui, dt)

  if btnp(pcA):
    play()

  if btnp(pcB):
    if data.steps[editIndex].shape < SynthShape.high:
      data.steps[editIndex].shape.inc()
    else:
      data.steps[editIndex].shape = synSin

  if btnpr(pcLeft):
    editIndex -= 1
  if btnpr(pcRight):
    editIndex += 1

  if btnpr(pcUp):
    case editMode:
    of 0:
      data.steps[editIndex].note.inc()
    of 1:
      data.steps[editIndex].volume.inc()
    of 2:
      data.steps[editIndex].shape.inc()
    else: discard
  if btnpr(pcDown):
    case editMode:
    of 0:
      data.steps[editIndex].note.dec()
    of 1:
      data.steps[editIndex].volume.dec()
    of 2:
      data.steps[editIndex].shape.dec()
    else: discard

  editIndex = wrap(editIndex, data.steps.len)

  if dirty:
    outputStr = synthDataToString(data)

proc gameDraw() =
  cls()

  G.draw(gameGui)

nico.init("nico", "nicoSynthEditor")
nico.createWindow("nicoSynthEditor", 150, 190, 4, false)
nico.run(gameInit, gameUpdate, gameDraw)
