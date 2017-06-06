# Package

version       = "0.1.0"
author        = "Jez Kabanov"
description   = "Nico Game Engine"
license       = "MIT"

# Dependencies

requires "nim >= 0.16.0"
requires "sdl2_nim#head"
requires "gifenc >= 0.1.0"
requires "stb_image >= 1.3"
requires "webaudio >= 0.1.0"
requires "html5_canvas >= 0.1.0"
requires "ajax >= 0.1.0"

skipDirs = @["examples","tests"]

task test, "run tests":
  exec "nim c -p:. -d:debug -r tests/copymem.nim"
  exec "nim c -p:. -d:debug -r tests/fonts.nim"
  exec "nim c -p:. -d:debug -r tests/config.nim"

task paintout, "compile paintout example":
  exec "nim c -p:. -d:debug examples/paintout.nim"
  exec "nim js -p:. -d:debug --lineTrace:on --stackTrace:on -o:examples/paintout.js examples/paintout.nim"

task platformer, "compile platformer example":
  exec "nim c -p:. -d:release -o:examples/platformer examples/platformer.nim"
  exec "nim js -p:. -d:release -o:examples/platformer.js examples/platformer.nim"

task examples, "compile all examples":
  exec "nimble paintout"
  exec "nimble platformer"

task runplatformer, "runs platformer":
  exec "nim c -r -p:. -d:release -o:examples/platformer examples/platformer.nim"
