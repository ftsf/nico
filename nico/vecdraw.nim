import nico
import nico/vec
export vec
{.push inline.}

proc pset*(pos: Vec2i) = 
  pset(pos.x, pos.y)

proc pget*(pos: Vec2i): ColorId = 
  pget(pos.x, pos.y)

proc psetRaw*(pos: Vec2I, c: Pint) =
  psetRaw(pos.x, pos.y, c)

proc sset*(pos: Vec2i, c: int = -1) = 
  sset(pos.x, pos.y, c)

proc rect*(pos1, pos2: Vec2i) =
  rect(pos1.x, pos1.y, pos2.x, pos2.y)

proc rectFill*(pos1, pos2: Vec2i) =
  rectFill(pos1.x, pos1.y, pos2.x, pos2.y)

proc rrect*(pos1, pos2: Vec2i, r: Pint = 1) =
  rrect(pos1.x, pos1.y, pos2.x, pos2.y, r)

proc rrectfill*(pos1, pos2: Vec2i, r: Pint = 1) =
  rrectfill(pos1.x, pos1.y, pos2.x, pos2.y, r)

proc rectcorner*(pos1, pos2: Vec2i) =
  rectCorner(pos1.x, pos1.y, pos2.x, pos2.y)

proc rrectcorner*(pos1, pos2: Vec2i) =
  rrectCorner(pos1.x, pos1.y, pos2.x, pos2.y)

proc box*(pos, size: Vec2i) =
  box(pos.x, pos.y, size.x, size.y)

proc boxfill*(pos, size: Vec2i) =
  boxfill(pos.x, pos.y, size.x, size.y)

proc line*(pos1, pos2: Vec2i) =
  line(pos1.x, pos1.y, pos2.x, pos2.y)

proc trifill*(point1, point2, point3: Vec2i) =
  trifill(point1.x, point1.y, point2.x, point2.y, point3.x, point3.y)

proc quadfill*(point1, point2, point3, point4: Vec2i) =
  quadfill(point1.x, point1.y, point2.x, point2.y, point3.x, point3.y, point4.x, point4.y)

proc circfill*(pos: Vec2i, r: Pint) =
  circfill(pos.x, pos.y, r)

proc circ*(pos: Vec2i, r: Pint) =
  circ(pos.x, pos.y, r)

proc ellipsefill*(pos, radius: Vec2i) =
  ellipsefill(pos.x, pos.y, radius.x, radius.y)

proc spr*(spr: Pint, pos: Vec2I, size = vec2i(-1, -1), hflip, vflip = false) =
  spr(spr, pos.x, pos.y, size.x, size.y, hflip, vflip)

proc sprs*(spr: Pint, pos: Vec2I, size = vec2i(-1, -1), destSize = vec2i(1,1), hflip, vflip = false) =
  sprs(spr, pos.x, pos.y, size.x, size.y, destSize.x, destSize.y, hflip, vflip)

proc sspr*(spritePos, spriteSize, destPos: Vec2I, destSize = vec2i(1,1), hflip, vflip = false) =
  sspr(spritePos.x, spritePos.y, spriteSize.x, spriteSize.y, destPos.x, destPos.y, destSize.x, destSize.y, hflip, vflip)

proc sprshift*(spr: Pint, pos: Vec2I, size = vec2i(1, 1), offsetPos = vec2i(0, 0), hflip, vflip = false) =
  sprs(spr, pos.x, pos.y, size.x, size.y, offsetPos.x, offsetPos.y, hflip, vflip)

proc sprRot*(spr: Pint, pos: Vec2i, radians: float32, size = vec2i(1, 1)) =
  sprrot(spr, pos.x, pos.y, radians, size.x, size.y)

proc sprRot90*(spr: Pint, pos: Vec2i, rotations: int, size = vec2i(1, 1)) =
  sprRot90(spr, pos.x, pos.y, rotations, size.x, size.y)

proc copy*(source, dest, width: Vec2i)=
  copy(source.x, source.y, dest.x, dest.y, width.x, width.y)

proc mset*(pos: Vec2i, t: uint8) =
  mset(pos.x, pos.y, t)

proc mget*(pos: Vec2i): uint8 =
  mget(pos.x, pos.y)

proc mapDraw*(tilePos, tileSize, destPos: Vec2i, size = vec2i(-1, -1), loop = false, offset = vec2i(0, 0)) =
  mapDraw(tilePos.x, tilepos.y, tileSize.x, tileSize.y, destPos.x, destpos.y, size.x, size.y, loop, offset.x, offset.y)

proc newMap*(index: int, size: Vec2i, tileSize = vec2i(8, 8)) =
  newMap(index, size.x, size.y, tileSize.x, tileSize.y)

{.pop.}
