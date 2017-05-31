import nico
import math
import vec
import sequtils

var frame = 0

type
  Hitbox = tuple
    x,y,w,h: int

  Obj = ref object of RootObj
    pos: Vec2i
    vel: Vec2f
    rem: Vec2f
    hitbox: Hitbox
    shouldKill: bool
    bounciness: float

  Hook = ref object of Obj
    attached: bool
    attachedObject: Obj
    player: Player
    length: float

  Player = ref object of Obj
    wasOnGround: bool
    wasOnWall: bool
    jump: bool
    jbuffer: int
    grace: int
    hook: Hook
    dir: int
    step: int
    ammo: int
    firing: bool
    score: int

  Bullet = ref object of Obj
    ttl: int

  Gem = ref object of Obj
    ttl: int

  Floater = ref object of Obj
    hp: int
    hitflash: int

var player: Player

proc newPlayer(x,y: int): Player =
  result = new(Player)
  result.pos.x = x
  result.pos.y = y
  result.hitbox.x = 2
  result.hitbox.w = 4
  result.hitbox.y = 1
  result.hitbox.h = 7

proc newFloater(x,y: int): Floater =
  result = new(Floater)
  result.pos.x = x
  result.pos.y = y
  result.hitbox.x = 1
  result.hitbox.w = 6
  result.hitbox.y = 1
  result.hitbox.h = 6
  result.bounciness = 1.0
  result.hp = 4

proc newHook(player: Player): Hook =
  result = new(Hook)
  result.player = player
  player.hook = result
  result.pos.x = player.pos.x
  result.pos.y = player.pos.y
  result.vel.x = player.vel.x * 4.0
  result.vel.y = -4.0
  result.hitbox.x = 2
  result.hitbox.w = 4
  result.hitbox.y = 2
  result.hitbox.h = 4
  result.length = 16.0

proc newBullet(x,y: int,xv,yv: float): Bullet =
  result = new(Bullet)
  result.pos.x = x
  result.pos.y = y
  result.vel.x = xv
  result.vel.y = yv
  result.hitbox.x = 2
  result.hitbox.w = 4
  result.hitbox.y = 3
  result.hitbox.h = 4
  result.ttl = 12

proc newGem(x,y: int,xv,yv: float): Gem =
  result = new(Gem)
  result.pos.x = x
  result.pos.y = y
  result.vel.x = xv
  result.vel.y = yv
  result.hitbox.x = 2
  result.hitbox.w = 4
  result.hitbox.y = 3
  result.hitbox.h = 4
  result.ttl = 60 * 5
  result.bounciness = 0.75

var cx,cy = 0.0
var objects: seq[Obj]


{.this:self.}

proc overlaps(a,b: Obj): bool =
  let ax0 = a.pos.x + a.hitbox.x
  let bx0 = b.pos.x + b.hitbox.x
  let ax1 = a.pos.x + a.hitbox.x + a.hitbox.w - 1
  let bx1 = b.pos.x + b.hitbox.x + b.hitbox.w - 1
  let ay0 = a.pos.y + a.hitbox.y
  let by0 = b.pos.y + b.hitbox.y
  let ay1 = a.pos.y + a.hitbox.y + a.hitbox.w - 1
  let by1 = b.pos.y + b.hitbox.y + b.hitbox.w - 1
  return not ( ax0 > bx1 or ay0 > by1 or ax1 < bx0 or ay1 < by0 )

proc appr(val, target, amount: float): float =
  return if val > target: max(val - amount, target) else: min(val + amount, target)

proc tileAt(x,y: int): uint8 =
  return mget(x div 8, y div 8)

proc isSolid(t: uint8): bool =
  return t != 0 and t != 33

proc isSolid(x,y,w,h: int): bool =
  if x < 0 or x + w > 127 or y < 0:
    return true
  for i in max(0,(x div 8))..min(15,(x+w-1) div 8):
    for j in max(0,(y div 8))..min(511,(y+h-1) div 8):
      let t = mget(i,j)
      if isSolid(t):
        return true
  return false

method isSolid(self: Obj, ox,oy: int): bool {.base.} =
  #if oy > 0 and not check(platform, ox, 0) and check(platform, ox,oy):
  #  return true
  return isSolid(pos.x+hitbox.x+ox, pos.y+hitbox.y+oy, hitbox.w, hitbox.h)

method collide(a,b: Obj) {.base.} =
  discard

method collide(a,b: Floater) =
  discard

method collide(a,b: Gem) =
  discard

method collide(a: Player, b: Gem) =
  b.shouldKill = true
  a.score += 10

