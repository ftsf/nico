import nico
import nico/gui2
import strformat
import nico/debug

var lastNumber = 0
var debugMode = false

var floatData: array[4, float32]
var sliderData: array[32, float32]
var intData: array[4, int]
var statusData: array[3, RenderStatus]
var toggleData: array[3, bool]

type Level = ref object
  name: string
var levels: seq[Level]
for i in 0..<10:
  levels.add(Level(name: &"level {i+1}"))

proc `$`(l: Level): string =
  return l.name

var level = levels[0]
var levelId = 0

proc gameInit() =
  discard

proc gameUpdate(dt: float32) =
  if keyp(K_F1):
    debugMode = not debugMode

  guiStartFrame()
  guiSize(3 * 16 + 12, 6 * 16 + 10)

  if guiBegin("NICO/GUI DEMO", resizable = true):
    guiFoldout("Value"):
      guiHorizontal(16):
        guiSize(16,16)
        guiLabel($lastNumber)

    guiFoldout("Input"):
      guiHorizontal(16):
        for i in 0..<9:
          guiSize(16,16)
          if guiButton(&"{i+1}"):
            echo &"button {i+1} pressed"
            lastNumber = i+1

    guiFoldout("Drag"):
      for i,v in floatData.mpairs:
        guiDrag(&"f{i+1}", v, 0f, 0f, 10f, 0.1f)
      for i,v in intData.mpairs:
        guiDrag(&"int{i+1}", v, -100, 100, 0.1f)

    guiFoldout("Slider"):
      for i,v in floatData.mpairs:
        guiSlider(&"f{i+1}", v, 0, 0, 10)
      for i,v in intData.mpairs:
        guiSlider(&"int{i+1}", v, 0, -100, 100)

    guiFoldout("XY"):
      guiSize(h = 32)
      guiSlider2D("2D", floatData[0], floatData[1], 0f, 0f, 10f, 10f)

    guiFoldout("Option"):
      for i,v in statusData.mpairs:
        guiOption(&"status{i+1}", statusData[i])
      guiOption("", statusData[0])
      if guiOption("level", level, levels):
        levelId = levels.find(level)
      if guiOption("levelId", levelId, levels):
        level = levels[levelId]

    guiFoldout("Toggle"):
      guiToggle("debug", debugMode)
      for i,v in toggleData.mpairs:
        guiToggle(&"{i+1}", v)

    guiFoldout("MultiSlider"):
      guiMultiSlider(floatData, 0f, 10f)
      guiMultiSliderV(sliderData, 0f, 10f)

proc gameDraw() =
  cls()
  guiDraw()

  if debugMode:
    drawDebug()
  else:
    clearDebug()

  when not defined(emscripten):
    let (mx,my) = mouse()
    setColor(7)
    circfill(mx,my,1)

nico.init("myOrg", "myApp")

fixedSize(false)
integerScale(true)

when not defined(emscripten):
  hideMouse()

nico.createWindow("myApp", 256, 256, 4, false)
nico.run(gameInit, gameUpdate, gameDraw)
