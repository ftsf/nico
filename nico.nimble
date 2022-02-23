# Package

version       = "0.4.9"
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

task testemscripten, "compile tests with emscripten":
  # test they compile with emscripten backend, harder to test running
  for file in tests:
    exec &"nim c -d:emscripten -p:. {file}"

let examples = collect(newSeq):
  for file in listFiles("examples"):
    if file.endswith(".nim"): file

task examples, "compile all examples":
  for file in examples:
    let output = file.changeFileExt("")
    exec &"nim c -p:. -d:release -d:danger -o:{output} {file}"

task examplesd, "compile all examples as debug":
  for file in examples:
    let output = file.changeFileExt("")
    exec &"nim c -p:. -d:debug -o:{output} {file}"

task nicosynth, "runs nicosynth":
  exec "nim c -r -p:. -d:release -o:tools/nicosynth tools/nicosynth.nim"

task nicosynthWeb, "builds nicosynth for web":
  exec "nim c -d:emscripten -p:. -d:release -o:tools/nicosynth.html tools/nicosynth.nim"
