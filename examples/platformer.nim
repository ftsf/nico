import nico
import math
import nico/vec
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
    ethereal: bool
    riding: Obj

  PlayerMode = enum
    Human
    Plane

  Weapon = enum
    Machinegun
    Shotgun
    Burst
    Noppy

  Player = ref object of Obj
    mode: PlayerMode
    weapon: Weapon
    wasOnGround: bool
    wasOnWall: bool
    jump: bool
    jbuffer: int
    grace: int
    dir: int
    step: int
    ammo: int
    firing: bool
    score: int
    hp: int
    hitflash: int
    combo: int
    bulletTimer: int

  Bullet = ref object of Obj
    damage: int
    destructive: bool
    ttl: int

  Block = ref object of Obj

  Crate = ref object of Block
    hp: int
    hitflash: int

  Platform = ref object of Block
    direction: int

  Boulder = ref object of Obj
    hp: int
    hitflash: int

  Fart = ref object of Obj
    ttl: int

  Gem = ref object of Obj
    size: int
    ttl: int

  Floater = ref object of Obj
    hp: int
    hitflash: int
    target: Obj

var player: Player
var gameOver: bool

proc newPlayer(x,y: int): Player =
  result = new(Player)
  result.pos.x = x
  result.pos.y = y
  result.hitbox.x = 2
  result.hitbox.w = 4
  result.hitbox.y = 1
  result.hitbox.h = 7
  result.hp = 4
  result.hitflash = 0

proc newCrate(x,y: int): Crate =
  result = new(Crate)
  result.pos.x = x
  result.pos.y = y
  result.hitbox.x = 0
  result.hitbox.w = 8
  result.hitbox.y = 0
  result.hitbox.h = 8
  result.hp = 4
  result.hitflash = 0

proc newPlatform(x,y: int, direction: int): Platform =
  result = new(Platform)
  result.pos.x = x
  result.pos.y = y
  result.hitbox.x = 0
  result.hitbox.w = 8
  result.hitbox.y = 0
  result.hitbox.h = 8
  result.direction = direction
  result.vel.x = direction.float * 0.1

proc newFloater(x,y: int): Floater =
  result = new(Floater)
  result.pos.x = x
  result.pos.y = y
  result.hitbox.x = 1
  result.hitbox.w = 6
  result.hitbox.y = 1
  result.hitbox.h = 6
  result.bounciness = 1.0
  result.hp = 2
  result.target = nil

proc newBullet(x,y: int,xv,yv: float): Bullet =
  result = new(Bullet)
  result.damage = 1
  result.pos.x = x
  result.pos.y = y
  result.vel.x = xv
  result.vel.y = yv
  result.hitbox.x = 2
  result.hitbox.w = 4
  result.hitbox.y = 3
  result.hitbox.h = 4
  result.ttl = 30

proc newFart(x,y: int,xv,yv: float): Fart =
  result = new(Fart)
  result.pos.x = x
  result.pos.y = y
  result.vel.x = xv
  result.vel.y = yv
  result.hitbox.x = 2
  result.hitbox.w = 4
  result.hitbox.y = 3
  result.hitbox.h = 4
  result.ttl = 4

proc newGem(x,y: int,xv,yv: float, size: int): Gem =
  result = new(Gem)
  result.size = size
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

proc overlaps(a,b: Obj): bool =
  let ax0 = a.pos.x + a.hitbox.x
  let ax1 = a.pos.x + a.hitbox.x + a.hitbox.w - 1
  let ay0 = a.pos.y + a.hitbox.y
  let ay1 = a.pos.y + a.hitbox.y + a.hitbox.h - 1

  let bx0 = b.pos.x + b.hitbox.x
  let bx1 = b.pos.x + b.hitbox.x + b.hitbox.w - 1
  let by0 = b.pos.y + b.hitbox.y
  let by1 = b.pos.y + b.hitbox.y + b.hitbox.h - 1
  return not ( ax0 > bx1 or ay0 > by1 or ax1 < bx0 or ay1 < by0 )

proc overlaps(a,b: Obj, ox,oy: int): bool =
  let ax0 = a.pos.x + a.hitbox.x + ox
  let ax1 = a.pos.x + a.hitbox.x + ox + a.hitbox.w - 1
  let ay0 = a.pos.y + a.hitbox.y + oy
  let ay1 = a.pos.y + a.hitbox.y + oy + a.hitbox.h - 1

  let bx0 = b.pos.x + b.hitbox.x
  let bx1 = b.pos.x + b.hitbox.x + b.hitbox.w - 1
  let by0 = b.pos.y + b.hitbox.y
  let by1 = b.pos.y + b.hitbox.y + b.hitbox.h - 1

  return not ( ax0 > bx1 or ay0 > by1 or ax1 < bx0 or ay1 < by0 )

