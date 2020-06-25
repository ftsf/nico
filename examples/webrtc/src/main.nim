import nico
import nico/vec
import peerjs
import jsffi
import dom
import strutils
import strscans

var conn: DataConnection
var peer: Peer
var myID: string

const idPrefix = "nicoTest"
const idLen = 4

var remoteID: array[idLen, int]
var remoteIDindex: int

var frame: uint

var connecting = 0
var connected = false
var isHost = false

var playerPos: array[2, Vec2i]
var playerScores: array[2, int]
var playerId: range[0..1]

var ballPos: Vec2f
var ballVel: Vec2f

var paddleWidth = 16
var pauseTimer = 1.0'f
var ballSpeed: float32 = 0.5'f
var resetTimer = 0'f
var lastMessageTimer: int
var lastPingTimer: int

var charSet: seq[char]
for c in '0'..'9':
  charSet.add(c)

proc overlap(ax,ay,aw,ah, bx,by,bw,bh: Pint): bool =
  let aminx = ax
  let amaxx = ax + aw - 1
  let aminy = ay
  let amaxy = ay + ah - 1

  let bminx = bx
  let bmaxx = bx + bw - 1
  let bminy = by
  let bmaxy = by + bh - 1
  return not (aminx >= bmaxx or amaxx <= bminx or aminy >= bmaxy or amaxy <= bminy)

proc drawPaddle(x,y,w,h,c: int) =
  setColor(c)
  circfill(x - w div 2 + 2, y, 2)
  circfill(x + w div 2 - 2, y, 2)
  boxfill(x - w div 2 + 2, y - h div 2, w - 4, h)

proc handleData(d: string) =
  var i: int
  var pid, score: int
  if scanf(d, "bx:$i", i):
    ballPos.x = i.float32
  elif scanf(d, "by:$i", i):
    ballPos.y = i.float32
  elif scanf(d, "p:$i", i):
    playerPos[wrap(playerId + 1, 2)].x = i
  elif scanf(d, "stop"):
    pauseTimer = 1'f
    resetTimer = 1'f
  elif scanf(d, "start"):
    pauseTimer = 0'f
    resetTimer = 0'f
  elif scanf(d, "score:$i:$i", pid, score):
    playerScores[pid] = score
  lastMessageTimer = 0

proc resetBall() =
  ballPos = vec2f(64,64)
  ballVel = vec2f(rnd(-1'f,1'f), rnd([-1'f,1'f]))
  ballVel = ballVel.clamp(ballSpeed)
  ballSpeed = 1.0'f
  conn.send("stop")
  conn.send("bx:" & $ballPos.x.int)
  conn.send("by:" & $ballPos.y.int)

proc gameInit() =
  srand()
  loadFont(0, "font.png")

  myID = ""
  for i in 0..<idLen:
    myID &= rnd(charSet)
  peer = newPeer(idPrefix & myID, PeerOptions(debug: 1))
  peer.on("disconnected") do(data: JsObject):
    echo "disconnected"
    connected = false
    connecting = 0
    peer.reconnect()
  peer.on("connection", proc(data: JsObject) =
    conn = cast[DataConnection](data)
    var peerStr = $(conn.peer)
    peerStr = peerStr.substr(idPrefix.len.int, idPrefix.len.int + idLen.int)
    echo "got incoming connection from ", peerStr
    for i in 0..<idLen:
      let ch = charSet.find(peerStr[i])
      if ch != -1:
        remoteID[i] = ch
    connected = true
    connecting = 0
    lastMessageTimer = 0

    conn.on("data", proc(data: cstring) =
      handleData($data)
    )
    playerId = 0
    isHost = true
    resetBall()
    resetTimer = 1.0'f
    setWindowTitle("nicoTest " & myID & " - host")
  )

  playerPos[0].x = screenWidth div 2
  playerPos[0].y = 8
  playerPos[1].x = screenWidth div 2
  playerPos[1].y = screenHeight - 9

  setWindowTitle("nicoTest " & myID)

