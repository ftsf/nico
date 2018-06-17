import nico
import math

proc invLerp*(a,b,v: Pfloat): Pfloat =
  (v - a) / (b - a)

proc modSign[T](a,n: T): T =
  return (a mod n + n) mod n

proc angleDiff*(a,b: Pfloat): Pfloat =
  let a = modSign(a,TAU)
  let b = modSign(b,TAU)
  return modSign((a - b) + PI, TAU) - PI
