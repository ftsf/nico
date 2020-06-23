import nico, math



var
  mouseDraw : SpriteDraw
  blockDraw : SpriteDraw


proc init() =
  setCamera(0, 0)
  loadSpriteSheet(0, "platformer.png",16,16)
  mouseDraw = initSpriteDraw(0,8,0,0)

  blockDraw = initSpriteDraw(0,0,54,54)

proc update(dt: Pfloat) =
  let moose = mouse()
  mouseDraw.x = moose[0] - 4
  mouseDraw.y= moose[1] - 4


proc draw() =
  cls()
  setColor(17)
  spr(mouseDraw)
  spr(blockDraw)
  setColor(1)
  if(mouseDraw.sprOverlap(blockDraw)):
    printc("Over the object",75,0)

nico.init("Nico","Overlap")

nico.createWindow("nico",128,128,4,false)

loadFont(0,"font.png")
setFont(0)
fixedSize(true)
integerScale(true)

nico.run(init,update,draw)