proc gameUpdate(dt: float32) =
  if connecting > 0:
    connecting -= 1
    if connecting == 0:
      connected = false
    return

  if not connected:
    # remote id entry
    if btnpr(pcLeft):
      remoteIDindex -= 1
    if btnpr(pcRight):
      remoteIDindex += 1
    remoteIDindex = wrap(remoteIDindex, remoteID.len)
    if btnpr(pcDown):
      remoteID[remoteIDindex].dec()
      if remoteID[remoteIDindex] < charSet.low:
        remoteID[remoteIDindex] = charSet.high
    if btnpr(pcUp):
      remoteID[remoteIDindex].inc()
      if remoteID[remoteIDindex] > charSet.high:
        remoteID[remoteIDindex] = charSet.low
    if btnp(pcA):
      connecting = 60
      var remoteIDtext: string
      for i,c in remoteID:
        remoteIDtext.add(charSet[c])
      conn = peer.connect(idPrefix & remoteIDtext)
      conn.on("open", proc(data: cstring) =
        echo "connected"
        setWindowTitle("nicoTest " & myID & " - client")
        connected = true
        connecting = 0
        playerId = 1
        conn.on("data", proc(data: cstring) =
          handleData($data)
        )
        lastMessageTimer = 0
      )
  elif connected:
    lastMessageTimer += 1
    if lastMessageTimer > 120:
      connected = false
      #peer.reconnect()

    if not isHost:
      lastPingTimer += 1
      if lastPingTimer > 60:
        conn.send("ping")

    var dirty = false
    if btn(pcLeft):
      playerPos[playerId].x -= 1
      dirty = true
    if btn(pcRight):
      playerPos[playerId].x += 1
      dirty = true

    playerPos[playerId].x = clamp(playerPos[playerId].x, paddleWidth div 2, screenWidth - paddleWidth div 2)

    if dirty:
      conn.send("p:" & $playerPos[playerId].x)

    if isHost:
      if pauseTimer > 0:
        pauseTimer -= dt
        if pauseTimer <= 0:
          resetBall()
          resetTimer = 1.0'f

      if resetTimer > 0:
        resetTimer -= dt
        if resetTimer <= 0:
          conn.send("start")

      var lastPos = ballPos.vec2i

      playerPos[0].x = clamp(playerPos[0].x, paddleWidth div 2, screenWidth - paddleWidth div 2)
      playerPos[1].x = clamp(playerPos[1].x, paddleWidth div 2, screenWidth - paddleWidth div 2)

      if pauseTimer <= 0 and resetTimer <= 0:
        ballPos += ballVel

        if ballPos.x < 2 and ballVel.x < 0:
          ballPos.x = 2
          ballVel.x = -ballVel.x
        if ballPos.x > screenWidth - 2 and ballVel.x > 0:
          ballPos.x = (screenWidth - 2).float32
          ballVel.x = -ballVel.x

        if overlap(ballPos.x - 2, ballPos.y - 2, 4, 4, playerPos[0].x - paddleWidth div 2, playerPos[0].y - 3, paddleWidth, 5):
          if ballVel.y < 0:
            ballVel.y = -ballVel.y
            ballPos.y = playerPos[0].y.float32 + 4.0'f
          let relx = (ballPos.x - playerPos[0].x).float32
          if abs(relx) >= paddleWidth:
            ballVel.x += relx * 0.25'f
            ballVel = ballVel.clamp(ballSpeed)

          ballVel *= 2.0'f
          ballSpeed *= 1.1'f
          ballVel = ballVel.clamp(ballSpeed)

        if overlap(ballPos.x - 2, ballPos.y - 2, 4, 4, playerPos[1].x - paddleWidth div 2, playerPos[1].y - 3, paddleWidth, 5):
          if ballVel.y > 0:
            ballVel.y = -ballVel.y
            ballPos.y = playerPos[1].y.float32 - 4.0'f
          let relx = (ballPos.x - playerPos[1].x).float32
          if abs(relx) >= paddleWidth:
            ballVel.x += relx * 0.25'f
            ballVel = ballVel.clamp(ballSpeed)

          ballVel *= 2.0'f
          ballSpeed *= 1.1'f
          ballVel = ballVel.clamp(ballSpeed)

        if ballPos.y < 2 and ballVel.y < 0:
          playerScores[1] += 1
          conn.send("score:0:" & $playerScores[0])
          conn.send("score:1:" & $playerScores[1])
          pauseTimer = 1'f
          conn.send("stop")

        if ballPos.y > screenHeight - 2 and ballVel.y > 0:
          playerScores[0] += 1
          conn.send("score:0:" & $playerScores[0])
          conn.send("score:1:" & $playerScores[1])
          pauseTimer = 1'f
          conn.send("stop")

      var nextPos = ballPos.vec2i
      if lastPos != nextPos:
        conn.send("bx:" & $nextPos.x)
        conn.send("by:" & $nextPos.y)

proc gameDraw() =
  frame.inc()
  cls()
  setColor(7)
  if not connected and connecting == 0:
    var y = 32
    print("local id:", screenWidth div 2, y)
    y += 12
    print(myID, screenWidth div 2, y, 2)
    y += 24

    setColor(8)
    print("remote id:", screenWidth div 2, y)
    y += 12
    var remoteIDtext: string
    for i,c in remoteID:
      remoteIDtext.add(charSet[c])

    for i,c in remoteIDtext:
      if not connected:
        setColor(if i == remoteIDindex: 8 else: 5)
      glyph(c, screenWidth div 2 + i * 8, y, 2)

    y += 24

    setColor(5)
    print("enter your friend's\nlocal id with arrows\npress Z to connect", 4, y)

  if connecting > 0:
    printc("connecting...", screenWidth div 2, screenHeight - 12)

  if connected:
    setColor(1)
    rectfill(0,0,screenWidth-1,3)
    setColor(3)
    rectfill(0,screenHeight-4,screenWidth-1,screenHeight-1)

    var topPos = 8
    var bottomPos = screenHeight - 9

    drawPaddle(playerPos[0].x, playerPos[0].y, paddleWidth, 5, 11)
    drawPaddle(playerPos[1].x, playerPos[1].y, paddleWidth, 5, 12)

    setColor(if (pauseTimer > 0 or resetTimer > 0) and frame mod 10 < 5: 1 else: 7)
    circfill(ballPos.x, ballPos.y, 2)

    if pauseTimer > 0 or resetTimer > 0:
      setColor(11)
      printc($playerScores[0], screenWidth div 2, screenHeight div 2 - 32)
      setColor(12)
      printc($playerScores[1], screenWidth div 2, screenHeight div 2 + 32)

nico.init("myOrg", "myApp")
nico.fixedSize(true)
nico.integerScale(true)
nico.createWindow("myApp", 128, 128, 4, false)
nico.run(gameInit, gameUpdate, gameDraw)
