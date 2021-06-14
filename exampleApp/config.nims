when defined(emscripten):
  import std/compilesettings
  import strformat

  # This path will only run if -d:emscripten is passed to nim.
  --nimcache:tmp # Store intermediate files close by in the ./tmp dir.

  --os:linux # Emscripten pretends to be linux.
  --cpu:wasm32 # Emscripten is 32bits.
  --cc:clang # Emscripten is very close to clang, so we ill replace it.
  when defined(windows):
    --clang.exe:emcc.bat  # Replace C
    --clang.linkerexe:emcc.bat # Replace C linker
    --clang.cpp.exe:emcc.bat # Replace C++
    --clang.cpp.linkerexe:emcc.bat # Replace C++ linker.
  else:
    --clang.exe:emcc  # Replace C
    --clang.linkerexe:emcc # Replace C linker
    --clang.cpp.exe:emcc # Replace C++
    --clang.cpp.linkerexe:emcc # Replace C++ linker.
  --listCmd # List what commands we are running so that we can debug them.

  --gc:orc # GC:arc is friendlier with crazy platforms.
  --exceptions:goto # Goto exceptions are friendlier with crazy platforms.
  --define:noSignalHandler # Emscripten doesn't support signal handlers.

  --dynlibOverride:SDL2

  when defined(opengl):
    --dynlibOverride:opengl

  --define:emscripten

  # Pass this to Emscripten linker to generate html file scaffold for us.
  const projName = projectName()
  const userSetOutFile = querySetting(SingleValueSetting.outFile)
  const outFile = if userSetOutFile == "": &"{projName}.html" else: userSetOutFile
  when defined(debug):
    switch("passL", &"-o {outFile} --shell-file nico_minimal.html -lidbfs.js -s ASSERTIONS=1 -s USE_SDL=2 -s FORCE_FILESYSTEM=1 -s ALLOW_MEMORY_GROWTH -s EXPORTED_FUNCTIONS=[\"_main\",\"_initConfigDone\"] -s EXPORTED_RUNTIME_METHODS=[\"ccall\",\"cwrap\"] -O0 --preload-file assets")
  else:
    switch("passL", &"-o {outFile} --shell-file nico_minimal.html -lidbfs.js -s ASSERTIONS=1 -s USE_SDL=2 -s FORCE_FILESYSTEM=1 -s ALLOW_MEMORY_GROWTH -s EXPORTED_FUNCTIONS=[\"_main\",\"_initConfigDone\"] -s EXPORTED_RUNTIME_METHODS=[\"ccall\",\"cwrap\"] -O3 --preload-file assets")
