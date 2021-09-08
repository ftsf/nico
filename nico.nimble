# Package

version       = "0.4.4"
author        = "Jez 'Impbox' Kabanov"
description   = "Nico Game Engine"
license       = "MIT"

# Dependencies

requires "nim >= 1.4.0"
requires "sdl2_nim >= 2.0.14.2"
requires "gifenc >= 0.1.0"
requires "nimPNG >= 0.3.1"
requires "zippy >= 0.5.9"

skipDirs = @["examples","tests","android","tools"]
installDirs = @["exampleApp"]
installExt = @["nim"]

bin = @["nicoboot","nicoandroid","nicosynth"]

task test, "run tests":
  exec "nim c -p:. -r tests/rgba.nim"
  exec "nim c -p:. -r tests/copymem.nim"
  exec "nim c -p:. -r tests/fonts.nim"
  exec "nim c -p:. -r tests/config.nim"
  exec "nim c -p:. -r tests/palette.nim"
  exec "nim c -p:. -r tests/tilemap.nim"

task testemscripten, "compile tests with emscripten":
  # test they compile with emscripten backend, harder to test running
  exec "nim c -d:emscripten -p:. tests/rgba.nim"
  exec "nim c -d:emscripten -p:. tests/copymem.nim"
  exec "nim c -d:emscripten -p:. tests/fonts.nim"
  exec "nim c -d:emscripten -p:. tests/config.nim"
  exec "nim c -d:emscripten -p:. tests/palette.nim"
  exec "nim c -d:emscripten -p:. tests/tilemap.nim"

task paintout, "compile paintout example":
  exec "nim c -p:. -d:debug examples/paintout.nim"

task platformer, "compile platformer example":
  exec "nim c -p:. -d:release --multimethods:on -o:examples/platformer examples/platformer.nim"

task audio, "compile audio example":
  exec "nim c -p:. -d:debug -o:examples/audio examples/audio.nim"

task vertex, "compile vertex example":
  exec "nim c -p:. -d:debug -o:examples/vertex examples/vertex.nim"

task gui, "compile gui example":
  exec "nim c -p:. -d:debug -o:examples/gui examples/gui.nim"

task coro, "compile coro example":
  exec "nim c -p:. -d:debug -o:examples/gui examples/coro.nim"

task benchmark, "compile benchmark example":
  exec "nim c -p:. -d:release -d:danger -o:examples/benchmark examples/benchmark.nim"

task tweaker, "compile tweaker example":
  exec "nim c -p:. -d:release -d:danger -o:examples/tweaker examples/tweaker.nim"

task examples, "compile all examples":
  exec "nimble paintout"
  exec "nimble platformer"
  exec "nimble audio"
  exec "nimble vertex"
  exec "nimble gui"
  exec "nimble benchmark"
  exec "nimble coro"
  exec "nimble tweaks"

task nicosynth, "runs nicosynth":
  exec "nim c -r -p:. -d:release -o:tools/nicosynth tools/nicosynth.nim"

task nicosynthWeb, "builds nicosynth for web":
  exec "nim c -d:emscripten -p:. -d:release -o:tools/nicosynth.html tools/nicosynth.nim"