method collide(a: Player, b: Floater) =
  if a.vel.y > 0:
    a.vel.y = -1.5
    b.shouldKill = true
    a.wasOnGround = true
    a.ammo = 8
    for i in 0..rnd(4):
      objects.add(newGem(b.pos.x, b.pos.y, rnd(2.0)-1.0, rnd(1.0)-0.5))

method collide(a: Bullet, b: Floater) =
  a.shouldKill = true
  b.hp -= 1
  b.hitflash = 4
  b.vel += a.vel * 0.5
  if b.hp < 0:
    b.shouldKill = true
    for i in 0..rnd(4):
      objects.add(newGem(b.pos.x, b.pos.y, rnd(2.0)-1.0, rnd(1.0)-0.5))

method collide(b: Floater, a: Bullet) =
  a.shouldKill = true
  b.hp -= 1
  b.hitflash = 4
  b.vel += a.vel * 0.5
  if b.hp < 0:
    b.shouldKill = true
    for i in 0..rnd(4):
      objects.add(newGem(b.pos.x, b.pos.y, rnd(2.0)-1.0, rnd(1.0)-0.5))

method moveX(self: Obj, amount, start: float) {.base.} =
  var step = amount.int.sgn
  for i in start..<abs(amount.int):
    if not isSolid(step,0):
      pos.x += step
    else:
      vel.x = -vel.x * bounciness
      rem.x = 0
      break

method moveY(self: Obj, amount: float) {.base.} =
  var step = amount.int.sgn
  for i in 0..<abs(amount.int):
    if not isSolid(0,step):
      pos.y += step
    else:
      vel.y = -vel.y * bounciness
      rem.y = 0
      break

method move(self: Obj, ox,oy: float) {.base.} =
  rem.x += ox
  var amount = flr(rem.x + 0.5)
  rem.x -= amount
  moveX(amount,0)

  rem.y += oy
  amount = flr(rem.y + 0.5)
  rem.y -= amount
  moveY(amount)

method update(self: Obj) {.base.} =
  discard

method update(self: Hook) =
  if not attached:
    vel.x = appr(vel.x, 0.0, 0.15)
    vel.y = appr(vel.y, 2.0, 0.21)
    if isSolid(0,-1):
      vel.y = 0
      vel.x = 0
      attached = true
      length = length(pos.vec2f - player.pos.vec2f) / 2.0

  if attached:
    if player.hook == self:
      let springv = player.pos.vec2f - pos.vec2f
      let currentLength = length(springv)
      let desiredLength = self.length
      if desiredLength < currentLength:
        let displacement = currentLength - desiredLength
        let k = 0.01
        let restoreForce = springv * displacement * k
        let b = 0.5
        player.vel.x -= restoreForce.x + b * player.vel.x
        player.vel.y -= restoreForce.y + b * player.vel.y

method update(self: Floater) =
  vel.x += rnd(0.1) - 0.05
  vel.y += rnd(0.1) - 0.05
  if abs(vel.x) > 0.5:
    vel.x *= 0.5
  if abs(vel.y) > 0.5:
    vel.y *= 0.5

method update(self: Bullet) =
  ttl -= 1
  if ttl < 0 or vel.y == 0:
    shouldKill = true

method update(self: Gem) =
  ttl -= 1
  if ttl < 0:
    shouldKill = true
  vel.y = appr(vel.y, 0.5, 0.105)
  vel.x = appr(vel.x, 0.0, 0.001)

  let d = pos.vec2f - player.pos.vec2f
  if length(d) < 16.0:
    vel.x -= d.x * 0.01 + 0.1 * vel.x
    vel.y -= d.y * 0.01 + 0.1 * vel.x

method update(self: Player) =
  let input = if btn(pcRight): 1 elif btn(pcLeft): -1 else: 0
  if input < 0:
    dir = 0
  elif input > 0:
    dir = 1
  let onGround = isSolid(0,1)

  let jump = btn(pcA) and not self.jump
  self.jump = btn(pcA)
  if jump:
    jbuffer = 8
  elif jbuffer > 0:
    jbuffer -= 1

  var maxrun = 1.0
  var accel = 0.6
  var deccel = 0.15

  if not onGround:
    accel = 0.4

  if onGround:
    grace = 12

  if grace > 0:
    grace -= 1

  if abs(vel.x) > maxrun:
    vel.x = appr(vel.x, input.float * maxrun, deccel)
  else:
    vel.x = appr(vel.x, input.float * maxrun, accel)

  var maxfall = 1.5
  var gravity = 0.105

  if abs(vel.y) <= 0.15:
    gravity *= 0.5

  # wall slide
  if input != 0 and isSolid(input,0):
    maxfall = 0.4
    wasOnWall = true
  else:
    wasOnWall = false

  if not onGround:
    vel.y = appr(vel.y, maxfall, gravity)

  if jbuffer > 0:
    if grace > 0:
      # normal jump
      jbuffer = 0
      vel.y -= 2.0
    else:
      # wall jump
      let wallDir = if isSolid(-3,0): -1.0 elif isSolid(3,0): 1.0 else: 0.0
      if wallDir != 0 and wallDir == input:
        jbuffer = 0
        vel.y = -2.0
        vel.x = -wallDir * (maxrun + 0.1)

  wasOnGround = onGround
  if wasOnGround:
    ammo = 8

  let tx = (pos.x + 4) div 8
  let ty = (pos.y + 4) div 8
  if mget(tx,ty) == 33:
    mset(tx,ty,0)