proc appr(val, target, amount: float): float =
  return if val > target: max(val - amount, target) else: min(val + amount, target)

proc tileAt(x,y: int): uint8 =
  return mget(x div 8, y div 8)

proc isSolid(t: uint8): bool =
  return t != 0 and t != 33 and t != 5

proc isSpikes(t: uint8): bool =
  return t == 5

proc isTouchingType(x,y,w,h: int, check: proc(t: uint8): bool): bool =
  if x < 0 or x + w > 127 or y < 0:
    return check(255)
  for i in max(0,(x div 8))..min(15,(x+w-1) div 8):
    for j in max(0,(y div 8))..min(254,(y+h-1) div 8):
      let t = mget(i,j)
      if check(t):
        return true
  return false

proc check(self: Obj, t: typedesc, x,y: int): bool =
  for o in objects:
    if o != self and o of t:
      if self.overlaps(o, x, y):
        return true
  return false

proc getNearObj(self: Obj, t: typedesc, x,y: int): Obj =
  for o in objects:
    if o != self and o of t:
      if self.overlaps(o, x, y):
        return o
  return nil

method isSolid(self: Obj, ox,oy: int): bool {.base.} =
  return isTouchingType(self.pos.x+self.hitbox.x+ox, self.pos.y+self.hitbox.y+oy, self.hitbox.w, self.hitbox.h, isSolid)

proc isTouchingType(self: Obj, ox,oy: int, check: proc(t: uint8): bool): bool =
  return isTouchingType(self.pos.x+self.hitbox.x+ox, self.pos.y+self.hitbox.y+oy, self.hitbox.w, self.hitbox.h, check)

method collide(a,b: Obj) {.base.} =
  discard

method collide(a,b: Floater) =
  discard

method collide(a,b: Gem) =
  discard

method collide(a: Player, b: Gem) =
  b.shouldKill = true
  a.combo += 1
  a.score += 10 * a.combo
  synth(2, synSqr, 100.0 + (a.combo.float32 * 10.0), 0, 7, 12)
  pitchbend(2, 20)

method collide(a: Player, b: Floater) =
  if a.vel.y > 0 and a.pos.y + a.hitbox.y <= b.pos.y + b.hitbox.y:
    a.vel.y = -1.5
    b.shouldKill = true
    a.wasOnGround = true
    a.ammo = 8
    synth(3, synP12, 100.0, 4, -2, 20)
    pitchbend(3, -10)
    for i in 0..rnd(4):
      objects.add(newGem(b.pos.x, b.pos.y, rnd(2.0)-1.0, rnd(1.0)-0.5, if rnd(10) == 0: 1 else: 0))
  else:
    if a.hitflash == 0:
      a.hitflash = 30
      a.hp -= 1
      a.vel += (a.pos.vec2f - b.pos.vec2f) * 0.5
      if a.hp < 1:
        gameOver = true
        a.shouldKill = true

method collide(a: Bullet, b: Floater) =
  a.shouldKill = true
  if b.hitflash == 0:
    b.hp -= a.damage
    b.hitflash = 4
  b.vel += a.vel * 0.5
  synth(3, synP12, 100.0, 4, -2, 20)
  pitchbend(3, -10)
  if b.hp < 0:
    b.shouldKill = true
    for i in 0..rnd(4):
      objects.add(newGem(b.pos.x, b.pos.y, rnd(2.0)-1.0, rnd(1.0)-0.5, if rnd(10) == 0: 1 else: 0))

method collide(a: Floater, b: Bullet) =
  collide(b,a)

method collide(a: Crate, b: Bullet) =
  b.shouldKill = true
  if a.hitflash == 0:
    a.hitflash = 4
    a.hp -= b.damage
    if a.hp <= 0:
      a.shouldKill = true
      for i in 0..rnd(10):
        objects.add(newGem(a.pos.x, a.pos.y, rnd(2.0)-1.0, rnd(1.0)-0.5, if rnd(10) == 0: 1 else: 0))

method collide(a: Bullet, b: Crate) =
  collide(b,a)

