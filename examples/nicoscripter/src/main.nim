import nimscripter
import nimscripter/expose
import compiler/nimeval
import std/[options, os, times]

#import nicoscript
import nico

exportTo(nico,
  setColor,
  line,
  circ,
  circfill,
  rect,
  rectfill,
  cls,
  btn,
  sin,
  cos,
)

var
  intr: Option[Interpreter]
  lastModified: Time

const
  fileName = "assets/example.nims"
  codeImpls = implNimscriptModule(nico)
  stdlib = findNimStdlibCompileTime()

when defined(emscripten):
  proc reload*(script: cstring): cint {.exportc,cdecl.} =
    echo "reloading script..."
    echo script
    echo "..."
    intr = loadScript($script, codeImpls, isFile = false, modules = ["nicoscript"], stdPath = "assets/lib")
    echo "done"

    #if intr.isSome:
    #  intr.get.invoke(init)

    return 0

proc gameInit() =
  when defined(emscripten):
    intr = loadScript(fileName, codeImpls, modules = ["nicoscript"], stdPath = "assets/lib")

  #if intr.isSome:
  #  intr.get.invoke(init)

proc gameUpdate(dt: float32) =
  when not defined(emscripten):
    if lastModified < getLastModificationTime(fileName):
      intr = loadScript(fileName, codeImpls, modules = ["nicoscript"], stdPath = stdlib)
      lastModified = getLastModificationTime(fileName)

  #if intr.isSome:
  #  intr.get.invoke(update, dt)

proc gameDraw() =
  if intr.isSome:
    intr.get.invoke(draw)

nico.init("nico","test")
nico.createWindow("nico", 128, 128, 4, false)
nico.run(gameInit, gameUpdate, gameDraw)
