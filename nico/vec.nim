import math
import nico
import hashes

type
  Vec*[N: static int, T: float32 | int] = array[N,T]
  Vec2*[T] = Vec[2,T]
  Vec3*[T] = Vec[3,T]
  Vec4*[T] = Vec[4,T]

  Vec2f* = Vec2[float32]
  Vec2i* = Vec2[int]

  Vec3f* = Vec3[float32]
  Vec3i* = Vec3[int]

  Vec4f* = Vec4[float32]
  Vec4i* = Vec4[int]

template x*[N,T](v: Vec[N,T]): T = v[0]
template `x=`*[N,T](v: var Vec[N,T], val: T) = v[0] = val

template y*[T](v: Vec2[T] | Vec3[T] | Vec4[T]): T = v[1]
template `y=`*[T](v: var Vec2[T] | var Vec3[T] | var Vec4[T], val: T) = v[1] = val

template z*[T](v: Vec3[T] | Vec4[T]): T = v[2]
template `z=`*[T](v: var Vec3[T] | var Vec4[T], val: T) = v[2] = val

template w*[T](v: Vec4[T]): T = v[3]
template `w=`*[T](v: var Vec4[T], val: T) = v[3] = val

proc xy*[V](v: V): Vec2f =
  result.x = v.x
  result.y = v.y

proc xyi*[V](v: V): Vec2i =
  result.x = v.x.int
  result.y = v.y.int

proc xyf*[V](v: V): Vec2f =
  result.x = v.x.float32
  result.y = v.y.float32

proc xz*[V](v: V): Vec2f =
  result.x = v.x
  result.y = v.z

proc xyz*[V](v: V): Vec3f =
  result.x = v.x
  result.y = v.y
  result.z = v.z

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

proc vec3f*(x,y,z: float32): Vec3f =
  result.x = x
  result.y = y
  result.z = z

proc vec3f*(xy: Vec2f,z: float32 = 0): Vec3f =
  result.x = xy.x
  result.y = xy.y
  result.z = z

proc vec3f*(): Vec3f =
  result.x = 0
  result.y = 0
  result.z = 0

proc vec4f*(): Vec4f =
  result.x = 0
  result.y = 0
  result.z = 0
  result.w = 0

proc vec4f*(x,y,z,w:float32): Vec4f =
  result.x = x
  result.y = y
  result.z = z
  result.w = w

proc vec4f*(a: Vec3f, w: float32 = 0): Vec4f =
  result.x = a.x
  result.y = a.y
  result.z = a.z
  result.w = w

proc vec3f*(a: Vec4f): Vec3f =
  result.x = a.x
  result.y = a.y
  result.z = a.z

proc vec4i*(s: int): Vec4i =
  result.x = s
  result.y = s
  result.z = s
  result.w = s

proc vec4i*(x,y,z,w: int): Vec4i =
  result.x = x
  result.y = y
  result.z = z
  result.w = w

proc vec4f*(s: float32): Vec4f =
  result.x = s
  result.y = s
  result.z = s
  result.w = s

# vector add
proc `+`*[T](a,b: Vec2[T]): Vec2[T] =
  result.x = a.x+b.x
  result.y = a.y+b.y

proc `+`*[T](a,b: Vec3[T]): Vec3[T] =
  result.x = a.x+b.x
  result.y = a.y+b.y
  result.z = a.z+b.z

proc `+`*[T](a: Vec3[T],b: Vec2[T]): Vec3[T] =
  result.x = a.x+b.x
  result.y = a.y+b.y
  result.z = a.z

proc `+`*[T](a,b: Vec4[T]): Vec4[T] =
  result.x = a.x+b.x
  result.y = a.y+b.y
  result.z = a.z+b.z
  result.w = a.w+b.w

proc `+`*[T](a: Vec2[T], s: T): Vec2[T] =
  result.x = a.x+s
  result.y = a.y+s

proc `+`*[T](a: Vec3[T], s: T): Vec3[T] =
  result.x = a.x+s
  result.y = a.y+s
  result.z = a.z+s

# vector subtraction
proc `-`*[T](a,b: Vec2[T]): Vec2[T] =
  result.x = a.x-b.x
  result.y = a.y-b.y

proc `-`*[T](a,b: Vec3[T]): Vec3[T] =
  result.x = a.x-b.x
  result.y = a.y-b.y
  result.z = a.z-b.z

proc `-`*[T](a,b: Vec4[T]): Vec4[T] =
  result.x = a.x-b.x
  result.y = a.y-b.y
  result.z = a.z-b.z
  result.w = a.w-b.w

proc `-`*[T](a: Vec2[T], s: T): Vec2[T] =
  result.x = a.x-s
  result.y = a.y-s

proc `-`*[T](a: Vec2[T]): Vec2[T] =
  result.x = -a.x
  result.y = -a.y

