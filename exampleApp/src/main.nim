import nico

const orgName = "exampleOrg"
const appName = "exampleApp"

var buttonDown = false

proc gameInit() =
  loadFont(0, "font.png")

proc gameUpdate(dt: float32) =
  buttonDown = btn(pcA)

proc gameDraw() =
  cls()
  setColor(if buttonDown: 7 else: 3)
  printc("welcome to " & appName, screenWidth div 2, screenHeight div 2)

nico.init(orgName, appName)
nico.createWindow(appName, 128, 128, 4, false)
nico.run(gameInit, gameUpdate, gameDraw)
