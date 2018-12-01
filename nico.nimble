# Package

version       = "0.1.0"
author        = "Jez Kabanov"
description   = "Nico Game Engine"
license       = "MIT"

# Dependencies

requires "nim >= 0.19.0"
requires "sdl2_nim >= 2.0.9.0"
requires "gifenc >= 0.1.0"
requires "webaudio >= 0.1.0"
requires "html5_canvas >= 0.1.0"
requires "ajax >= 0.1.0"
requires "sndfile >= 0.1.0"
requires "nimPNG#head"

skipDirs = @["examples","tests","android"]

task test, "run tests":
  exec "nim c -p:. -d:debug -r tests/copymem.nim"
  exec "nim c -p:. -d:debug -r tests/fonts.nim"
  exec "nim c -p:. -d:debug -r tests/config.nim"

task paintout, "compile paintout example":
  exec "nim c -p:. -d:debug examples/paintout.nim"
  exec "nim js -p:. -d:debug --lineTrace:on --stackTrace:on -o:examples/paintout.js examples/paintout.nim"

task platformer, "compile platformer example":
  exec "nim c -p:. -d:release --threads:off -o:examples/platformer examples/platformer.nim"
  exec "nim js -p:. -d:release -o:examples/platformer.js examples/platformer.nim"

task platformerthreads, "compile platformer example":
  exec "nim c -p:. -d:release --threads:on -o:examples/platformer examples/platformer.nim"
  exec "nim js -p:. -d:release -o:examples/platformer.js examples/platformer.nim"

task sfx, "compile sfx example":
  exec "nim c -p:. --threads:on -d:release -o:examples/sfx examples/sfx.nim"
  exec "nim js -p:. -d:release -o:examples/sfx.js examples/sfx.nim"

task sfxd, "compile sfx example":
  exec "nim c -p:. --threads:on -d:debug -o:examples/sfx examples/sfx.nim"
  exec "nim js -p:. -d:debug -o:examples/sfx.js examples/sfx.nim"


task audio, "compile audio example":
  exec "nim c -p:. --threads:on -d:debug -o:examples/audio examples/audio.nim"
  exec "nim js -p:. -d:release -o:examples/audio.js examples/audio.nim"

task examples, "compile all examples":
  exec "nimble paintout"
  exec "nimble platformer"
  exec "nimble audio"

task runplatformer, "runs platformer":
  exec "nim c -r -p:. -d:release -o:examples/platformer examples/platformer.nim"