proc `-`*[T](a: Vec3[T]): Vec3[T] =
  result.x = -a.x
  result.y = -a.y
  result.z = -a.z

proc `-`*[T](a: Vec4[T]): Vec4[T] =
  result.x = -a.x
  result.y = -a.y
  result.z = -a.z
  result.w = -a.w

# vector scale
proc `*`*[T](a,b: Vec2[T]): Vec2[T] =
  result.x = a.x*b.x
  result.y = a.y*b.y

proc `*`*[T](a,b: Vec3[T]): Vec3[T] =
  result.x = a.x*b.x
  result.y = a.y*b.y
  result.z = a.z*b.z

proc `*`*[T](a,b: Vec4[T]): Vec4[T] =
  result.x = a.x*b.x
  result.y = a.y*b.y
  result.z = a.z*b.z
  result.w = a.w*b.w

# vector scale
proc `/`*[T](a,b: Vec2[T]): Vec2[T] =
  result.x = a.x/b.x
  result.y = a.y/b.y

proc `/`*[T](a,b: Vec3[T]): Vec3[T] =
  result.x = a.x/b.x
  result.y = a.y/b.y
  result.z = a.z/b.z

proc `/`*[T](a: Vec2[T], s: T): Vec2[T] =
  result.x = a.x/s
  result.y = a.y/s

proc `/`*[T](a: Vec3[T], s: T): Vec3[T] =
  result.x = a.x/s
  result.y = a.y/s
  result.z = a.z/s

proc `/`*[T](a: Vec4[T], s: T): Vec4[T] =
  result.x = a.x/s
  result.y = a.y/s
  result.z = a.z/s
  result.w = a.w/s

proc `*`*[T](a: Vec2[T], s: T): Vec2[T] =
  result.x = a.x*s
  result.y = a.y*s

proc `*`*[T](a: Vec3[T], s: T): Vec3[T] =
  result.x = a.x*s
  result.y = a.y*s
  result.z = a.z*s

proc `*`*(a: Vec4f, s: float32): Vec4f =
  result.x = a.x*s
  result.y = a.y*s
  result.z = a.z*s
  result.w = a.w*s

proc `*`*[T](a: Vec2[T], s: float64 | float32 | float): Vec2[T] =
  result.x = a.x*s
  result.y = a.y*s

proc `-=`*[T](a: var Vec2[T], s: T) =
  a.x -= s
  a.y -= s

proc `-=`*[T](a: var Vec2[T], b: Vec2[T]) =
  a.x -= b.x
  a.y -= b.y

proc `-=`*[T](a: var Vec3[T], b: Vec3[T]) =
  a.x -= b.x
  a.y -= b.y
  a.z -= b.z

proc `*`*[T](s: T, a: Vec2[T]): Vec2[T] =
  result.x = a.x*s
  result.y = a.y*s

proc `*`*[T](s: T, a: Vec3[T]): Vec3[T] =
  result.x = a.x*s
  result.y = a.y*s
  result.z = a.z*s

proc `*`*[T](s: float64, a: Vec2[T]): Vec2[T] =
  result.x = a.x*s
  result.y = a.y*s

proc `+=`*[N,T](a: var Vec[N,T], s: T) =
  for i in 0..<N:
    a[i] += s

proc `+=`*[N,T](a: var Vec[N,T], b: Vec[N,T]) =
  for i in 0..<N:
    a[i] += b[i]

proc `*=`*[T](a: var Vec2[T], s: T) =
  a.x*=s
  a.y*=s

proc `*=`*[T](a: var Vec3[T], s: T) =
  a.x*=s
  a.y*=s
  a.z*=s

proc `*=`*[T](a: var Vec4[T], s: T) =
  a.x*=s
  a.y*=s
  a.z*=s
  a.w*=s

proc `*=`*[T](a: var Vec4[T], b: Vec4[T]) =
  a.x*=b.x
  a.y*=b.y
  a.z*=b.z
  a.w*=b.w

proc `/=`*[T](a: var Vec2[T], s: T) =
  a.x /= s
  a.y /= s

proc `/=`*[T](a: var Vec3[T], s: T) =
  a.x /= s
  a.y /= s
  a.z /= s

proc `/=`*[T](a: var Vec4[T], s: T) =
  a.x /= s
  a.y /= s
  a.z /= s
  a.w /= s

proc `or`*(a,b: Vec4i): Vec4i =
  result.x = a.x or b.x
  result.y = a.y or b.y
  result.z = a.z or b.z
  result.w = a.w or b.w

proc length2*[N,T](a: Vec[N,T]): T =
  for i in 0..<N:
    result += a[i]*a[i]

proc length*[N,T](v: Vec[N,T]): T =
  let l2 = v.length2()
  return sqrt(l2)

proc normalized*[N,T](v: Vec[N,T]): Vec[N,T] =
  let length = v.length()
  if length < 0.000001:
    return result
  result = v / length

