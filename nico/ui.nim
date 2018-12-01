import nico
import nico/util

proc hslider*(x,y: Pint, w,h: Pint, v: var Pfloat, min: Pfloat = 0.0, max: Pfloat = 1.0, name = "") =
  # draws a slider at position
  # if clicked changes value
  let col = getColor()
  setColor(0)
  rectfill(x,y,x+w-1,y+h-1)
  setColor(col)
  rectfill(x,y,(x+w-1).Pfloat * invLerp(min,max,v), y+h-1)
  if name.len != 0:
    print(name, x+w+1, y)

  if mousebtn(0):
    let (mx,my) = mouse()
    if mx >= x and my >= y and mx <= x + w - 1 and my <= y + h - 1:
      let xv = invLerp(x.Pfloat, (x+w-1).Pfloat, mx.Pfloat)
      v = lerp(min, max, xv)

  setColor(col)
