import nico
import nico/vec
import strformat

type Object = ref object
  color: int
  pos: Vec2f
  rawPoints: seq[Vec2f]
  angle: float32
  highlightEdgeIndex: int
  highlightVertIndex: int
  highlightColor: int
  bestSupport: Vec2f
  supportDir: Vec2f
  mass: float32
  vel: Vec2f
  avel: float32

type Line = array[2, Vec2f]

type ContactData = object
  normal: Vec2f
  nPoints: int
  points: array[2, Vec2f]
  penetration: float32
  clipEdge: Line

proc `-`(x: Line): Line =
  result[0] = x[1]
  result[1] = x[0]

type Plane2D = object
  pos: Vec2f
  normal: Vec2f

var objs: seq[Object]

var overlapping = false
var overlapAxis: Vec2f
var overlapAmount: float32
var overlapClipEdge: Line
var overlapContactData: ContactData

proc normal(self: Line): Vec2f =
  return (self[1] - self[0]).normal()

proc point(self: Object, i: int): Vec2f =
  return self.pos + self.rawPoints[i].rotate(self.angle)

proc toPlane(self: Line): Plane2D =
  result.pos = self[0]
  result.normal = -self.normal()

proc distance(self: Plane2D, p: Vec2f): float32 =
  ## return signed distance from plane to point
  return dot(self.normal, p - self.pos)

iterator points(self: Object): Vec2f =
  let pos = self.pos
  for p in self.rawPoints:
    let rotated = p.rotate(self.angle)
    yield pos + rotated

proc edge(self: Object, i: int): Line =
  let pos = self.pos
  let a = self.rawPoints[wrap(i,  self.rawPoints.len)].rotate(self.angle)
  let b = self.rawPoints[wrap(i+1,self.rawPoints.len)].rotate(self.angle)
  return [pos + a, pos + b]

iterator edges(self: Object): Line =
  let pos = self.pos
  for i in 1..<self.rawPoints.len:
    let a = self.rawPoints[i-1].rotate(self.angle)
    let b = self.rawPoints[i].rotate(self.angle)
    yield [pos + a, pos + b]
  block:
    let a = self.rawPoints[self.rawPoints.high].rotate(self.angle)
    let b = self.rawPoints[0].rotate(self.angle)
    yield [pos + a, pos + b]

proc getAxes(a,b: Object): seq[Vec2f] =
  for edge in a.edges:
    let axis = edge.normal()
    if axis notin result:
      result.add(axis)
  for edge in b.edges:
    let axis = edge.normal()
    if axis notin result:
      result.add(axis)

proc getSupport(self: Object, n: Vec2f): (Vec2f,int) =
  var bestProj = -Inf
  var i = 0
  for p in self.points:
    let proj = dot(p, n)
    if proj > bestProj:
      bestProj = proj
      result = (p, i)
    i.inc()

proc line(self: Plane2D): Line =
  [self.pos, self.pos + self.normal]

proc isLeftOf(p: Vec2f, edge: Line): bool =
  ## returns true if p is left of edge
  let tmp1 = edge[1] - edge[0]
  let tmp2 = p - edge[1]

  let x = (tmp1.x * tmp2.y) - (tmp1.y * tmp2.x)

  if x < 0:
    return false
  elif x > 0:
    return true
  else:
    # colinear points
    return false

proc getIntersect(a,b: Line): Vec2f =
  ## returns the intersection of two lines
  let adir = a[1] - a[0]
  let bdir = b[1] - b[0]

  let dotPerp = (adir.x * bdir.y) - (adir.y * bdir.x)

  if abs(dotPerp) < 0.0001f:
    # parallel
    return

  let c = b[0] - a[0]
  let t = (c.x * bdir.y - c.y * bdir.x) / dotPerp

  return a[0] + (t * adir)

proc clip(ln: Line, plane: Line): Line =
  # returns ln clipped by plane
  result = ln
  # get intersection of ln and plane
  let i = getIntersect(ln, plane)
  let aOK = ln[0].isLeftOf(plane)
  let bOK = ln[1].isLeftOf(plane)
  if not aOK and not bOK:
    # both on wrong side of plane
    result[0] = i
    result[1] = i
  elif not aOK:
    result[0] = i
    result[1] = ln[1]
  elif not bOK:
    result[0] = ln[0]
    result[1] = i

