import nico

proc invLerp*(a,b,v: Pfloat): Pfloat =
  (v - a) / (b - a)
