import nico
import nico/vec

# frame counter
var frame = 0

var verts: array[4, Vec4f]
var currentPoint: ptr Vec4f

proc tquadfill(a,b,c,d: Vec4f) =
  tquadfill(a.x,a.y,a.z,a.w, b.x,b.y,b.z,b.w, c.x,c.y,c.z,c.w, d.x,d.y,d.z,d.w)

proc tquadfill(verts: array[4, Vec4f]) =
  tquadfill(verts[0], verts[1], verts[2], verts[3])

proc gameInit() =
  setPalette(loadPalettePico8Extra())
  loadSpriteSheet(0, "spritesheet.png", 8, 8)

  verts[0] = vec4f( 0,  0,  0.01f, 16.01f)
  verts[1] = vec4f(64,  0, 15.99f, 16.01f)
  verts[2] = vec4f(64, 64, 15.99f, 31.99f)
  verts[3] = vec4f( 0, 64,  0.01f, 31.99f)

proc gameUpdate(dt: Pfloat) =
  frame.inc

  let (mx,my) = mouse()
  if mousebtnp(0):
    let mv = vec2f(mx,my)
    for v in verts.mitems:
      if nearer(mv, v.xy, 8f):
        currentPoint = v.addr
  elif mousebtn(0):
    if currentPoint != nil:
      currentPoint[].x = mx
      currentPoint[].y = my

proc gameDraw() =
  cls()

  tquadfill(verts)

  for p in verts.mitems:
    setColor(if p.addr == currentPoint: 7 else: 5)
    circ(p.x,p.y,3)

# initialization
nico.init("nico", "test")

# we want a fixed sized screen with perfect square pixels
fixedSize(true)
integerScale(true)
# create the window
nico.createWindow("nico",128,128,4)

# start, say which functions to use for init, update and draw
nico.run(gameInit, gameUpdate, gameDraw)
