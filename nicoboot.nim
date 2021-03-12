# tool to set up a new nico project
import os
import osproc
import parseopt
import strutils

var params = initOptParser(commandLineParams(), shortNoVal = {'f'})

var targetPath: string = ""
var overwrite = false

for kind, key, val in getOpt(params):
  case kind:
    of cmdArgument:
      targetPath = key
    of cmdLongOption, cmdShortOption:
      case key:
        of "f": overwrite = true
    of cmdEnd:
      assert(false)

if targetPath == "":
  echo "nicoboot [-f] projectPath"
  quit(1)

# create a new project
let sourcePath = joinPath(getAppDir(), "exampleApp")
if overwrite == false and (dirExists(targetPath) or fileExists(targetPath) or symlinkExists(targetPath)):
  echo "not overwriting existing path: ", targetPath, " use -f to overwrite"
  quit(1)
echo "copying ", sourcePath, " to ", targetPath
copyDir(sourcePath, targetPath)
# search and replace

let 
  nimblePath = targetPath / (targetPath & ".nimble")
  mainFile = targetPath & ".nim"

echo "New main file: ", mainFile

# Make the nimble file with tasks to build the `targetPath.nim` file.
let nimbleFile = readFile(targetPath / "exampleApp.nimble")
nimblePath.writeFile nimbleFile.replace("main.nim", mainFile)
removeFile(targetPath / "exampleApp.nimble")

# Move the test to the main folder"
moveFile(targetPath / "src" / "main.nim", targetPath / "src" / mainFile)

echo execProcess("nimgrep", "", ["-!","exampleApp",targetPath,"-r",targetPath], nil, {poUsePath})
echo "nico project ", targetPath, " created"
quit(0)
