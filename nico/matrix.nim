import math
import nico/vec

type
  Mat4x4f* = object
    data*: array[16,float32]
  Mat3x3f* = object
    data*: array[9,float32]

proc `[]`*(m: Mat4x4f, i: int): float32 =
  m.data[i]

proc `[]`*(m: var Mat4x4f, i: int): var float32 =
  m.data[i]

proc `[]=`*(m: var Mat4x4f, i: int, v: float32) =
  m.data[i] = v

proc `[]`*(m: Mat4x4f, x,y: int): float32 =
  m.data[x * 4 + y]

proc `[]`*(m: var Mat4x4f, x,y: int): var float32 =
  m.data[x * 4 + y]

proc `[]=`*(m: var Mat4x4f, x,y: int, v: float32) =
  cast[ptr array[16,float32]](m.data[0].addr)[x * 4 + y] = v

proc `[]`*(m: Mat3x3f, i: int): float32 =
  m.data[i]

proc `[]`*(m: var Mat3x3f, i: int): var float32 =
  m.data[i]

proc `[]=`*(m: var Mat3x3f, i: int, v: float32) =
  m.data[i] = v

proc `[]`*(m: Mat3x3f, x,y: int): float32 =
  m.data[x * 3 + y]

proc `[]`*(m: var Mat3x3f, x,y: int): var float32 =
  m.data[x * 3 + y]

proc `[]=`*(m: var Mat3x3f, x,y: int, v: float32) =
  cast[ptr array[9,float32]](m.data[0].addr)[x * 3 + y] = v

