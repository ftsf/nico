import nico
import nico/vec
import nico/console
import nico/tweaks
import sets
import hashes
#import queues
import sequtils

{.this:self.}

type Bullet = object
  pos: Vec2f
  vel: Vec2f
  ttl: float32

type BoidState = enum
  Mine
  Vertex
  Protected
  Battleship

type Boid = ref object
  toKill: bool
  state: BoidState
  stateChangeTimeout: float32
  activated: bool
  badActivated: bool
  ttl: float32
  id: int
  pos: Vec2f
  lastPos: Vec2f
  vel: Vec2f
  targetVel: Vec2f
  steering: Vec2f
  angle: float32
  mass: float32
  cohesion: float32
  separation: float32
  alignment: float32
  maxForce: float32
  maxSpeed: float32
  neighbors: HashSet[Boid]
  shootTimeout: float32
  health: float32
  splitTimer: float32
  introTimer: float32

var nextId = 0

proc newBoid(pos: Vec2f): Boid =
  result = new(Boid)
  result.id = nextId
  result.introTimer = 1.0
  result.toKill = false
  result.state = Mine
  result.stateChangeTimeout = 0.5
  nextId += 1
  result.pos = pos
  result.health = 0.5
  result.lastPos = result.pos
  result.mass = 5.0
  result.cohesion = 3.5
  result.separation = 10.0
  result.maxForce = 10.0
  result.maxSpeed = 5.0
  result.alignment = 0.5
  result.shootTimeout = 5.0
  result.splitTimer = 10.0
  result.neighbors = initSet[Boid]()

proc hash(self: Boid): Hash =
  var h: Hash = 0
  h = h !& self.id
  result = !$h

proc seek(self: Boid, target: Vec2f, weight = 1.0) =
  if (target - pos).sqrMagnitude > 0.01:
    steering += (target - pos).normalized * maxSpeed * weight

proc arrive(self: Boid, target: Vec2f, stoppingDistance = 1.0, weight = 1.0) =
  steering += (target - pos).normalized * maxSpeed * weight


var boids: seq[Boid]
var bgBoids: seq[Boid]
var bullets: seq[Bullet]
var score = 0
var lives = 3
var wave = 1

var ship: Boid
var invulerable = 0.0

var waveTimer = 60.0
var waveSpawnTimer = 10.0

const maxBoids = 500
const minBoids = 20
const maxBullets = 20

const cohesionRadius = 16.0
const separationRadius = 12.0

const shipMaxSpeed = 25.0
const shipMaxForce = 100.0
const shipAttackRadius = 12.0

proc gameInit() =
  reloadTweaks()

  setConsoleBG(24)
  setConsoleFG(21)

  score = 0
  lives = 3
  waveTimer = 60.0
  waveSpawnTimer = 1.5
  wave = 1
  invulerable = 5.0

  boids = @[]
  bgBoids = @[]
  bullets = @[]

  ship = newBoid(vec2f(screenWidth.float32 / 2.0, screenHeight.float32 / 2.0))

  registerConsoleCommand("restart", proc(args: seq[string]): seq[string] =
    gameInit()
  )

  while bgBoids.len < 50:
    var newPos = vec2f(rnd(screenWidth.float32), rnd(screenHeight.float32))
    bgBoids.add(newBoid(newPos))

  consoleLog("restarting")

var shake = 0.0

proc spawnRandomBoid(): Boid =
  var newPos = vec2f(rnd(screenWidth.float32), rnd(screenHeight.float32))
  if further(newPos, ship.pos, 32.0):
    if boids.len < maxBoids:
      var boid = newBoid(newPos)
      return boid
  return nil

