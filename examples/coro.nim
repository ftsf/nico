import nico
import sequtils

nico.init("nico","coroutines")

var num = 0

var coroutines: seq[iterator: void]

template coroutine(body: untyped): untyped =
  let c = iterator =
    body
  coroutines.add(c)

proc gameInit() =
  num = 0

proc gameUpdate(dt: float32) =
  if btnp(pcA):
    echo "adding coroutine"
    coroutine:
      for i in 0..<100:
        num += 1
        yield
      echo "coroutine finished"

  for c in coroutines:
    c()
  coroutines.keepItIf(it.finished() == false)

proc gameDraw() =
  cls()

  setColor(7)
  print("num: " & $num, 4, 4)

nico.createWindow("coroutines", 128, 128, 3)

nico.run(gameInit, gameUpdate, gameDraw)
