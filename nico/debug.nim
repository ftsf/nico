import nico
import nico/vec
import sequtils
import strutils

type DebugKind = enum
  Point
  Line
  Circle
  Text

type DebugObject = object
  kind: DebugKind
  a,b: Vec2f
  r: float32
  color: int
  str: string
  ttl: float32
  category: string

const debugDrawTime = 0f
const debugColor = 8

var currentCategory: string = ""
var debugObjects: seq[DebugObject]

proc debugCategory*(s: string) =
  currentCategory = s

proc debugPoint*(a: Vec2f, color: int = debugColor, ttl = debugDrawTime) =
  debugObjects.add(DebugObject(kind: Point, a: a, color: color, ttl: ttl, category: currentCategory))

proc debugCircle*(a: Vec2f, r: float32, color: int = debugColor, ttl = debugDrawTime) =
  debugObjects.add(DebugObject(kind: Circle, a: a, r: r, color: color, ttl: ttl, category: currentCategory))

proc debugLine*(a,b: Vec2f, color: int = debugColor, ttl = debugDrawTime) =
  debugObjects.add(DebugObject(kind: Line, a: a, b: b, color: color, ttl: ttl, category: currentCategory))

proc debugText*(str: string, a: Vec2f, color: int = debugColor, ttl = debugDrawTime) =
  debugObjects.add(DebugObject(kind: Text, str: str, a: a, color: color, ttl: ttl, category: currentCategory))

proc debugRay*(a,b: Vec2f, color: int = debugColor, ttl = debugDrawTime) =
  debugObjects.add(DebugObject(kind: Line, a: a, b: a + b, color: color, ttl: ttl, category: currentCategory))

proc debugBox*(x,y,w,h: float32, color: int = debugColor, ttl = debugDrawTime) =
  debugLine(vec2f(x,y), vec2f(x+w,y), color, ttl)
  debugLine(vec2f(x+w,y), vec2f(x+w,y+h), color, ttl)
  debugLine(vec2f(x+w,y+h), vec2f(x,y+h), color, ttl)
  debugLine(vec2f(x,y+h), vec2f(x,y), color, ttl)

proc debugBox*(x,y,w,h: int, color: int = debugColor, ttl = debugDrawTime) =
  debugLine(vec2f(x,y), vec2f(x+w,y), color, ttl)
  debugLine(vec2f(x+w,y), vec2f(x+w,y+h), color, ttl)
  debugLine(vec2f(x+w,y+h), vec2f(x,y+h), color, ttl)
  debugLine(vec2f(x,y+h), vec2f(x,y), color, ttl)

proc debugPoly*(poly: seq[Vec2f], color: int = debugColor, ttl = debugDrawTime) =
  for i in 1..<poly.len:
    debugLine(poly[i-1], poly[i], color, ttl)
  debugLine(poly[^1], poly[0], color, ttl)

proc debugPoly*(poly: seq[Vec2f], pos: Vec2f, angle: float32, color: int = debugColor, ttl = debugDrawTime) =
  for i in 1..<poly.len:
    let a = poly[i-1].rotate(angle) + pos
    let b = poly[i].rotate(angle) + pos
    debugLine(a, b, color, ttl)
  block:
    let a = poly[^1].rotate(angle) + pos
    let b = poly[0].rotate(angle) + pos
    debugLine(a, b, color, ttl)

proc drawDebug*(filter: string = "") =
  for d in debugObjects.mitems:
    if filter == "" or filter in d.category:
      d.ttl -= timeStep
      setColor(d.color)
      case d.kind:
      of Point:
        pset(d.a.x, d.a.y)
      of Line:
        line(d.a, d.b)
      of Circle:
        circ(d.a.x, d.a.y, d.r)
      of Text:
        print(d.str, d.a.x, d.a.y)
      d.ttl -= timeStep
  debugObjects.keepItIf(it.ttl > 0f)

proc clearDebug*(filter: string = "") =
  for d in debugObjects.mitems:
    if filter == "" or filter in d.category:
      d.ttl -= timeStep
  debugObjects.keepItIf(it.ttl > 0f)
