# Package

version = "0.1.0"
author = "Your Name"
description = "exampleApp"
license = "?"

# Deps
requires "nim >= 1.2.0"
requires "nico >= 0.2.5"

srcDir = "src"

task runr, "Runs exampleApp for current platform":
 exec "nim c -r -d:release -o:exampleApp src/main.nim"

task rund, "Runs debug exampleApp for current platform":
 exec "nim c -r -d:debug -o:exampleApp src/main.nim"

task release, "Builds exampleApp for current platform":
 exec "nim c -d:release -o:exampleApp src/main.nim"

task debug, "Builds debug exampleApp for current platform":
 exec "nim c -d:debug -o:exampleApp_debug src/main.nim"

task web, "Builds exampleApp for current web":
 exec "nim js -d:release -o:exampleApp.js src/main.nim"

task webd, "Builds debug exampleApp for current web":
 exec "nim js -d:debug -o:exampleApp.js src/main.nim"

task deps, "Downloads dependencies":
 exec "curl https://www.libsdl.org/release/SDL2-2.0.12-win32-x64.zip -o SDL2_x64.zip"
 exec "unzip SDL2_x64.zip"
 #exec "curl https://www.libsdl.org/release/SDL2-2.0.12-win32-x86.zip -o SDL2_x86.zip"
