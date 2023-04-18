import nico
import unicode, tables
import strutils, strformat
import nico/backends/common
import testfontdata

# QuanPixel | 全小素
# https://diaowinner.itch.io/galmuri-extended
# gb2312
type
  Font_cjk = tuple
    cw,ch,dw,dh: Pint
    idxw: Pint = 16
    idxh, idxlen: Pint
    maxw, maxh: Pint
    tabs = initTable[Rune, Pint]()
    spidx = 6
var ftcjk: Font_cjk

proc loadFontcjk(filename: string, w, h: Pint = 8; dw, dh: Pint = 0) =
  ftcjk.cw = w
  ftcjk.ch = h
  ftcjk.dw = dw
  ftcjk.dh = dh
  ftcjk.spidx = 6

  loadSpriteSheet(ftcjk.spidx, filename, w+dw, h+dh)
  setSpritesheet(ftcjk.spidx)
  ftcjk.maxw = spritesheet.w
  ftcjk.maxh = spritesheet.h
  ftcjk.idxw = 16
  ftcjk.idxh = ftcjk.maxh div h
  ftcjk.idxlen = runeLen(testchars)
  #ftcjk.idxlen = ftcjk.idxw * ftcjk.idxh
  echo &"rune len: {ftcjk.idxlen}"
  echo &"runelen() : {runeLen(testchars)}"
  echo ftcjk.repr
  var i = 0

  for rune in runes(testchars):
    ftcjk.tabs[rune] = i
    #echo &"rune = {rune}, idx = {i}"
    i.inc
  echo &"i = {i}"
  echo testchars.toRunes[10654..10660]

proc printcjk(text: string, x, y: Pint, scale = 1.0f32) =
  let ix = x
  var
    x = x
    y = y
    w = ftcjk.cw
    h = ftcjk.ch
    dw = ftcjk.dw
    dh = ftcjk.dh
    idx: Pint
    idxw = ftcjk.idxw
    #idxh = ftcjk.idxh
    sx, sy, dx, dy = 0
    ew = w + dw
    eh = h + dh
  var runonce {.global.} = false
  for line in text.splitLines:
    if not runonce:
      echo &"line={line}"
    for c in line.runes:
      idx = ftcjk.tabs[c]
      sx = idx mod idxw * ew
      sy = idx div idxw * eh
      dx = w
      dy = h
      if not runonce:
        echo &" c={c}, {idx} {sx} {sy} {dx} {dy}"
      sspr(sx, sy, dx, dy, x, y, w.Pfloat * scale, h.Pfloat * scale)
      if ((c.int32 < 128) or (idx > 18014 and idx < 18070)): x += (w shr 1 + 1).Pfloat * scale
      else: x += w.Pfloat * scale
    x = ix.Pfloat * scale
    y += h.Pfloat * scale
  runonce = true
  discard

proc gameInit =
  loadFontcjk("quan12x8.png", 8, 8, dw=4) # pw:8+4=12 ph:8

proc gameUpdate(dt: float32) =
  if keyp(K_ESCAPE): shutdown()
proc gameDraw =
  cls(3)
  setSpritesheet(ftcjk.spidx)
  #sspr(0, 20 * 8, 16 * 9, 16 * 8, 0, 0, screenWidth.float / 1.0, screenHeight.float / 1.0)
  printcjk("123456789,./\n !@#$^%&*-=;(){}\"\'", 0, 0)
  #printcjk("123456789,./\n !@#$^%&*-=;(){}\"\'", 0, 0, 1.3)
  printcjk("휄휌휍휏휐휑휘휙휜휟휠휨휩휫휭휴휵휸휺휻휼흃흄흅흇\n흉흍흐흑흔흕흖흗흘", 0, 20)
  printcjk("Ⓘⓔⓛⓞⓥ⓪⓫⓬⓭⓮⓯⓰⓱⓲⓳⓴", 0, 40)
  printcjk("我人有的和主产不为这工要在地一上是中国经以发了民同\n终于能输入中文了:)", 0, screenHeight div 2-10)
  printcjk("繁體字也都可以的哦, 大家快來試試吧", 0, screenHeight div 2 + 10)
  printcjk("ぁあぃいぅうぇえぉおかがきぎくぐけげこごさざしじすずせぜそぞた\nだちぢっつづてでとどなにぬねのはばぱひびぴふぶぷへべぺほぼぽま\nみむめもゃやゅゆょよらりるれろゎわゐゑをんゔゕゖ゙゚", 0, screenHeight div 2+20)
  printcjk("ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆ\nﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ", 0, screenHeight div 2+45)

nico.init("nico", "nico_test")
fixedSize(true)
integerScale(true)
nico.createWindow("nico test", 128, 128, 4, false)
nico.run(gameInit, gameUpdate, gameDraw)