proc mat4x4f*(m: float32 = 1.0'f): Mat4x4f =
  # X x.x x.y x.z 0
  # Y y.x y.y y.z 0
  # Z z.x z.y.z.z 0
  # T t.x t.y t.z 1

  result[0,0] = m
  result[1,1] = m
  result[2,2] = m
  result[3,3] = m

proc mat4x4f*(cols: array[4,Vec4f]): Mat4x4f =
  for i in 0..<4:
    result[i,0] = cols[i].x
    result[i,1] = cols[i].y
    result[i,2] = cols[i].z
    result[i,3] = cols[i].w

proc `$`(m: Mat4x4f): string =
  result &= $m.data[0..3] & "\n"
  result &= $m.data[4..7] & "\n"
  result &= $m.data[8..11] & "\n"
  result &= $m.data[12..15] & "\n"

proc mat3x3f*(m: float32 = 1.0'f): Mat3x3f =
  result[0,0] = m
  result[1,1] = m
  result[2,2] = m

proc mat3x3f*(v00,v01,v02,v10,v11,v12,v20,v21,v22: float32): Mat3x3f =
  result[0,0] = v00
  result[0,1] = v01
  result[0,2] = v02
  result[1,0] = v10
  result[1,1] = v11
  result[1,2] = v12
  result[2,0] = v20
  result[2,1] = v21
  result[2,2] = v22

proc `+`*(a,b: Mat4x4f): Mat4x4f =
  for i in 0..<16:
    result[i] = a[i] + b[i]

proc `-`*(a,b: Mat4x4f): Mat4x4f =
  for i in 0..<16:
    result[i] = a[i] - b[i]

proc `*`*(a: Mat4x4f, s: float32): Mat4x4f =
  for i in 0..<16:
    result[i] = a[i] * s

proc `/`*(a: Mat4x4f, s: float32): Mat4x4f =
  for i in 0..<16:
    result[i] = a[i] / s

# matrix matrix multiplication
proc `*`*(a,b: Mat4x4f): Mat4x4f =
  # multiply each row in A by each column in B
  # a row 0 x b col 0
  for i in 0..<4:
    for j in 0..<4:
      var v = 0.0'f
      for k in 0..<4:
        v += a[k,j] * b[i,k]
      result[i,j] = v

proc `*=`*(a: var Mat4x4f, b: Mat4x4f) =
  # multiply each row in A by each column in B
  # a row 0 x b col 0
  var tmp = a
  for i in 0..<4:
    for j in 0..<4:
      var v = 0.0'f
      for k in 0..<4:
        v += tmp[k,j] * b[i,k]
      a[i,j] = v

proc `*`*(m: Mat4x4f, v: Vec4f): Vec4f =
  let x = v.x
  let y = v.y
  let z = v.z
  let w = v.w
  result.x = x * m[0,0] + y * m[1,0] + z * m[2,0] + w * m[3,0]
  result.y = x * m[0,1] + y * m[1,1] + z * m[2,1] + w * m[3,1]
  result.z = x * m[0,2] + y * m[1,2] + z * m[2,2] + w * m[3,2]
  result.w = x * m[0,3] + y * m[1,3] + z * m[2,3] + w * m[3,3]

proc translate*(m: var Mat4x4f, v: Vec3f) =
  var vm = m * vec4f(v,1.0'f)
  m[3,0] = vm.x
  m[3,1] = vm.y
  m[3,2] = vm.z
  m[3,3] = vm.w

proc translate*(m: var Mat4x4f, x,y,z: float32) =
  var vm = m * vec4f(x,y,z,1.0'f)
  m[3,0] = vm.x
  m[3,1] = vm.y
  m[3,2] = vm.z
  m[3,3] = vm.w

proc rotate*(angle: float32, axis: Vec3f): Mat4x4f =
  let a = angle
  let c = cos(a)
  let s = sin(a)
  let t = 1.0'f - c
  let temp = (1 - c) * axis

  let x = axis.x
  let y = axis.y
  let z = axis.z

  result[0,0] = t*x*x + c
  result[0,1] = t*x*y - s*z
  result[0,2] = t*x*z + s*y
  result[0,3] = 0

  result[1,0] = t*x*y + s*z
  result[1,1] = t*y*y + c
  result[1,2] = t*z*y - s*x
  result[1,3] = 0

  result[2,0] = t*x*z - s*y
  result[2,1] = t*y*z + s*x
  result[2,2] = t*z*z + c
  result[2,3] = 0

  result[3,0] = 0
  result[3,1] = 0
  result[3,2] = 0
  result[3,3] = 1

proc row*(m: Mat4x4f, i: range[0..3]): Vec4f =
  return vec4f(m[i,0], m[i,1], m[i,2], m[i,3])

proc col*(m: Mat4x4f, i: range[0..3]): Vec4f =
  return vec4f(m[0,i], m[1,i], m[2,i], m[3,i])

proc rotate*(m: var Mat4x4f, angle: float32, axis: Vec3f) =
  var rot = rotate(angle, axis)
  m = m * rot

proc scale*(m: var Mat4x4f, s: Vec3f) =
  m[0,0] *= s.x
  m[0,1] *= s.x
  m[0,2] *= s.x
  m[0,3] *= s.x

  m[1,0] *= s.y
  m[1,1] *= s.y
  m[1,2] *= s.y
  m[1,3] *= s.y

  m[2,0] *= s.z
  m[2,1] *= s.z
  m[2,2] *= s.z
  m[2,3] *= s.z

proc scale*(m: var Mat4x4f, s: float32) =
  m[0,0] *= s
  m[0,1] *= s
  m[0,2] *= s
  m[0,3] *= s

  m[1,0] *= s
  m[1,1] *= s
  m[1,2] *= s
  m[1,3] *= s

  m[2,0] *= s
  m[2,1] *= s
  m[2,2] *= s
  m[2,3] *= s

proc perspectiveLH*(fovy: float32, aspect: float32, near, far: float32): Mat4x4f =
  let tanHalfFovy = tan(fovy / 2.0'f)
  result[0,0] = 1.0'f / (aspect * tanHalfFovy)
  result[1,1] = 1.0'f / tanHalfFovy
  result[2,2] = (far + near) / (far - near)
  result[2,3] = 1.0'f
  result[3,2] = -(2.0'f * far * near) / (far - near)

proc perspectiveRH*(fovy: float32, aspect: float32, near, far: float32): Mat4x4f =
  let tanHalfFovy = tan(fovy / 2.0'f)
  result[0,0] = 1.0'f / (aspect * tanHalfFovy)
  result[1,1] = 1.0'f / tanHalfFovy
  result[2,3] = -1.0'f
  result[2,2] = -(far + near) / (far - near)
  result[3,2] = -(2.0'f * far * near) / (far - near)

proc perspectiveRightDown*(fovy: float32, aspect: float32, near, far: float32): Mat4x4f =
  # right is positive, towards bottom of screen is positive, towards the camera is positive
  let tanHalfFovy = tan(fovy / 2.0'f)
  result[0,0] = -1.0'f / (aspect * tanHalfFovy)
  result[1,1] = -1.0'f / tanHalfFovy
  result[2,3] = -1.0'f
  result[2,2] = -(far + near) / (far - near)
  result[3,2] = -(2.0'f * far * near) / (far - near)

proc frustum*(left, right, bottom, top, near, far: float32): Mat4x4f =
  result[0,0] = (2*near)/(right-left)
  result[1,1] = (2*near)/(top-bottom)
  result[2,2] = (far+near)/(near-far)
  result[2,0] = (right+left)/(right-left)
  result[2,1] = (top+bottom)/(top-bottom)
  result[2,3] = -1.0'f
  result[3,2] = (2*far*near)/(near-far)

proc lookAt*(eye, at: Vec3f, up: Vec3f = vec3f(0,0,1)): Mat4x4f =
  var zaxis = normalized(eye - at)
  let xaxis = normalized(cross(up.normalized, zaxis))
  let yaxis = cross(zaxis, xaxis)

  result[0,0] = xaxis.x
  result[1,0] = xaxis.y
  result[2,0] = xaxis.z
  result[3,0] = 0

  result[0,1] = yaxis.x
  result[1,1] = yaxis.y
  result[2,1] = yaxis.z
  result[3,1] = 0

  result[0,2] = zaxis.x
  result[1,2] = zaxis.y
  result[2,2] = zaxis.z
  result[3,2] = 0

  result[0,3] = 0
  result[1,3] = 0
  result[2,3] = 0
  result[3,3] = 1

  result.translate(-eye)

proc up*(m: Mat4x4f): Vec3f =
  return vec3f(m[1,0], m[1,1], m[1,2])

proc down*(m: Mat4x4f): Vec3f =
  return -m.up()

proc right*(m: Mat4x4f): Vec3f =
  return vec3f(m[0,0], m[0,1], m[0,2])

proc left*(m: Mat4x4f): Vec3f =
  return -m.right()

proc back*(m: Mat4x4f): Vec3f =
  return vec3f(m[2,0], m[2,1], m[2,2])

proc forward*(m: Mat4x4f): Vec3f =
  return -m.back()

template xaxis*(m: Mat4x4f): Vec3f = right(m)
template yaxis*(m: Mat4x4f): Vec3f = up(m)
template zaxis*(m: Mat4x4f): Vec3f = forward(m)

proc transpose*(m: Mat4x4f): Mat4x4f =
  for i in 0..<4:
    for j in 0..<4:
      result[i,j] = m[j,i]

proc determinant*(m: Mat3x3f): float32 =
  + m[0,0] * (m[1,1] * m[2,2] - m[2,1] * m[1,2]) -
    m[1,0] * (m[0,1] * m[2,2] - m[2,1] * m[0,2]) +
    m[2,0] * (m[0,1] * m[1,2] - m[1,1] * m[0,2])

proc determinant*(m: Mat4x4f): float32 =
  if m[0,0] != 0:
    result += m[0,0] * determinant(mat3x3f(
      m[1,1],m[1,2],m[1,3],
      m[2,1],m[2,2],m[2,3],
      m[3,1],m[3,2],m[3,3]
    ))
  if m[0,1] != 0:
    result -= m[0,1] * determinant(mat3x3f(
      m[1,0],m[1,2],m[1,3],
      m[2,0],m[2,2],m[2,3],
      m[3,0],m[3,2],m[3,3]
    ))
  if m[0,2] != 0:
    result += m[0,2] * determinant(mat3x3f(
      m[1,0],m[1,1],m[1,3],
      m[2,0],m[2,1],m[2,3],
      m[3,0],m[3,1],m[3,3]
    ))
  if m[0,3] != 0:
    result += m[0,3] * determinant(mat3x3f(
      m[1,0],m[1,1],m[1,2],
      m[2,0],m[2,1],m[2,2],
      m[3,0],m[3,1],m[3,2]
    ))

proc inverse*(m: Mat4x4f): Mat4x4f =
  let
    Coef00:float32 = (m[2,2] * m[3,3]) - (m[3,2] * m[2,3])
    Coef02:float32 = (m[1,2] * m[3,3]) - (m[3,2] * m[1,3])
    Coef03:float32 = (m[1,2] * m[2,3]) - (m[2,2] * m[1,3])

    Coef04:float32 = (m[2,1] * m[3,3]) - (m[3,1] * m[2,3])
    Coef06:float32 = (m[1,1] * m[3,3]) - (m[3,1] * m[1,3])
    Coef07:float32 = (m[1,1] * m[2,3]) - (m[2,1] * m[1,3])

    Coef08:float32 = (m[2,1] * m[3,2]) - (m[3,1] * m[2,2])
    Coef10:float32 = (m[1,1] * m[3,2]) - (m[3,1] * m[1,2])
    Coef11:float32 = (m[1,1] * m[2,2]) - (m[2,1] * m[1,2])

    Coef12:float32 = (m[2,0] * m[3,3]) - (m[3,0] * m[2,3])
    Coef14:float32 = (m[1,0] * m[3,3]) - (m[3,0] * m[1,3])
    Coef15:float32 = (m[1,0] * m[2,3]) - (m[2,0] * m[1,3])

    Coef16:float32 = (m[2,0] * m[3,2]) - (m[3,0] * m[2,2])
    Coef18:float32 = (m[1,0] * m[3,2]) - (m[3,0] * m[1,2])
    Coef19:float32 = (m[1,0] * m[2,2]) - (m[2,0] * m[1,2])

    Coef20:float32 = (m[2,0] * m[3,1]) - (m[3,0] * m[2,1])
    Coef22:float32 = (m[1,0] * m[3,1]) - (m[3,0] * m[1,1])
    Coef23:float32 = (m[1,0] * m[2,1]) - (m[2,0] * m[1,1])

  var
    Fac0 = vec4f(Coef00, Coef00, Coef02, Coef03)
    Fac1 = vec4f(Coef04, Coef04, Coef06, Coef07)
    Fac2 = vec4f(Coef08, Coef08, Coef10, Coef11)
    Fac3 = vec4f(Coef12, Coef12, Coef14, Coef15)
    Fac4 = vec4f(Coef16, Coef16, Coef18, Coef19)
    Fac5 = vec4f(Coef20, Coef20, Coef22, Coef23)

    Vec0=vec4f(m[1,0], m[0,0], m[0,0], m[0,0])
    Vec1=vec4f(m[1,1], m[0,1], m[0,1], m[0,1])
    Vec2=vec4f(m[1,2], m[0,2], m[0,2], m[0,2])
    Vec3=vec4f(m[1,3], m[0,3], m[0,3], m[0,3])

    Inv0: Vec4f = (Vec1 * Fac0) - (Vec2 * Fac1) + (Vec3 * Fac2)
    Inv1: Vec4f = (Vec0 * Fac0) - (Vec2 * Fac3) + (Vec3 * Fac4)
    Inv2: Vec4f = (Vec0 * Fac1) - (Vec1 * Fac3) + (Vec3 * Fac5)
    Inv3: Vec4f = (Vec0 * Fac2) - (Vec1 * Fac4) + (Vec2 * Fac5)

    SignA: Vec4f = vec4f(+1, -1, +1, -1)
    SignB: Vec4f = vec4f(-1, +1, -1, +1)

    col0 : Vec4f = Inv0 * SignA
    col1 : Vec4f = Inv1 * SignB
    col2 : Vec4f = Inv2 * SignA
    col3 : Vec4f = Inv3 * SignB

    Inverse : Mat4x4f = mat4x4f([col0, col1, col2, col3])

    Row0 = vec4f(Inverse[0,0], Inverse[1,0], Inverse[2,0], Inverse[3,0])

    Dot0 = m.row(0) * Row0
    Dot1 = (Dot0.x + Dot0.y) + (Dot0.z + Dot0.w)

    OneOverDeterminant = 1.0'f / Dot1
  result = Inverse * OneOverDeterminant
