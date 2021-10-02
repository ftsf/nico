import nico
import strutils
import strscans

type TextAlign* = enum
  taLeft
  taRight
  taCenter

var outlineColor: int = 0

proc setOutlineColor*(oc: int) =
  outlineColor = oc

proc printOutlineC*(text: string, x, y: cint, scale: cint = 1) =
  let oldColor = getColor()
  setColor(outlineColor)
  printc(text, x-scale, y, scale)
  printc(text, x+scale, y, scale)
  printc(text, x, y-scale, scale)
  printc(text, x, y+scale, scale)
  printc(text, x+scale, y+scale, scale)
  printc(text, x-scale, y-scale, scale)
  printc(text, x+scale, y-scale, scale)
  printc(text, x-scale, y+scale, scale)
  setColor(oldColor)
  printc(text, x, y, scale)

proc printOutlineR*(text: string, x, y: cint, scale: cint = 1) =
  let oldColor = getColor()
  setColor(outlineColor)
  printr(text, x-scale, y, scale)
  printr(text, x+scale, y, scale)
  printr(text, x, y-scale, scale)
  printr(text, x, y+scale, scale)
  printr(text, x+scale, y+scale, scale)
  printr(text, x-scale, y-scale, scale)
  printr(text, x+scale, y-scale, scale)
  printr(text, x-scale, y+scale, scale)
  setColor(oldColor)
  printr(text, x, y, scale)

proc printOutline*(text: string, x, y: cint, scale: cint = 1) =
  let oldColor = getColor()
  setColor(outlineColor)
  print(text, x-scale, y, scale)
  print(text, x+scale, y, scale)
  print(text, x, y-scale, scale)
  print(text, x, y+scale, scale)
  print(text, x+scale, y+scale, scale)
  print(text, x-scale, y-scale, scale)
  print(text, x+scale, y-scale, scale)
  print(text, x-scale, y+scale, scale)
  setColor(oldColor)
  print(text, x, y, scale)

proc printShadow*(text: string, x, y: cint, scale: cint = 1) =
  let oldColor = getColor()
  setColor(0)
  print(text, x-scale, y, scale)
  setColor(oldColor)
  print(text, x, y, scale)

proc richPrintWidthOneLine*(text: string, startChar = 0, endChar = -1): int =
  var i = startChar
  var endChar = if endChar == -1: text.high else: endChar
  while i < min(text.len,endChar+1):
    let c = text[i]
    if c == '<' and i + 1 < text.len:
      # scan foward until '>'
      var k = i + 1
      if text[k] == '<': # << = just print <
        result += glyphWidth(c)
        continue

      while k < text.len:
        if text[k] == '>':
          break
        k += 1

      let code = text[i+1..k-1]
      if code.startsWith("spr"):
        var sprId, palA, palB: int
        var (sw,sh) = spriteSize()
        if scanf(code, "spr($i,$i,$i)", sprId, sw, sh) or 
          scanf(code, "spr($i)pal($i,$i)", sprId, palA, palB) or
          scanf(code, "spr($i)", sprId):
          result += sw
      i = k + 1
      continue

    i += 1
    result += glyphWidth(c)

proc richPrintWidth*(text: string, start = 0): int =
  var maxWidth = 0
  for text in text.split('\n'):
    let width = richPrintWidthOneLine(text)
    if width > maxWidth:
      maxWidth = width
  return maxWidth

proc richPrintCount*(text: string): int =
  var i = 0
  while i < text.len:
    let c = text[i]
    if c == '<':
      # scan foward until '>'
      var k = i + 1
      if text[k] == '<':
        result += glyphWidth(c)
        continue
      while k < text.len:
        if text[k] == '>':
          break
        k += 1
      i = k + 1
      continue
    i += 1
    result += 1

var lastPrintedChar = '\0'

proc richPrintLastPrintedChar*(): char =
  return lastPrintedChar

