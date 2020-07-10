import nico
import nico/gui

var buttonPressed = false
var speed: float32
var i = 5
var advanced = false
var darkMode = false
var advancedApproved = false

var winx,winy,winw,winh: Pint
winx = 2
winy = 2
winw = 120
winh = 120
var showWin = true

proc gameInit() =
  loadFont(0, "font.png")

proc gameGui() =
  if G.beginWindow("NICO/GUI DEMO",winx,winy,winw,winh,showWin, gTopToBottom):
    G.hExpand = true
    G.outcome = gGood
    if G.button("GOOD BUTTON", true, K_g):
      buttonPressed = true
      speed = 1.0'f
      i += 1
    G.outcome = gDefault
    if G.drag("DRAG FLOAT",speed,0'f,10'f,0.01'f):
      discard
    if G.drag("DRAG INT",i,0,10,0.1'f):
      discard
    if G.beginDrawer("TEST"):
      G.label("HOW IS THAT?")
      G.endDrawer()
    G.outcome = gDanger
    G.toggle("DANGEROUS TOGGLE", advanced, true, true, K_d)
    G.outcome = gDefault
    if advanced and advancedApproved:
      G.outcome = gWarning
      if G.button("DECREMENT"):
        i -= 1
      G.outcome = gDefault
      discard G.slider("slider int", i, 0, 10)
      discard G.slider("slider float", speed, 0, 10)

    if G.toggle("DARK MODE", darkMode, true, i mod 2 == 0, K_k):
      if darkMode:
        #G.colorSets = gui.colorSetDark
        discard
      else:
        G.colorSets = gui.colorSetLight
    G.endArea()

    if advanced and not advancedApproved:
      G.beginArea(8, screenHeight div 2 - 32, screenWidth - 16, 64, gTopToBottom, true, true)
      G.label("MODAL DIALOG")
      G.label("ARE YOU SURE YOU WANT TO DO THIS?")
      G.outcome = gDanger
      G.beginHorizontal(20)
      G.hExpand = false
      if G.button("YES"):
        advancedApproved = true
      G.outcome = gGood
      if G.button("NO"):
        advancedApproved = false
        advanced = false
      G.outcome = gDefault
      G.endArea()
      G.endArea()

proc gameUpdate(dt: float32) =
  G.update(gameGui, dt)

proc gameDraw() =
  cls()
  G.draw(gameGui)

nico.init("myOrg", "myApp")

fixedSize(false)
integerScale(true)

nico.createWindow("myApp", 256, 256, 4, false)
nico.run(gameInit, gameUpdate, gameDraw)
