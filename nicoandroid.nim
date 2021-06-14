import httpclient
import os
import osproc
import strutils
import zippy/ziparchives

if not dirExists("android"):
  if not fileExists("android.zip"):
    # download and extract nico android base
    let client = newHttpClient()
    client.downloadFile("https://www.impbox.net/nico/android.zip", "android.zip")

  createDir("tmp_android")
  extractAll("android.zip", "tmp_android/android")
  moveFile("tmp_android/android/android", "android")
  removeDir("tmp_android")

let dumpLines = execProcess("nim dump")
let lastLine = dumpLines.splitLines()[^2]
let nimbasePath = lastLine / "nimbase.h"
copyFile(nimbasePath, "android/app/jni/src/nimbase.h")