proc moveX(self: Obj, amount, start: float) =
  var step = amount.int.sgn
  for i in start..<abs(amount.int):
    if self.ethereal or not self.isSolid(step,0) and not self.check(Block,step,0):
      self.pos.x += step
      for obj in objects:
        if obj.riding == self:
          obj.moveX(step.float, 0.0)
    else:
      self.vel.x = -self.vel.x * self.bounciness
      self.rem.x = 0
      break

proc moveY(self: Obj, amount: float) =
  var step = amount.int.sgn
  for i in 0..<abs(amount.int):
    if self.ethereal or not self.isSolid(0,step) and not self.check(Block,0,step):
      self.pos.y += step
    else:
      self.vel.y = -self.vel.y * self.bounciness
      self.rem.y = 0
      break

proc move(self: Obj, ox,oy: float) =
  self.rem.x += ox
  var amount = flr(self.rem.x + 0.5)
  self.rem.x -= amount
  self.moveX(amount,0)

  self.rem.y += oy
  amount = flr(self.rem.y + 0.5)
  self.rem.y -= amount
  self.moveY(amount)

method update(self: Obj) {.base.} =
  discard

method update(self: Crate) =
  if self.hitflash > 0:
    self.hitflash -= 1

method update(self: Platform) =
  if self.direction == 0:
    self.direction = if rnd(2) == 0: -1 else: 1
  if self.vel.x == 0 or (self.vel.x < 0 and self.pos.x < 16) or (self.vel.x > 0 and self.pos.x > 127-16-7):
    self.direction = -self.direction
  if self.direction == -1:
    self.vel.x = -0.1
  elif self.direction == 1:
    self.vel.x = 0.1

method collide(self: Player, other: Platform) =
  other.collide(self)

method update(self: Floater) =
  if self.target == nil:
    let d = length(self.pos.vec2f - player.pos.vec2f)
    if d < 32.0:
      self.target = player

  if self.target == nil or rnd(5) == 0:
    self.vel.x += rnd(0.1) - 0.05
    self.vel.y += rnd(0.1) - 0.05
  else:
    self.vel += (player.pos.vec2f - self.pos.vec2f) * 0.005 + rnd(0.01)
    let d = length(self.pos.vec2f - player.pos.vec2f)
    if d > 64.0:
      self.target = nil

  if abs(self.vel.x) > 0.25:
    self.vel.x *= 0.25
  if abs(self.vel.y) > 0.5:
    self.vel.y *= 0.5
  if self.hitflash > 0:
    self.hitflash -= 1




method update(self: Bullet) =
  if self.destructive:
    let x = self.pos.x div 8
    let y = (self.pos.y - 1) div 8
    let t = mget(x,y)
    if t >= 16.uint8:
      mset(x,y,0)
  self.ttl -= 1
  if self.vel.y == 0 and self.ttl > 4:
    self.ttl = 4
  if self.ttl < 0:
    self.shouldKill = true
  if not self.destructive:
    self.vel.y *= 0.95

method update(self: Fart) =
  self.ttl -= 1
  if self.ttl < 0 or self.vel.y == 0:
    self.shouldKill = true

method update(self: Gem) =
  self.ttl -= 1
  if self.ttl < 0:
    self.shouldKill = true
  self.vel.y = appr(self.vel.y, 0.5, 0.105)
  self.vel.x = appr(self.vel.x, 0.0, 0.001)

  let d = self.pos.vec2f - player.pos.vec2f
  if length(d) < 16.0:
    self.vel.x -= d.x * 0.01 + 0.1 * self.vel.x
    self.vel.y -= d.y * 0.01 + 0.1 * self.vel.x

proc transform(self: Player) =
  self.mode = Plane
  self.hitbox.x = 2
  self.hitbox.w = 12
  self.hitbox.y = 6
  self.hitbox.h = 8