proc gameUpdate(dt: float32) =
  if invulerable > 0:
    invulerable -= dt

  if waveSpawnTimer <= 0 and boids.len < minBoids:
    waveTimer = 0

  waveTimer -= dt
  if waveTimer < 0:
    waveTimer = 60.0
    wave += 1
    waveSpawnTimer = wave.float32 * 1.0

  if waveSpawnTimer > 0:
    var b = spawnRandomBoid()
    if b != nil:
      boids.add(b)
    waveSpawnTimer -= dt

  for b in mitems(bullets):
    b.pos += b.vel * dt
    b.ttl -= dt

  bullets.keepItIf(it.ttl > 0)

  if shake > 0:
    shake -= dt

  boids.keepItIf(it.toKill == false)

  if btn(pcLeft):
    ship.vel.x -= shipMaxForce * dt

  if btn(pcRight):
    ship.vel.x += shipMaxForce * dt

  if btn(pcUp):
    ship.vel.y -= shipMaxForce * dt

  if btn(pcDown):
    ship.vel.y += shipMaxForce * dt

  if mousebtn(0):
    let (mx,my) = mouse()
    let mv = vec2f(mx,my)
    let diff = (mv - ship.pos)
    if diff.sqrMagnitude > 0.01:
      ship.vel += (mv - ship.pos).normalized * shipMaxForce * dt

  ship.vel = clamp(ship.vel, shipMaxSpeed)

  if ship.vel.sqrMagnitude > 0.01:
    let d = angleDiff(ship.vel.angle(), ship.angle)
    ship.angle = ship.angle + d * 0.1

  ship.pos += ship.vel * dt

  ship.vel += -ship.vel * 0.9 * dt

  if ship.pos.x < 0:
    ship.pos.x = screenWidth.float32
    ship.lastPos.x = ship.pos.x
  if ship.pos.y < 0:
    ship.pos.y = screenHeight.float32
    ship.lastPos.y = ship.pos.y
  if ship.pos.x > screenWidth:
    ship.pos.x = 0
    ship.lastPos.x = 0
  if ship.pos.y > screenHeight:
    ship.pos.y = 0
    ship.lastPos.y = 0

  # background
  for b in mitems(bgBoids):
    b.lastPos = b.pos
    b.steering = vec2f()

    var avgpos = b.pos
    var avgvel = b.vel
    var nflockmates = 1

    if not b.activated:
      b.neighbors.clear()

    for j in bgBoids:
      if j != b:
        if nearer(b.pos,j.pos, cohesionRadius):
          avgpos += j.pos
          avgvel += j.vel
          nflockmates += 1
          b.neighbors.incl(j)
        if nearer(b.pos,j.pos, separationRadius):
          b.seek(j.pos, -b.separation)

    if nflockmates > 1:
      avgpos /= nflockmates.float32
      avgvel /= nflockmates.float32
      b.seek(avgpos, if b.activated: b.cohesion * 10.0 else: b.cohesion)
      b.seek(b.pos + avgvel, b.alignment)

    b.steering = clamp(b.steering, b.maxForce)

    b.vel += b.steering * (1.0 / b.mass) * dt

    b.vel = clamp(b.vel, b.maxSpeed)

    b.pos += b.vel * dt
    if b.pos.x < 0:
      b.pos.x = screenWidth.float32
      b.lastPos.x = b.pos.x
    if b.pos.y < 0:
      b.pos.y = screenHeight.float32
      b.lastPos.y = b.pos.y
    if b.pos.x > screenWidth:
      b.pos.x = 0
      b.lastPos.x = 0
    if b.pos.y > screenHeight:
      b.pos.y = 0
      b.lastPos.y = 0



  var newBoids: seq[Boid] = @[]

  # main
  for b in mitems(boids):
    b.lastPos = b.pos
    b.steering = vec2f()

    if b.introTimer > 0:
      b.introTimer -= dt

    if b.activated:
      b.seek(ship.pos, -50.0)
      b.ttl -= dt
      if b.ttl < 0:
        b.toKill = true

    if b.state == Mine:
      if nearer(b.pos, ship.pos, cohesionRadius):
        b.maxSpeed = 10.0
        b.maxForce = 50.0
      b.seek(ship.pos, 50.0)

    if b.state == Battleship:
      if b.shootTimeout < 0 and bullets.len < maxBullets:
        b.shootTimeout = 10.0
        var bullet: Bullet
        bullet.pos = b.pos
        let diff = ship.pos - b.pos
        let mag = diff.magnitude
        bullet.vel = ((ship.pos + ship.vel * mag * 0.001) - b.pos).normalized * 20.0
        bullet.ttl = 10.0
        bullets.add(bullet)
      else:
        b.shootTimeout -= dt

    var avgpos = b.pos
    var avgvel = b.vel
    var nflockmates = 1

    if not b.activated:
      b.neighbors.clear()

    for j in boids:
      if j != b:
        if nearer(b.pos,j.pos, cohesionRadius):
          avgpos += j.pos
          avgvel += j.vel
          nflockmates += 1
          b.neighbors.incl(j)
        if nearer(b.pos,j.pos, separationRadius):
          b.seek(j.pos, -b.separation)

    if nflockmates > 1:
      avgpos /= nflockmates.float32
      avgvel /= nflockmates.float32
      b.seek(avgpos, if b.activated: b.cohesion * 10.0 else: b.cohesion)
      b.seek(b.pos + avgvel, b.alignment)

    # state changes
    if b.health > 0.5:
      if b.neighbors.len == 0:
        if b.state != Mine:
          b.stateChangeTimeout -= dt
          if b.stateChangeTimeout < 0:
            b.state = Mine
            b.stateChangeTimeout = 0.5
      elif b.neighbors.len >= 5:
        if b.state != Battleship:
          b.stateChangeTimeout -= dt
          if b.stateChangeTimeout < 0:
            b.state = Battleship
            b.stateChangeTimeout = 0.5
      elif b.neighbors.len == 1:
        if b.state != Vertex:
          b.stateChangeTimeout -= dt
          if b.stateChangeTimeout < 0:
            b.state = Vertex
            b.stateChangeTimeout = 0.5
      else:
        if b.state != Protected:
          b.stateChangeTimeout -= dt
          if b.stateChangeTimeout < 0:
            b.state = Protected
            b.splitTimer = 20.0
            b.stateChangeTimeout = 0.5
    else:
      b.health += dt * 0.1

    if not b.activated and (b.state == Mine or b.state == Battleship or b.state == Protected):
      b.splitTimer -= dt
      if b.splitTimer < 0:
        # split one mine into 3
        if boids.len < maxBoids:
          var b2 = newBoid(b.pos + rndVec(0.1))
          b2.vel = b.vel + rndVec(0.01)
          newBoids.add(b2)
          if b.state == Mine:
            var b3 = newBoid(b.pos + rndVec(0.1))
            b3.vel = b.vel + rndVec(0.01)
            newBoids.add(b3)
            b.splitTimer = 10.0
          else:
            b.splitTimer = 30.0

    b.steering = clamp(b.steering, b.maxForce)

    b.vel += b.steering * (1.0 / b.mass) * dt

    b.vel = clamp(b.vel, b.maxSpeed)

    b.pos += b.vel * dt
    if b.pos.x < 0:
      b.pos.x = screenWidth.float32
      b.lastPos.x = b.pos.x
    if b.pos.y < 0:
      b.pos.y = screenHeight.float32
      b.lastPos.y = b.pos.y
    if b.pos.x > screenWidth:
      b.pos.x = 0
      b.lastPos.x = 0
    if b.pos.y > screenHeight:
      b.pos.y = 0
      b.lastPos.y = 0

    if not b.activated:
      if b.state == Vertex:
        if nearer(b.pos, ship.pos, shipAttackRadius):
          # attack
          b.health -= dt
          if b.health < 0:
            b.activated = true
            b.ttl = 0.5
            score += 1

      if invulerable <= 0 and nearer(b.pos, ship.pos, 3.0):
        # do damage to player
        lives -= 1
        invulerable = 1.0
        shake = 0.5
        b.activated = true
        b.badActivated = true

        var nb = spawnRandomBoid()
        if nb != nil:
          newBoids.add(nb)
        nb = spawnRandomBoid()
        if nb != nil:
          newBoids.add(nb)

        b.ttl = 0.1
        if lives < 0:
          gameInit()
          return

    if b.activated and b.ttl < 0.25:
      # kill the chain

      for n in b.neighbors:
        if not n.activated:
          n.activated = true
          n.ttl = 0.5
          if b.badActivated:
            n.badActivated = true
            var nb = spawnRandomBoid()
            if nb != nil:
              newBoids.add(nb)
            nb = spawnRandomBoid()
            if nb != nil:
              newBoids.add(nb)
          else:
            let scoreAdd = case b.state:
            of Mine: 0
            of Vertex: 1
            of Protected: 5
            of Battleship: 20
            score += scoreAdd

  for b in mitems(bullets):
    if invulerable <= 0 and nearer(b.pos, ship.pos, 3.0):
      # do damage to player
      lives -= 1
      invulerable = 1.0
      shake = 0.5
      b.ttl = 0.0
      if lives < 0:
        gameInit()
        return

  boids.add(newBoids)