proc clipRemove(ln: Line, plane: Line): seq[Vec2f] =
  # returns points of ln, removing anything behind plane
  # get intersection of ln and plane
  let aOK = ln[0].isLeftOf(plane)
  if aOK:
    result.add(ln[0])
  let bOK = ln[1].isLeftOf(plane)
  if bOK:
    result.add(ln[1])

proc getContactData(a,b: Object, collisionNormal: Vec2f, penetration: float32): ContactData =
  ## returns the indices of the significant edges on A and B
  let vertA = a.getSupport(collisionNormal)
  let vertB = b.getSupport(-collisionNormal)

  var bestAEdgeDot: float32 = -Inf
  var bestAEdge: int = -1
  var bestBEdgeDot: float32 = -Inf
  var bestBEdge: int = -1

  block:
    var i = 0
    for edge in a.edges:
      if vertA[0] in edge:
        let d = dot(edge.normal, collisionNormal)
        if abs(d) > bestAEdgeDot:
          bestAEdgeDot = abs(d)
          bestAEdge = i
      i.inc()
  block:
    var i = 0
    for edge in b.edges:
      if vertB[0] in edge:
        let d = dot(edge.normal, -collisionNormal)
        if abs(d) > bestBEdgeDot:
          bestBEdgeDot = abs(d)
          bestBEdge = i
      i.inc()

  a.highlightVertIndex = vertA[1]
  b.highlightVertIndex = vertB[1]

  a.highlightEdgeIndex = bestAEdge
  b.highlightEdgeIndex = bestBEdge

  var reference,incident: Line
  var refAdjacentA: Line
  var refAdjacentB: Line

  var flipped = false

  if bestAEdgeDot < bestBEdgeDot:
    reference = a.edge(bestAEdge)
    refAdjacentA = a.edge(bestAEdge-1)
    refAdjacentB = a.edge(bestAEdge+1)
    a.highlightColor = 12
    incident = b.edge(bestBEdge)
    b.highlightColor = 8
  else:
    reference = b.edge(bestBEdge)
    refAdjacentA = b.edge(bestBEdge-1)
    refAdjacentB = b.edge(bestBEdge+1)
    b.highlightColor = 12
    incident = a.edge(bestAEdge)
    a.highlightColor = 8
    flipped = true

  ## We now clip the incident with all the adjacent faces of the reference. This is done by taking the
  ## adjacent faces normal and any vertex that it contains to produce a plane equation.
  if flipped:
    incident = incident.clip(refAdjacentA)
    incident = incident.clip(refAdjacentB)
  else:
    incident = incident.clip(refAdjacentA)
    incident = incident.clip(refAdjacentB)

  result.clipEdge = incident

  # final clipping, remove points behind reference
  if incident[0].isLeftOf(reference):
    result.points[result.nPoints] = incident[0]
    result.nPoints += 1
  if incident[1].isLeftOf(reference):
    result.points[result.nPoints] = incident[1]
    result.nPoints += 1

proc sat(a,b: Object): (bool,Vec2f,float32) =
  ## return true if objects are overlapping, if overlapping returns the axis of min overlap
  var axisOfMinOverlap: Vec2f
  var minOverlap: float32 = Inf

  for axis in getAxes(a,b):
    var amin = Inf
    var bmin = Inf
    var amax = -Inf
    var bmax = -Inf

    # project each edge against the current axis
    for edge in a.edges:
      for p in edge:
        var v = dot(p,axis)
        if v < amin:
          amin = v
        if v > amax:
          amax = v
    for edge in b.edges:
      for p in edge:
        var v = dot(p,axis)
        if v < bmin:
          bmin = v
        if v > bmax:
          bmax = v

    if bmin > amax or amin > bmax:
      # found axis of separation, we can exit early
      result[0] = false
      return

    var overlap = 0f
    if amax > bmin:
      overlap = abs(bmin - amax)
    elif bmax > amin:
      overlap = abs(amin - bmax)

    if abs(overlap) < abs(minOverlap):
      minOverlap = overlap
      axisOfMinOverlap = axis

  return (true, axisOfMinOverlap, minOverlap)

proc addTorque(self: Object, torque: float32) =
  self.avel += torque / self.mass

proc addForceAtPos(self: Object, force: Vec2f, point: Vec2f) =
  self.vel += force / self.mass
  self.addTorque(cross(point - self.pos, force))

