# Package

version       = "0.4.10"
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

import os
import strformat
import sugar

bin = @["nicoboot","nicoandroid","nicosynth"]

let tests = collect(newSeq):
  for file in listFiles("tests"):
    if file.endswith(".nim"): file

task test, "run tests":
  for file in tests:
    exec &"nim c -p:. -r {file}"

task docs, "Generate documentation":
  exec "nim doc -p:. --git.url:https://github.com/ftsf/nico --git.commit:main --project --outdir:docs nico.nim"
  exec "echo \"<meta http-equiv=\\\"Refresh\\\" content=\\\"0; url='nico.html'\\\" />\" >> docs/index.html"

task testemscripten, "compile tests with emscripten":
  # test they compile with emscripten backend, harder to test running
  for file in tests:
    exec &"nim c -d:emscripten -p:. {file}"

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

task guiweb, "compile gui example":
  exec "nim c -d:emscripten -p:. -o:examples/gui.js examples/gui2.nim"

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
