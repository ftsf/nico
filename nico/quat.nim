import nico/vec
import math

type Quat* = array[4,float32]

template x*(q: Quat): float32 = q[0]
template `x=`*(q: var Quat, val: float32) = q[0] = val

template y*(q: Quat): float32 = q[1]
template `y=`*(q: var Quat, val: float32) = q[1] = val

template z*(q: Quat): float32 = q[2]
template `z=`*(q: var Quat, val: float32) = q[2] = val

template w*(q: Quat): float32 = q[3]
template `w=`*(q: var Quat, val: float32) = q[3] = val

proc quat*(x,y,z,w: float32): Quat =
  result.x = x
  result.y = y
  result.z = z
  result.w = w

proc quat*(angle: float32, axis: Vec3f): Quat =
  let s = sin(angle / 2.0'f)
  result.x = axis.x * s
  result.y = axis.y * s
  result.z = axis.z * s
  result.w = cos(angle / 2.0'f)

proc conjugate*(self: Quat): Quat =
  result = quat(-self.x, -self.y, -self.z, self.w)

proc `*`*(a,b: Quat): Quat =
  result.w = a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z
  result.x = a.x * b.w + a.w * b.x + a.y * b.z - a.z * b.y
  result.y = a.y * b.w + a.w * b.y + a.z * b.x - a.x * b.z
  result.z = a.z * b.w + a.w * b.z + a.x * b.y - a.y * b.x

proc `*`*(a: Quat, v: Vec3f): Vec3f =
  let QuatVector = vec3f(a.x, a.y, a.z)
  let uv = cross(QuatVector, v)
  let uuv = cross(QuatVector, uv)
  return v + ((uv * a.w) + uuv) * 2

proc length2*(self: Quat): float32 =
  return self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w

proc length*(self: Quat): float32 =
  return sqrt(self.length2())

proc normalize*(self: var Quat) =
  let mag = self.length()
  self.x /= mag
  self.y /= mag
  self.z /= mag
  self.w /= mag

proc normalized*(self: Quat): Quat =
  let mag = self.length()
  result.x = self.x / mag
  result.y = self.y / mag
  result.z = self.z / mag
  result.w = self.w / mag