proc update(self: Object, dt: float32) =
  self.angle += self.avel * dt
  self.pos += self.vel * dt

  self.avel *= 0.9f
  self.vel *= 0.999f

proc draw(self: Object) =
  var i = 0
  for edge in self.edges:
    #if self.highlightEdgeIndex == i:
    #  setColor(self.highlightColor)
    #else:
    setColor(self.color)
    line(edge[0], edge[1])
    i.inc

  setColor(self.color)
  line(self.pos, self.pos + self.angle.angleToVec(10f))

  setColor(8)
  line(self.pos, self.pos + self.vel)

  #if self.highlightVertIndex >= 0:
  #  setColor(self.highlightColor)
  #  let p = self.point(self.highlightVertIndex)
  #  circfill(p.x, p.y, 2)


proc gameInit() =
  # we want a fixed sized screen with perfect square pixels
  fixedSize(true)
  integerScale(true)
  # create the window
  nico.createWindow("nico",128,128,4)

  objs = @[]
  objs.add(Object(color: 6, mass: 1f, pos: vec2f(20,64), rawPoints: @[vec2f(-16f, -16f), vec2f(16f, -16f), vec2f(16f, 16f), vec2f(-16f, 16f)]))
  objs.add(Object(color: 5, mass: 3f, pos: vec2f(82,64), rawPoints: @[vec2f(-32f, -16f), vec2f(16f, -16f), vec2f(16f, 16f), vec2f(-16f, 16f)]))
  objs.add(Object(color: 5, mass: 8f, pos: vec2f(0,100), rawPoints: @[vec2f(-32f, -16f), vec2f(16f, -16f), vec2f(16f, 16f), vec2f(-16f, 16f)]))

proc gameUpdate(dt: float32) =
  if btnp(pcStart):
    gameInit()
    return

  if btn(pcLeft):
    objs[0].addTorque(-30f * dt)
  if btn(pcRight):
    objs[0].addTorque(30f * dt)
  if btn(pcUp):
    objs[0].vel += objs[0].angle.angleToVec(36f) * dt
  if btn(pcDown):
    objs[0].vel -= objs[0].angle.angleToVec(36f) * dt

  for s in 0..<4:
    for obj in objs:
      obj.update(dt * 0.25f)

      obj.highlightVertIndex = -1
      obj.highlightEdgeIndex = -1

    for i in 0..<objs.len-1:
      for j in i+1..<objs.len:
        let hit = sat(objs[i], objs[j])
        if hit[0]:
          let cd = getContactData(objs[i], objs[j], hit[1], hit[2])

          # push them apart
          objs[i].pos -= hit[1] * (hit[2] * 0.5f)
          objs[j].pos += hit[1] * (hit[2] * 0.5f)

          if cd.nPoints == 1:
            objs[i].addForceAtPos(-hit[1] * hit[2] * 0.5f, cd.points[0])
            objs[j].addForceAtPos( hit[1] * hit[2] * 0.5f, cd.points[0])
          elif cd.nPoints == 2:
            objs[i].addForceAtPos(-hit[1] * hit[2] * 0.25f, cd.points[0])
            objs[i].addForceAtPos(-hit[1] * hit[2] * 0.25f, cd.points[1])
            objs[j].addForceAtPos( hit[1] * hit[2] * 0.25f, cd.points[0])
            objs[j].addForceAtPos( hit[1] * hit[2] * 0.25f, cd.points[1])

proc gameDraw() =
  cls()

  for i,obj in objs:
    obj.draw()
    if i == 0:
      setColor(7)
      print("A", obj.pos.x - 2, obj.pos.y - 4)
    elif i == 1:
      setColor(7)
      print("B", obj.pos.x - 2, obj.pos.y - 4)


  if overlapping:
    setColor(8)
    print("overlapping", 4, 4)

  if overlapping:
    setColor(8)
    line(objs[0].pos, objs[0].pos - overlapAxis * overlapAmount)
    setColor(11)
    line(overlapContactData.clipEdge[0], overlapContactData.clipEdge[1])

    for i in 0..<overlapContactData.nPoints:
      circfill(overlapContactData.points[i].x, overlapContactData.points[i].y, 3)


# initialization
nico.init("nico", "sat")

# start, say which functions to use for init, update and draw
nico.run(gameInit, gameUpdate, gameDraw)
