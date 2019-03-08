import math
import nico
import hashes

type
  Vec2[T] = tuple
    x,y: T

  Vec2f* = Vec2[float32]
  Vec2i* = Vec2[int]

proc vec2f*(x,y: Pfloat | Pint): Vec2f =
  result.x = x.float32
  result.y = y.float32

proc vec2f*(): Vec2f =
  result.x = 0
  result.y = 0

proc vec2i*(x,y: int): Vec2i =
  result.x = x
  result.y = y

proc vec2i*(v: Vec2f): Vec2i =
  result.x = v.x.int
  result.y = v.y.int

proc vec2f*(v: Vec2i): Vec2f =
  result.x = v.x.float32
  result.y = v.y.float32

template x*[T](v: Vec2[T]): T =
  return v.x

template y*[T](v: Vec2[T]): T =
  return v.y

proc `x=`*[T](v: var Vec2[T], s: T) =
  v.x = s

proc `y=`*[T](v: var Vec2[T], s: T) =
  v.y = s

proc `+`*[T](a,b: Vec2[T]): Vec2[T] =
  result.x = a.x+b.x
  result.y = a.y+b.y

proc `+`*[T](a: Vec2[T], s: T): Vec2[T] =
  result.x = a.x+s
  result.y = a.y+s

proc `-`*[T](a,b: Vec2[T]): Vec2[T] =
  result.x = a.x-b.x
  result.y = a.y-b.y

proc `-`*[T](a: Vec2[T], s: T): Vec2[T] =
  result.x = a.x-s
  result.y = a.y-s

proc `-`*[T](a: Vec2[T]): Vec2[T] =
  result.x = -a.x
  result.y = -a.y

proc `*`*[T](a,b: Vec2[T]): Vec2[T] =
  result.x = a.x*b.x
  result.y = a.y*b.y

proc `/`*[T](a,b: Vec2[T]): Vec2[T] =
  result.x = a.x/b.x
  result.y = a.y/b.y

proc `/`*[T](a: Vec2[T], s: T): Vec2[T] =
  result.x = a.x/s
  result.y = a.y/s

proc `*`*[T](a: Vec2[T], s: T): Vec2[T] =
  result.x = a.x*s
  result.y = a.y*s

proc `*`*[T](a: Vec2[T], s: float64 | float32 | float): Vec2[T] =
  result.x = a.x*s
  result.y = a.y*s

proc `-=`*[T](a: var Vec2[T], s: T | float64) =
  a.x -= s
  a.y -= s

proc `-=`*[T](a: var Vec2[T], b: Vec2[T]) =
  a.x -= b.x
  a.y -= b.y

proc `*`*[T](s: T, a: Vec2[T]): Vec2[T] =
  result.x = a.x*s
  result.y = a.y*s

proc `*`*[T](s: float64, a: Vec2[T]): Vec2[T] =
  result.x = a.x*s
  result.y = a.y*s

proc `+=`*[T](a: var Vec2[T], b: Vec2[T]) =
  a.x+=b.x
  a.y+=b.y

proc `*=`*[T](a: var Vec2[T], s: T) =
  a.x*=s
  a.y*=s

proc `/=`*[T](a: var Vec2[T], s: T) =
  a.x /= s
  a.y /= s

proc length*[T](a: Vec2[T]): T =
  return sqrt(a.x*a.x + a.y*a.y)

proc length2*[T](a: Vec2[T]): T =
  return a.x*a.x + a.y*a.y

proc magnitude*(a: Vec2i): float32 =
  return sqrt((a.x*a.x).float32 + (a.y*a.y).float32)

proc magnitude*[T](a: Vec2[T]): T =
  return sqrt(a.x*a.x + a.y*a.y)

proc sqrMagnitude*[T](a: Vec2[T]): T =
  return a.x*a.x + a.y*a.y

proc normalized*[T](a: Vec2[T]): Vec2[T] =
  let length = a.length()
  if length < 0.000001:
    return vec2f(0,0)
  result.x = a.x / length
  result.y = a.y / length

proc normalize*[T](a: var Vec2[T]) =
  let length = a.length()
  if length < 0.000001:
    a.x = 0
    a.y = 0
    return
  a.x /= length
  a.y /= length

proc perpendicular*[T](a: Vec2[T]): Vec2[T] =
  result.x = -a.y
  result.y = a.x

proc normal*[T](a: Vec2[T]): Vec2[T] =
  result = a.perpendicular().normalized()

proc dot*[T](a,b: Vec2[T]): T =
  result = 0.0
  result += a.x*b.x
  result += a.y*b.y

proc line*[T](a,b: Vec2[T]) =
  line(a.x.int, a.y.int, b.x.int, b.y.int)

proc rndVec*(mag: float32): Vec2f =
  result.x = rnd(mag*2.0) - mag
  result.y = rnd(mag*2.0) - mag
  result = result.normalized

proc diff*(a,b: Vec2f): Vec2f =
  return a - b

proc dist*(a,b: Vec2f): float32 =
  return (a-b).length

proc dist2*(a,b: Vec2f): float32 =
  return (a-b).length2

proc nearer*(a,b: Vec2f, compDist: float32): bool =
  return dist2(a,b) < compDist * compDist

proc further*(a,b: Vec2f, compDist: float32): bool =
  return dist2(a,b) > compDist * compDist

proc clamp*(a: Vec2f, maxLength: float32): Vec2f =
  let d2 = a.length2
  if d2 > maxLength * maxLength:
    let d = sqrt(d2)
    result = (a / d) * maxLength
  else:
    result = a

proc clampPerAxis*[T](a: Vec2[T], maxLength: T): Vec2[T] =
  result.x = clamp(a.x, -maxLength, maxLength)
  result.y = clamp(a.y, -maxLength, maxLength)

proc insideRect*(p: Vec2f, a: Vec2f, b: Vec2f): bool =
  # returns if a is inside min and max (inclusive)
  let minx = min(a.x, b.x)
  let miny = min(a.y, b.y)
  let maxx = max(a.x, b.x)
  let maxy = max(a.y, b.y)
  return p.x >= minx and p.y >= miny and p.x <= maxx and p.y <= maxy

proc rotate*(v: Vec2f, angle: float32): Vec2f =
  let sa = sin(angle)
  let ca = cos(angle)
  return vec2f(
    ca * v.x - sa * v.y,
    sa * v.x + ca * v.y
  )

proc angle*(v: Vec2f): Pfloat =
  return arctan2(v.y, v.x)

proc angleToVec*(angle: Pfloat, mag: Pfloat = 1.0): Vec2f =
  return vec2f(cos(angle), sin(angle)) * mag

proc zero*(): Vec2f =
  return vec2f(0,0)

proc approxZero*(v: Vec2f): bool =
  return abs(v.x) < 0.0001 and abs(v.y) < 0.0001

proc hash*(x: Vec2i): Hash =
  var h: Hash = 0
  h = h !& x.x
  h = h !& x.y
  result = !$h
