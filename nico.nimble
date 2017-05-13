# Package

version       = "0.1.0"
author        = "Jez Kabanov"
description   = "Nico Game Engine"
license       = "MIT"

# Dependencies

requires "nim >= 0.16.0"
requires "sdl2 >= 1.1"
requires "gifenc >= 0.1.0"

skipDirs = @["examples","tests"]

task test, "run tests":
  exec "nim c --path:. -d:debug -r tests/copymem.nim"
  exec "nim c --path:. -d:debug -r tests/fonts.nim"
