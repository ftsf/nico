# tool to set up a new nico project
import os
import osproc
import parseopt

var params = initOptParser(commandLineParams(), shortNoVal = {'f'})

var targetPath: string = ""
var orgName: string = ""
var appName: string = ""
var overwrite = false

var arg = 0

for kind, key, val in getOpt(params):
  case kind:
    of cmdArgument:
      if arg == 0:
        orgName = key
      elif arg == 1:
        appName = key
      elif arg == 2:
        targetPath = key
      arg.inc
    of cmdLongOption, cmdShortOption:
      case key:
        of "f": overwrite = true
    of cmdEnd:
      assert(false)

if targetPath == "":
  echo "nicoboot [-f] orgName appName projectPath"
  quit(1)

# create a new project
let sourcePath = joinPath(getAppDir(), "exampleApp")
if overwrite == false and (dirExists(targetPath) or fileExists(targetPath) or symlinkExists(targetPath)):
  echo "not overwriting existing path: ", targetPath, " use -f to overwrite"
  quit(1)
echo "copying ", sourcePath, " to ", targetPath
copyDir(sourcePath, targetPath)
# search and replace
moveFile(joinPath(targetPath, "exampleApp.nimble"), joinPath(targetPath, appName & ".nimble"))
echo execProcess("nimgrep", "", ["-!","exampleApp",appName,"-r",targetPath], nil, {poUsePath, poStdErrToStdOut})
echo execProcess("nimgrep", "", ["-!","exampleOrg",orgName,"-r",targetPath], nil, {poUsePath, poStdErrToStdOut})
echo "nico project ", appName, " created in ", targetPath
