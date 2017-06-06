import math

type
  Vec2[T] = tuple
    x,y: T

  Vec2f* = Vec2[float32]
  Vec2i* = Vec2[int]

proc vec2f*(x,y: float32): Vec2f =
  result.x = x
  result.y = y

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

proc length*[T](a: Vec2[T]): T =
  return sqrt(a.x*a.x + a.y*a.y)

proc length2*[T](a: Vec2[T]): T =
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
