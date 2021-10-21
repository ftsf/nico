import nico

var textInputString: string
var textInputEventListener: EventListener

proc gameInit() =
  textInputString = ""
  textInputEventListener = addEventListener(proc(ev: Event): bool =
    if ev.kind == ekTextInput:
      textInputString &= ev.text
  )
  startTextInput()

proc gameUpdate(dt: float32) =
  discard

proc gameDraw() =
  cls()
  setColor(6)
  print("TYPE SOMETHING",1,1)
  setColor(7)
  print(textInputString,1,10)

# initialization
nico.init("nico", "test")

# we want a fixed sized screen with perfect square pixels
fixedSize(true)
integerScale(true)
# create the window
nico.createWindow("nico",128,128,4)

# start, say which functions to use for init, update and draw
nico.run(gameInit, gameUpdate, gameDraw)