method update(self: Player) =
  case self.mode:
  of Human:
    let input = if btn(pcRight): 1 elif btn(pcLeft): -1 else: 0
    if input < 0:
      self.dir = 0
    elif input > 0:
      self.dir = 1
    let onGround = self.isSolid(0,1) or self.check(Block,0,1)

    # check if we're on spikes
    if self.isTouchingType(0,0,isSpikes):
      if self.hitflash == 0:
        self.hp -= 1
        self.hitflash = 30
        self.vel.y = -2.0

    var o = self.getNearObj(Platform,0,1)
    if o == nil:
      o = self.getNearObj(Platform,1,0)
    if o == nil:
      o = self.getNearObj(Platform,-1,0)
    if o != nil:
      self.riding = o
    else:
      self.riding = nil

    let jump = btn(pcA) and not self.jump
    self.jump = btn(pcA)
    if jump:
      synth(0, synSqr, 400.0, 1, -7)
      pitchbend(0, 1)
      self.jbuffer = 8
    elif self.jbuffer > 0:
      self.jbuffer -= 1

    if self.hitflash > 0:
      self.hitflash -= 1

    var maxrun = 1.0
    var accel = 0.6
    var deccel = 0.15

    if not onGround:
      accel = 0.4

    if onGround:
      self.grace = 12

    if self.grace > 0:
      self.grace -= 1

    if abs(self.vel.x) > maxrun:
      self.vel.x = appr(self.vel.x, input.float * maxrun, deccel)
    else:
      self.vel.x = appr(self.vel.x, input.float * maxrun, accel)

    var maxfall = if btn(pcDown): 2.0 else: 1.5
    var gravity = if btn(pcDown): 0.21 else: 0.105

    if abs(self.vel.y) <= 0.15:
      gravity *= 0.5

    # wall slide
    if input != 0 and (self.isSolid(input,0) or self.check(Block,input,0)):
      maxfall = 0.4
      self.wasOnWall = true
    else:
      self.wasOnWall = false

    if not onGround:
      self.vel.y = appr(self.vel.y, maxfall, gravity)

    if self.jbuffer > 0:
      if self.grace > 0:
        # normal jump
        self.jbuffer = 0
        self.vel.y -= 2.0
      else:
        # wall jump
        if self.wasOnWall and input != 0:
          self.jbuffer = 0
          self.vel.y = -2.0
          self.vel.x = -input.float * (maxrun + 0.1)

    self.wasOnGround = onGround
    if self.wasOnGround:
      self.ammo = 8
      self.combo = 0

    let tx = (self.pos.x + 4) div 8
    let ty = (self.pos.y + 4) div 8
    if mget(tx,ty) == 33:
      mset(tx,ty,0)

    if btnp(pcA) and not self.wasOnGround and not self.wasOnWall:
      self.firing = true

    if btn(pcA) and self.firing and self.bulletTimer <= 0:

      if self.ammo <= 0:
        var fart = newFart(self.pos.x, self.pos.y + 8.0, 0, 2.0)
        objects.add(fart)
        self.bulletTimer = 16
      else:
        case self.weapon:
        of Machinegun:
          var bullet = newBullet(self.pos.x, self.pos.y + 4.0, 0, 4.0)
          objects.add(bullet)
          self.bulletTimer = 8
          self.ammo -= 1
          self.vel.y -= 0.1
          synth(1, synSqr, 1000.0, 3, -3)
          pitchbend(1, -40)
        of Shotgun:
          for i in 0..5:
            var bullet = newBullet(self.pos.x, self.pos.y + 4.0, rnd(2.0)-1.0, 4.0)
            objects.add(bullet)
            self.vel.y -= 0.2
          self.ammo -= 2
          self.bulletTimer = 16
        else:
          discard

    if not btn(pcA):
      self.firing = false

    elif self.bulletTimer > 0:
      self.bulletTimer -= 1

    if self.pos.y > 256 * 8 + 16 * 8:
      self.transform()

  of Plane:
    self.vel.y = appr(self.vel.y, -2.0, 0.01)
    let input = if btn(pcRight): 1.0 elif btn(pcLeft): -1.0 else: 0.0
    self.vel.x += input * 0.1
    self.vel.x *= 0.98

    if btn(pcA) and self.bulletTimer == 0:
      var bullet = newBullet(self.pos.x + 4, self.pos.y, rnd(1.0)-0.5, -4.0)
      bullet.destructive = true
      bullet.ttl = 60
      objects.add(bullet)
      self.bulletTimer = 4
    elif self.bulletTimer > 0:
      self.bulletTimer -= 1

method draw(self: Obj) {.base.} =
  setColor(2)
  rect(self.pos.x + self.hitbox.x, self.pos.y + self.hitbox.y, self.pos.x + self.hitbox.x + self.hitbox.w - 1, self.pos.y + self.hitbox.y + self.hitbox.h - 1)