var frame: uint16 = 0

proc gameDraw() =
  frame += 1
  clip()
  setColor(26)
  rectfill(0,0,screenWidth,screenHeight)

  if shake > 0.0:
    setCamera(rnd(2.0)-1.0, rnd(2.0)-1.0)
  else:
    setCamera()

  for b in boids:
    for n in b.neighbors:
      setColor(23)
      if nearer(b.pos, n.pos, cohesionRadius):
        if not n.activated:
          line(b.pos.vec2i, n.pos.vec2i)
        if b.activated:
          setColor(if b.badActivated: 25 else: 18)
          line(b.pos.vec2i, lerp(b.pos, n.pos, clamp(invLerp(0.5, 0.25, b.ttl), 0.0, 1.0)).vec2i)

    if b.state == Vertex:
      setColor(if frame mod 4 < 2: 19 else: 18)
      # attacking
      if nearer(b.pos, ship.pos, shipAttackRadius):
        line(b.pos.vec2i, ship.pos.vec2i)
    else:
      setColor(25)
      if nearer(b.pos, ship.pos, 3.0):
        line(b.pos.vec2i, ship.pos.vec2i)

    if b.introTimer > 0:
      setColor(25)
      circ(b.pos.x, b.pos.y, b.introTimer * 5.0)

    if b.activated and b.ttl < 0.5:
      setColor(if b.badActivated: 25 else: 18)
      circ(b.pos.x, b.pos.y, b.ttl * 5.0)

  for b in boids:
    if b.state == Mine:
      setColor(if b.activated and not b.badActivated: 18 else: 25)
      circ(b.pos.x, b.pos.y, 1)
    else:
      setColor(if b.activated: (if b.badActivated: 25 else: 18) elif b.state == Vertex: 1 else: 25)
      if b.state == Vertex:
        circ(b.pos.x, b.pos.y, 1)
      elif b.state == Battleship:
        circfill(b.pos.x, b.pos.y, if b.shootTimeout < 1.0: 2 else: 1)
        if b.shootTimeout < 0.5:
          setColor(19)
          circfill(b.pos.x, b.pos.y, 1)
      else:
        pset(b.pos.x, b.pos.y)

  # draw ship
  block:
    setColor(if invulerable > 0 and frame mod 4 < 2: 19 else: 18)
    let pa = ship.pos + rotate(vec2f(-3.0, 2.0), ship.angle)
    let pb = ship.pos + rotate(vec2f(4.0, 0.0), ship.angle)
    let pc = ship.pos + rotate(vec2f(-3.0, -2.0), ship.angle)
    line(pa, pb)
    line(pb, pc)
    line(pc, pa)

  for b in bullets:
    setColor(19)
    circfill(b.pos.x, b.pos.y, 1)

  #setColor(1)
  #hslider(1,1,32,5, cohesion, 0, 50, "COHE")
  #hslider(1,1+6,32,5, separation, 0, 50, "SEPA")
  #hslider(1,1+6+6,32,5, separationRadius, 4, 32, "SEPR")
  #hslider(1,1+6+6+6,32,5, maxForce, 1, 32, "MAXF")
  #hslider(1,1+6+6+6+6,32,5, alignment, 0, 5, "ALGN")
  #hslider(1,1+6+6+6+6+6,32,5, maxSpeed, 0, 10, "MAXV")
  #hslider(1,1+6+6+6+6+6+6,32,5, mass, 0.1, 10, "MASS")
  #hslider(1,1+6+6+6+6+6+6+6,32,5, cohesionRadius, 1, 128, "COHR")

  setColor(18)
  printr($score, screenWidth - 1, 1)
  setColor(25)
  printr($lives, screenWidth - 1, 9)

  if waveSpawnTimer > 0:
    setColor(19)
    printc("WAVE " & $wave, screenWidth div 2, screenHeight div 4)

  drawConsole()

nico.init("impbox", "vertex")

nico.createWindow("vertex prototype", 1920 div 6 , 1080 div 6, 5)

loadPaletteFromGPL("palette.gpl")
loadSpritesheet(0, "spritesheet.png")
setSpritesheet(0)

loadFont(0, "font.png")
setFont(0)

fixedSize(true)
integerScale(true)
nico.run(gameInit, gameUpdate, gameDraw)