method draw(self: Obj) {.base.} =
  setColor(1)
  circfill(pos.x,pos.y,2)
  rect(pos.x + hitbox.x, pos.y + hitbox.y, pos.x + hitbox.x + hitbox.w - 1, pos.y + hitbox.y + hitbox.h - 1)

method draw(self: Player) =
  let s = if abs(vel.x) > 1.0 and frame mod 10 < 5: 4 elif (dir == 0 and isSolid(-3, 0)) or (dir > 0 and isSolid(3,0)): (if wasOnGround: 1 else: 2) else: 0
  spr(s, pos.x, pos.y, 1, 1, dir == 1)

method draw(self: Hook) =
  setColor(1)
  line(pos.x + 4, pos.y + 4, player.pos.x + 4, player.pos.y + 2)
  spr(36, pos.x, pos.y)

method draw(self: Bullet) =
  if ttl == 0 or isSolid(0,1):
    spr(36, pos.x, pos.y)
  else:
    spr(35, pos.x, pos.y)

method draw(self: Gem) =
  if ttl < 60 and frame mod 10 < 5:
    return
  if frame mod 10 < 5:
    pal(1,3)
  if frame mod 30 < 15:
    spr(33, pos.x, pos.y)
  else:
    spr(34, pos.x, pos.y)
  pal()

method draw(self: Floater) =
  if hitflash > 0:
    pal(2,3)
    hitflash -= 1
  spr(48 + ((frame.float / 30.0).int mod 4), pos.x, pos.y)
  pal(2,2)

proc gameInit() =
  loadPaletteCGA()
  loadSpriteSheet("platformer.png")

  objects = newSeq[Obj]()
  mset(1,1,0)
  mset(1,2,0)
  mset(1,3,0)
  player = newPlayer(8,8)
  objects.add(player)

  newMap(16,512)
  for y in 0..<512:
    for x in 0..<16:
      let chance = if x < 5 or x > 11: 4 else: 16
      if rnd(chance) == 0:
        mset(x,y, (16+rnd(6)).uint8)
      else:
        if rnd(16) == 0:
          objects.add(newFloater(x*8,y*8))

var bulletTimer = 0

proc gameUpdate(dt: float) =
  frame += 1

  if btnp(pcA) and not player.wasOnGround and not player.wasOnWall and player.ammo > 0:
    player.firing = true

  if btn(pcA) and player.firing and bulletTimer <= 0 and player.ammo > 0:
    objects.add(newBullet(player.pos.x, player.pos.y, 0, 4.0))
    bulletTimer = 8
    player.ammo -= 1
    player.vel.y -= 0.25

  if not btn(pcA):
    player.firing = false

  if btnp(pcB):
    if player.hook == nil:
      objects.add(newHook(player))
  if not btn(pcB) and player.hook != nil:
      player.hook.shouldKill = true
      player.hook = nil

  elif bulletTimer > 0:
    bulletTimer -= 1

  if btnp(pcY):
    gameInit()

  if btn(pcUp) and player.hook != nil:
    if player.hook.length > 2.0:
      player.hook.length -= 0.5
  if btn(pcDown) and player.hook != nil:
    if player.hook.length < 64.0:
      player.hook.length += 0.5

  for obj in mitems(objects):
    obj.move(obj.vel.x, obj.vel.y)
    obj.update()

  for i in 0..<objects.len:
    for j in i+1..<objects.len:
      let a = objects[i]
      let b = objects[j]
      if a.overlaps(b):
        collide(a,b)

  objects.keepIf() do(a: Obj) -> bool:
    a.shouldKill == false

  cy = lerp(cy, player.pos.y.float - 64.0, 0.1)

proc gameDraw() =
  cls()

  setCamera(cx.int,cy.int)

  mapDraw(0,0,16,512,0,0)
  for obj in objects:
    obj.draw()

  setCamera()
  setColor(3)
  print($player.score, 1, 1)

nico.init("nico","platformer")
nico.createWindow("platformer", 128, 128, 4)
nico.run(gameInit, gameUpdate, gameDraw)