method draw(self: Player) =
  case self.mode:
  of Human:
    let s = if abs(self.vel.x) > 1.0 and frame mod 10 < 5: 4 elif (self.dir == 0 and self.isSolid(-3, 0)) or (self.dir > 0 and self.isSolid(3,0)): (if self.wasOnGround: 1 else: 2) else: 0
    if self.hitflash > 0 and frame mod 10 < 5:
      return
    spr(s, self.pos.x, self.pos.y, 1, 1, self.dir == 1)
  of Plane:
    spr(64, self.pos.x, self.pos.y, 2, 2)

method draw(self: Bullet) =
  if self.ttl == 0 or self.isSolid(0,1):
    spr(36, self.pos.x, self.pos.y)
  else:
    spr(35, self.pos.x, self.pos.y)

method draw(self: Fart) =
  spr(37, self.pos.x, self.pos.y)

method draw(self: Gem) =
  if self.ttl < 60 and frame mod 10 < 5:
    return
  if frame mod 10 < 5:
    pal(1,3)
  if self.size == 0:
    if frame mod 30 < 15:
      spr(33, self.pos.x, self.pos.y)
    else:
      spr(34, self.pos.x, self.pos.y)
  else:
    let t = frame mod 60
    if t < 30:
      spr(39, self.pos.x, self.pos.y)
    else:
      spr(40, self.pos.x, self.pos.y)
  pal()

method draw(self: Floater) =
  if self.hitflash > 0 and frame mod 10 < 5:
    pal(2,3)
  spr(48 + ((frame.float / 30.0).int mod 4), self.pos.x, self.pos.y)
  pal(2,2)

method draw(self: Crate) =
  if self.hitflash > 0 and frame mod 10 < 5:
    pal(1,3)
  spr(28, self.pos.x, self.pos.y)
  pal(1,1)

method draw(self: Platform) =
  spr(30, self.pos.x, self.pos.y)

proc gameInit() =
  loadPaletteCGA()
  loadSpriteSheet(0, "platformer.png")

  objects = newSeq[Obj]()
  player = newPlayer(16,8)
  objects.add(player)
  gameOver = false

  newMap(0,16,256,8,8)
  setMap(0)
  for y in 0..<256:
    for x in 0..<16:
      if x <= 1 or x >= 14:
        mset(x,y,255)
        continue
      if y == 3:
        if x < 5 or x > 10:
          mset(x,y, (16+rnd(6)).uint8)
      if y > 16:
        let chance = if x < 5 or x > 11: 4 else: 16
        if mget(x,y-1) == 5:
          mset(x,y, (16+rnd(6)).uint8)
        elif rnd(chance) == 0:
          if rnd(20) == 0:
            # crate
            objects.add(newCrate(x*8,y*8))
          elif rnd(20) == 0:
            # platform
            objects.add(newPlatform(x*8,y*8,if rnd(2) == 0: -1 else: 1))
          elif rnd(20) == 0 and mget(x,y-1) == 0:
            # spikes
            mset(x,y, 5)
          elif mget(x,y-1) == 0:
            # solid
            mset(x,y, (16+rnd(6)).uint8)
          else:
            # solid
            mset(x,y, (16+6+rnd(6)).uint8)
        else:
          if y > 32 and rnd(64) == 0:
            objects.add(newFloater(x*8,y*8))


proc gameUpdate(dt: float32) =
  frame += 1

  if btnp(pcY):
    gameInit()

  if btnp(pcX):
    player.weapon = Shotgun

  if not gameOver:
    for obj in all(objects):
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

  mapDraw(0,0,16,256,0,0)
  setColor(1)
  line(15,cy,15,cy+127)
  line(127-15,cy,127-15,cy+127)

  for obj in objects:
    obj.draw()

  when defined(debugHitboxes):
    for obj in objects:
      setColor(1)
      rect(obj.pos.x + obj.hitbox.x, obj.pos.y + obj.hitbox.y,
        obj.pos.x + obj.hitbox.x + obj.hitbox.w - 1,
        obj.pos.y + obj.hitbox.y + obj.hitbox.h - 1)

  setCamera()
  setColor(3)
  print($player.score, 1, 1)

  setColor(if player.hitflash > 0 and frame mod 10 < 5: 3 else: 1)
  rectfill(126 - player.hp * 8, 1, 126, 4)

  setColor(2)
  rectfill(124, 10, 126, 10 + 4 * player.ammo)

  if gameOver:
    setColor(2)
    print("GAME OVER", 48, 60)

nico.init("nico","platformer")
nico.createWindow("platformer", 128, 128, 4)

loadFont(0, "font.png")
setFont(0)

fixedSize(true)
integerScale(true)

nico.run(gameInit, gameUpdate, gameDraw)