proc richPrintOneLine*(text: string, x,y: int, align: TextAlign = taLeft, shadow = false, outline = false, startColor = 7, step = -1): int {.discardable.} =
  ## prints but handles color codes <0>black <8>red etc <-> to return to normal
  ## returns the number of chars printed
  result = 0

  if step == 0:
    return 0

  lastPrintedChar = '\0'

  var sx = x
  var x = x
  var y = y
  var wiggle = false
  var wiggleSpeed = 2.0
  var wiggleAmount = 2.0

  let t = time()

  var tlen = 0
  if align != taLeft:
    tlen = richPrintWidth(text)

  proc output(c: char, tlen: int) =
    if shadow:
      printShadow($c, x - (if align == taRight: tlen elif align == taCenter: tlen div 2 else: 0), y)
    elif outline:
      printOutline($c, x - (if align == taRight: tlen elif align == taCenter: tlen div 2 else: 0), y)
    else:
      print($c, x + (if wiggle: cos(x.float32 * 0.5421f + t * wiggleSpeed) * wiggleAmount.float32 else: 0).int - (if align == taRight: tlen elif align == taCenter: tlen div 2 else: 0).int, y + (if wiggle: sin(x.float32 * 0.234f + t * wiggleSpeed.float32 * 1.123f) * wiggleAmount.float32 else: 0f).int)
    lastPrintedChar = c
    x += glyphWidth(c)

  let hfh = fontHeight() div 2

  var i = 0
  while i < text.len:
    if step != -1 and result >= step:
      break

    let c = text[i]

    if c == '<':
      if i+1 < text.high and text[i+1] == '<':
        output(c, tlen)
        result += 1
        i += 2
        continue
      var k = i + 1
      while k < text.len:
        if text[k] == '>':
          break
        k += 1
      let code = text[i+1..k-1]
      if code == "/":
        setColor(startColor)
        wiggle = false
      elif scanf(code, "s($f,$f)", wiggleSpeed, wiggleAmount):
        wiggle = true
      elif scanf(code, "s($f)", wiggleSpeed):
        wiggle = true
      elif code == "s":
        wiggleSpeed = 2f
        wiggle = true
      elif code.startsWith("spr"):
        var sprId, palA, palB: int
        var (sw,sh) = spriteSize()
        if scanf(code, "spr($i,$i,$i)", sprId, sw, sh):
          spr(sprId, x - (if align == taCenter: tlen div 2 elif align == taRight: tlen else: 0), y - sh div 2 + hfh)
          x += sw
        elif scanf(code, "spr($i)pal($i,$i)", sprId, palA, palB):
          let original = pal(palA)
          pal(palA, palB)
          spr(sprId, x - (if align == taCenter: tlen div 2 elif align == taRight: tlen else: 0), y - sh div 2 + hfh)
          pal(palA, original)
          x += sw
        elif scanf(code, "spr($i)", sprId):
          spr(sprId, x - (if align == taCenter: tlen div 2 elif align == taRight: tlen else: 0), y - sh div 2 + hfh)
          x += sw
      else:
        let col = try: parseInt(code) except ValueError: startColor
        setColor(col)
      i = k + 1
      continue

    output(c, tlen)
    result += 1
    i += 1
  y += fontHeight()
  x = sx


proc richPrint*(text: string, x,y: int, align: TextAlign = taLeft, shadow = false, outline = false, step = -1) =
  ## prints but handles color codes <0>black <8>red etc <-> to return to normal
  var charCount = 0
  var step = step
  var y = y
  var startColor = getColor()
  for text in text.split('\n'):
    charCount = richPrintOneLine(text, x,y, align, shadow, outline, startColor, step)
    if step != -1:
      step -= charCount
    y += fontHeight()
  setColor(startColor)

proc richWrapLines*(text: string, width: int): seq[string] =
  ## returns a list of strings with text split to fit on lines of width
  var linesToProcess = text.split('\n')
  var currentLine = 0
  while currentLine < linesToProcess.len:
    var line = linesToProcess[currentLine]
    var w = richPrintWidth(line)
    if w <= width:
      result.add(line)
      currentLine += 1
    else:
      # line is too long, we need to split it
      # find all split chars in text and find the split that gives us the highest w under width
      var i = line.high
      var foundSplit = false
      while i > 0:
        let c = line[i]
        if c in [' ', '-']:
          w = richPrintWidthOneLine(line, 0, i)
          if w <= width:
            result.add(line[0..<i])
            foundSplit = true
            # add the remainder to the lines to process
            linesToProcess[currentLine] = line[i+1..line.high]
            break
        i -= 1
      if not foundSplit:
        # TODO: no good place to split it, just cut the last word
        result.add(line)
        currentLine += 1

proc richPrintWidthWrapped*(text: string, maxWidth: int): int =
  let lines = richWrapLines(text, maxWidth)
  var maxWidth = 0
  for line in lines:
    let width = richPrintWidthOneLine(line)
    if width > maxWidth:
      maxWidth = width
  return maxWidth

proc richPrintWrap*(text: string, x,y,w: int, align: TextAlign = taLeft, shadow = false, outline = false, step = -1) =
  var y = y
  var step = step
  var i = 0
  var startColor = getColor()
  for line in richWrapLines(text, w):
    let stepsPrinted = richPrintOneLine(line, x,y, align, shadow, outline, startColor, step)
    if step != -1:
      step -= stepsPrinted
    y += fontHeight()
    i += 1
  setColor(startColor)
