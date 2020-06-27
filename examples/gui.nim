import nico
import nico/gui

var buttonPressed = false
var t: float32
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
    if G.button("good button", true, K_g):
      buttonPressed = true
      t = 1.0'f
      i += 1
    G.outcome = gDefault
    if G.drag("drag float",t,0'f,10'f,0.01'f):
      discard
    if G.drag("drag int",i,0,10,0.1'f):
      discard
    G.outcome = gDanger
    G.toggle("dangerous toggle", advanced, true, K_d)
    G.outcome = gDefault
    if advanced and advancedApproved:
      G.outcome = gWarning
      if G.button("decrement"):
        i -= 1
      G.outcome = gDefault
      discard G.slider("slider int", i, 0, 10)
      discard G.slider("slider float", t, 0, 10)

    if G.toggle("dark mode", darkMode, i mod 2 == 0, K_k):
      if darkMode:
        G.colorSets = gui.colorSetDark
      else:
        G.colorSets = gui.colorSetLight
    G.endArea()

    if advanced and not advancedApproved:
      G.beginArea(8, screenHeight div 2 - 32, screenWidth - 16, 64, gTopToBottom, true, true)
      G.label("MODAL DIALOG")
      G.label("are you sure you want to do this?")
      G.outcome = gDanger
      G.beginHorizontal(20)
      G.hExpand = false
      if G.button("yes"):
        advancedApproved = true
      G.outcome = gGood
      if G.button("no"):
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
