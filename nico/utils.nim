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

proc richPrintWidth*(text: string): int =
  var i = 0
  while i < text.len:
    let c = text[i]
    if c == '<' and i + 1 < text.len:
      # scan foward until '>'
      var k = i + 1
      if text[k] == '<':
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

proc richPrint*(text: string, x,y: int, align: TextAlign = taLeft, shadow: bool = false, step = -1) =
  ## prints but handles color codes <0>black <8>red etc <-> to return to normal

  var sx = x
  var x = x
  var y = y
  var wiggle = false

  let t = time()

  proc output(c: char, tlen: int) =
    if shadow:
      printShadow($c, x - (if align == taRight: tlen elif align == taCenter: tlen div 2 else: 0), y)
    else:
      print($c, x + (if wiggle: cos(x.float32 * 0.2 + t * 2.0) * 1.5 else: 0) - (if align == taRight: tlen elif align == taCenter: tlen div 2 else: 0), y + (if wiggle: sin(x.float32 + t * 8.0) * 2.0 else: 0))
    x += glyphWidth(c)

  var j = 0
  for text in text.split('\n'):
    let tlen = richPrintWidth(text)

    let startColor = getColor()

    #setColor(27)
    #if align == taCenter:
    #  rect(x - tlen div 2,y,x+tlen-1 - tlen div 2,y+fontHeight()-1)
    #else:
    #  rect(x,y,x+tlen-1,y+fontHeight()-1)
    #setColor(startColor)


    var i = 0
    while i < text.len:
      if step != -1 and j >= step:
        break

      let c = text[i]
      if c == '<':
        if i+1 < text.high and text[i+1] == '<':
          echo "found escaped <<"
          output(c, tlen)
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
        elif code == "s":
          wiggle = true
        elif code.startsWith("spr"):
          var sprId: int
          var (sw,sh) = spriteSize()
          if scanf(code, "spr($i,$i,$i)", sprId, sw, sh):
            spr(sprId, x - (if align == taCenter: tlen div 2 elif align == taRight: tlen else: 0), y)
            x += sw
          elif scanf(code, "spr($i)pal($i,$i)", sprId, palA, palB):
            let original = pal(palA)
            pal(palA, palB)
            spr(sprId, x - (if align == taCenter: tlen div 2 elif align == taRight: tlen else: 0), y)
            pal(palA, original)
            x += sw
          elif scanf(code, "spr($i)", sprId):
            spr(sprId, x - (if align == taCenter: tlen div 2 elif align == taRight: tlen else: 0), y)
            x += sw
        else:
          let col = try: parseInt(code) except ValueError: startColor
          setColor(col)
        i = k + 1
        continue
      output(c, tlen)
      i += 1
      if c != ' ':
        j += 1
    setColor(startColor)
    y += fontHeight()
    x = sx
