import nico/vec

type Grid*[T] = object
  width*: int
  height*: int
  data*: seq[T]
  default*: T

proc set*[T](g: var Grid[T], x,y: int, t: T) =
  if x < 0 or y < 0 or x >= g.width or y >= g.height:
    return
  g.data[y * g.width + x] = t

proc get*[T](g: Grid[T], x,y: int): T =
  if x < 0 or y < 0 or x >= g.width or y >= g.height:
    return default(T)
  return g.data[y * g.width + x]

proc get*[T](g: Grid[T], v: Vec2i): T =
  return g.get(v.x, v.y)

proc set*[T](g: var Grid[T], v: Vec2i, t: T) =
  g.set(v.x, v.y, t)

proc `[]`*[T](g: Grid[T], v: Vec2i): T =
  g.get(v)

proc `[]`*[T](g: Grid[T], x,y: int): T =
  g.get(x,y)

proc `[]=`*[T](g: var Grid[T], v: Vec2i, t: T) =
  g.set(v,t)

proc `[]=`*[T](g: var Grid[T], x,y: int, t: T) =
  g.set(vec2i(x,y),t)

iterator items*[T](g: Grid[T]): Vec2i =
  for ty in 0..<g.height:
    for tx in 0..<g.width:
      yield vec2i(tx,ty)

iterator adjacent*[T](g: Grid[T], v: Vec2i, diagonal = false): Vec2i =
  if v.x > 0:
    yield vec2i(v.x-1,v.y)
  if v.x < g.width - 1:
    yield vec2i(v.x+1,v.y)
  if v.y > 0:
    yield vec2i(v.x,v.y-1)
  if v.y < g.height - 1:
    yield vec2i(v.x,v.y+1)

  if diagonal:
    if v.x > 0:
      if v.y > 0:
        yield vec2i(v.x-1,v.y-1)
      if v.y < g.height - 1:
        yield vec2i(v.x-1,v.y+1)
    if v.x < g.width - 1:
      if v.y > 0:
        yield vec2i(v.x+1,v.y-1)
      if v.y < g.height - 1:
        yield vec2i(v.x+1,v.y+1)

proc initGrid*[T](w,h: int, default: T = default(T)): Grid[T] =
  result.width = w
  result.height = h
  result.default = default
  result.data = newSeq[T](w*h)
  for y in 0..<h:
    for x in 0..<w:
      result.set(x,y,default)