proc normalize*[N,T](v: var Vec[N,T]) =
  let length = v.length()
  if length < 0.000001:
    v = Vec[N,T]()
    return
  v /= length

proc perpendicular*[T](a: Vec2[T]): Vec2[T] =
  result.x = -a.y
  result.y = a.x

proc normal*[N,T](v: Vec[N,T]): Vec[N,T] =
  result = v.normalized().perpendicular()

proc dot*[T](a,b: Vec2[T]): T =
  result += a.x*b.x
  result += a.y*b.y

proc dot*[T](a,b: Vec3[T]): T =
  result += a.x*b.x
  result += a.y*b.y
  result += a.z*b.z

proc dot*[T](a,b: Vec4[T]): T =
  result += a.x*b.x
  result += a.y*b.y
  result += a.z*b.z
  result += a.w*b.w

proc line*[T](a,b: Vec2[T]) =
  line(a.x.int, a.y.int, b.x.int, b.y.int)

proc lineDashed*[T](a,b: Vec2[T], pattern: uint8 = 0b10101010) =
  lineDashed(a.x.int, a.y.int, b.x.int, b.y.int, pattern)

proc rndVec2i*(mag: int): Vec2i =
  result.x = rnd(mag*2) - mag
  result.y = rnd(mag*2) - mag

proc rndVec2f*(mag: float32): Vec2f =
  result.x = rnd(mag*2.0) - mag
  result.y = rnd(mag*2.0) - mag
  result = result.normalized

proc rndVec3f*(mag: float32): Vec3f =
  result.x = rnd(mag*2.0) - mag
  result.y = rnd(mag*2.0) - mag
  result.z = rnd(mag*2.0) - mag
  result = result.normalized

proc dist*[V](a,b: V): float32 =
  return (a-b).length()

proc dist2*[V](a,b: V): float32 =
  return (a-b).length2()

proc nearer*[V](a,b: V, compDist: float32): bool =
  return dist2(a,b) < compDist * compDist

proc further*[V](a,b: V, compDist: float32): bool =
  return dist2(a,b) > compDist * compDist

proc clamp*[V](a: V, maxLength: float32): V =
  let d2 = a.length2
  if d2 > maxLength * maxLength:
    let d = sqrt(d2)
    result = (a / d) * maxLength
  else:
    result = a

proc clampPerAxis*[T](a: Vec2[T], maxLength: T): Vec2[T] =
  result.x = clamp(a.x, -maxLength, maxLength)
  result.y = clamp(a.y, -maxLength, maxLength)

proc clampPerAxis*[T](a: Vec3[T], maxLength: T): Vec3[T] =
  result.x = clamp(a.x, -maxLength, maxLength)
  result.y = clamp(a.y, -maxLength, maxLength)
  result.z = clamp(a.z, -maxLength, maxLength)

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

proc zero*[N,T](v: Vec[N,T]): bool =
  for i in 0..<N:
    if v[i] != 0:
      return false
  return true

proc approxZero*[N,T](v: Vec[N,T]): bool =
  for i in 0..<N:
    if abs(v[i]) < 0.0001:
      return false
  return true

proc hash*(x: Vec2i): Hash =
  var h: Hash = 0
  h = h !& x.x
  h = h !& x.y
  result = !$h

proc isNaN*(v: Vec4f): bool =
  return v.x.classify == fcNaN or v.y.classify == fcNaN or v.z.classify == fcNaN or v.w.classify == fcNaN

proc isNaN*(v: Vec3f): bool =
  return v.x.classify == fcNaN or v.y.classify == fcNaN or v.z.classify == fcNaN

proc isNaN*(v: Vec2f): bool =
  return v.x.classify == fcNaN or v.y.classify == fcNaN

proc cross*(a,b: Vec2f): float32 =
  return a.x * b.y - a.y * b.x

proc cross*(a,b: Vec3f): Vec3f =
  result.x = a.y*b.z - a.z*b.y
  result.y = a.z*b.x - a.x*b.z
  result.z = a.x*b.y - a.y*b.x

proc project*(v,n: Vec2f): Vec2f =
  return n * (v.dot(n) / n.dot(n))

proc projectAbs*(v,n: Vec2f): Vec2f =
  return abs(dot(v.normalized,n)) * n

proc reflect*(v,n: Vec2f): Vec2f =
  return -(v - v.dot(n) * 2.0 * n)

proc slide*(v,n: Vec2f): Vec2f =
  return n - v * dot(v, n)

proc scaleOnTwoAxes*(v: var Vec2f, axis: Vec2f, s1,s2: float32) =
  v = dot(v,axis) * v * s1 + dot(v,axis.perpendicular) * v * s2

proc round*[N,T](v: Vec[N,T]): T =
  for i in 0..<N:
    v[i] = v.round()
