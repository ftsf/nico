# Package

version = "0.1.0"
author = "exampleOrg"
description = "exampleApp"
license = "?"

# Deps
requires "nim >= 1.2.0"
requires "nico >= 0.2.5"

srcDir = "src"

import strformat

const releaseOpts = "-d:danger"
const debugOpts = "-d:debug"

task runr, "Runs exampleApp for current platform":
 exec &"nim c -r {releaseOpts} -o:exampleApp src/main.nim"

task rund, "Runs debug exampleApp for current platform":
 exec &"nim c -r {debugOpts} -o:exampleApp src/main.nim"

task release, "Builds exampleApp for current platform":
 exec &"nim c {releaseOpts} -o:exampleApp src/main.nim"

task webd, "Builds debug exampleApp for web":
 exec &"nim c {debugOpts} -d:emscripten -o:exampleApp.html src/main.nim"

task webr, "Builds release exampleApp for web":
 exec &"nim c {releaseOpts} -d:emscripten -o:exampleApp.html src/main.nim"

task debug, "Builds debug exampleApp for current platform":
 exec &"nim c {debugOpts} -o:exampleApp_debug src/main.nim"

task deps, "Downloads dependencies":
 if defined(windows):
  if not fileExists("SDL2.dll"):
   if not fileExists("SDL2_x64.zip"):
    exec "curl https://www.libsdl.org/release/SDL2-2.0.20-win32-x64.zip -o SDL2_x64.zip"
   if findExe("tar") != "":
    exec "tar -xf SDL2_x64.zip SDL2.dll"
   else:
    exec "unzip SDL2_x64.zip SDL2.dll"
  if fileExists("SDL2_x64.zip"):
   rmFile("SDL2_x64.zip")
 elif defined(macosx) and findExe("brew") != "":
  exec "brew list sdl2 || brew install sdl2"
 else:
  echo "I don't know how to install SDL on your OS! 😿"

task androidr, "Release build for android":
  if defined(windows):
    exec &"nicoandroid.cmd"
  else:
    exec &"nicoandroid"
  exec &"nim c -c --nimcache:android/app/jni/src/armeabi {releaseOpts}  --cpu:arm   --os:android -d:androidNDK --noMain --genScript src/main.nim"
  exec &"nim c -c --nimcache:android/app/jni/src/arm64   {releaseOpts}  --cpu:arm64 --os:android -d:androidNDK --noMain --genScript src/main.nim"
  exec &"nim c -c --nimcache:android/app/jni/src/x86     {releaseOpts}  --cpu:i386  --os:android -d:androidNDK --noMain --genScript src/main.nim"
  exec &"nim c -c --nimcache:android/app/jni/src/x86_64  {releaseOpts}  --cpu:amd64 --os:android -d:androidNDK --noMain --genScript src/main.nim"
  withDir "android":
    if defined(windows):
      exec &"gradlew.bat assembleDebug"
    else:
      exec "./gradlew assembleDebug"
