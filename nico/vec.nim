import math
import nico

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

proc `*`*[T](a: Vec2[T], s: float64): Vec2[T] =
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

proc magnitude*[T](a: Vec2[T]): T =
  return sqrt(a.x*a.x + a.y*a.y)

proc sqrMagnitude*[T](a: Vec2[T]): T =
  return a.x*a.x + a.y*a.y

proc normalized*[T](a: Vec2[T]): Vec2[T] =
  let length = a.length()
  result.x = a.x / length
  result.y = a.y / length

proc normalize*[T](a: var Vec2[T]) =
  let length = a.length()
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
  line(a.x, a.y, b.x, b.y)

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
  return dist2(a,b) < compDist

proc further*(a,b: Vec2f, compDist: float32): bool =
  return dist2(a,b) > compDist

proc clamp*(a: Vec2f, maxLength: float32): Vec2f =
  let d2 = a.length2
  if d2 > maxLength * maxLength:
    let d = sqrt(d2)
    result = (a / d) * maxLength
  else:
    result = a

proc insideRect*(p: Vec2f, a: Vec2f, b: Vec2f): bool =
  # returns if a is inside min and max (inclusive)
  let minx = min(a.x, b.x)
  let miny = min(a.y, b.y)
  let maxx = max(a.x, b.x)
  let maxy = max(a.y, b.y)
  return p.x >= minx and p.y >= miny and p.x <= maxx and p.y <= maxy
