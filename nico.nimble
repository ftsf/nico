# Package

version       = "0.2.7"
author        = "Jez 'Impbox' Kabanov"
description   = "Nico Game Engine"
license       = "MIT"

# Dependencies

requires "nim >= 1.2.0"
requires "sdl2_nim >= 2.0.10.0"
requires "gifenc >= 0.1.0"
requires "webaudio >= 0.2.1"
requires "html5_canvas >= 0.1.0"
requires "ajax >= 0.1.0"
requires "nimPNG"

skipDirs = @["examples","tests","android"]
installDirs = @["exampleApp"]

bin = @["nicoboot","nicoSynth"]

task test, "run tests":
  exec "nim c -p:. -r tests/copymem.nim"
  exec "nim c -p:. -r tests/fonts.nim"
  exec "nim c -p:. -r tests/config.nim"
  exec "nim c -p:. -r tests/palette.nim"

task testjs, "compile tests with js backend":
  # test they compile with js backend, harder to test running
  exec "nim js -p:. tests/copymem.nim"
  exec "nim js -p:. tests/fonts.nim"
  exec "nim js -p:. tests/config.nim"
  exec "nim js -p:. tests/palette.nim"

task paintout, "compile paintout example":
  exec "nim c -p:. -d:debug examples/paintout.nim"
  exec "nim js -p:. -d:debug --lineTrace:on --stackTrace:on -o:examples/paintout.js examples/paintout.nim"

task platformer, "compile platformer example":
  exec "nim c -p:. -d:release --multimethods:on -o:examples/platformer examples/platformer.nim"
  exec "nim js -p:. -d:release --multimethods:on -o:examples/platformer.js examples/platformer.nim"

task audio, "compile audio example":
  exec "nim c -p:. -d:debug -o:examples/audio examples/audio.nim"
  exec "nim js -p:. -d:release -o:examples/audio.js examples/audio.nim"

task vertex, "compile vertex example":
  exec "nim c -p:. -d:debug -o:examples/vertex examples/vertex.nim"
  exec "nim js -p:. -d:release -o:examples/vertex.js examples/vertex.nim"

task gui, "compile gui example":
  exec "nim c -p:. -d:debug -o:examples/gui examples/gui.nim"
  exec "nim js -p:. -d:release -o:examples/gui.js examples/gui.nim"

task benchmark, "compile benchmark example":
  exec "nim c -p:. -d:release -d:danger -o:examples/benchmark examples/benchmark.nim"
  exec "nim js -p:. -d:release -d:danger -o:examples/benchmark.js examples/benchmark.nim"

task runbenchmark, "compile and run benchmark example":
  exec "nim c -r -p:. -d:release -d:danger -o:examples/benchmark examples/benchmark.nim"

task examples, "compile all examples":
  exec "nimble paintout"
  exec "nimble platformer"
  exec "nimble audio"
  exec "nimble vertex"
  exec "nimble gui"
  exec "nimble benchmark"

task runplatformer, "runs platformer":
  exec "nim c -r -p:. -d:release -o:examples/platformer examples/platformer.nim"
