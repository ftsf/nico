import std/[json, tables, strutils]
import std/os except `/`
import nico
import nico/console
import nico/gui2
import nico/vec

type
  TweakKind = enum
    TweakFloat
    TweakInt
    TweakBool
  Tweak = object
    case kind: TweakKind
    of TweakFloat:
      f: ptr float32
      fmin,fmax: float32
      fdefault: float32
      fsaved: float32
    of TweakInt:
      i: ptr int
      imin,imax: int
      idefault: int
      isaved: int
    of TweakBool:
      b: ptr bool
      bdefault: bool
      bsaved: bool

var tweakTable = newOrderedTable[string,Tweak]()
var tweakCategory: string = ""

proc `/`(a,b: string): string =
  if a.len == 0:
    return b
  result = a
  result.add "/"
  result.add b

proc addTweak*[T: int or float32 or bool](name: string, v: var T, rng: Slice[T] = T.low .. T.high) =
  tweakTable[tweakCategory / name] =
    when T is int:
      echo "addTweakInt: ", name, " = ", v
      Tweak(kind: TweakInt, i: v.addr, imin: rng.a, imax: rng.b, idefault: v, isaved: v)
    elif T is float32:
      echo "addTweakFloat: ", name, " = ", v
      Tweak(kind: TweakFloat, f: v.addr, fmin: rng.a, fmax: rng.b, fdefault: v, fsaved: v)
    else:
      echo "addTweakBool: ", name, " = ", v
      Tweak(kind: TweakBool, b: v.addr, bdefault: v, bsaved: v)


template editRange*(bounds: untyped) {.pragma.}

proc `$`*(self: Tweak): string =
  case self.kind:
  of TweakFloat:
    return $self.f[]
  of TweakInt:
    return $self.i[]
  of TweakBool:
    return $self.b[]

proc getTweakPresets*(): seq[string] =
  for file in walkPattern("assets/tweaks*.json"):
    result.add(file.extractFilename().changeFileExt(""))

proc reloadTweaks*(name: string = "tweaks") =
  try:
    var j = readJsonFile("assets/" & name & ".json")
    for k,v in j.pairs():
      if k in tweakTable:
        let tweak = tweakTable[k]
        echo "tweak: '", k, "' = ", $tweak, " => ", v
        case tweak.kind:
        of TweakFloat:
          tweak.f[] = v.getFloat
          tweakTable[k].fsaved = v.getFloat
        of TweakInt:
          tweak.i[] = v.getInt
          tweakTable[k].isaved = v.getInt
        of TweakBool:
          tweak.b[] = v.getBool
          tweakTable[k].bsaved = v.getBool
      else:
        echo "unregistered tweak: ", k
    echo "reloaded tweaks"
  except Exception as e:
    echo "error loading tweaks ", e.msg
    return

proc saveTweaks*(name = "tweaks") =
  try:
    var j = newJObject()
    for k,v in tweakTable:
      case v.kind:
      of TweakFloat:
        j[k] = %* v.f[]
      of TweakInt:
        j[k] = %* v.i[]
      of TweakBool:
        j[k] = %* v.b[]
    saveJsonFile("assets/" & name & ".json", j)
    reloadTweaks(name)
    echo "saved tweaks"
  except:
    echo "error saving tweaks"

template tweaks*(category: string, body: typed): untyped =
  let startCat = tweakCategory
  tweakCategory = tweakCategory / category
  body
  tweakCategory = startCat

template tweak*(x: untyped, v: float32, rng = float32.low .. float32.high): untyped =
  var x: float32 = v
  addTweak(x.astToStr, x, rng)

template tweak*(x: untyped, v: int, rng = int.low .. int.high): untyped =
  var x: int = v
  addTweak(x.astToStr, x, rng)

template tweak*(x: untyped, v: bool): untyped =
  var x: bool = v
  addTweak(x.astToStr, x)

proc listTweaks(args: seq[string]): seq[string] =
  result = newSeq[string]()
  for k,v in tweakTable:
    case v.kind:
    of TweakFloat:
      result.add(k & " = " & $v.f[])
    of TweakInt:
      result.add(k & " = " & $v.i[])
    of TweakBool:
      result.add(k & " = " & $v.b[])

proc setTweak(args: seq[string]): seq[string] =
  if args.len != 2:
    return @["invalid usage of tweak, requires 2 args got " & $args.len]
  let k = args[0].strip()
  let v = args[1].strip()

  echo "k: '", k, "' = ", v

  try:
    let tweak = tweakTable[k]
    case tweak.kind:
    of TweakFloat:
      tweak.f[] = parseFloat(v)
    of TweakInt:
      tweak.i[] = parseInt(v)
    of TweakBool:
      tweak.b[] = parseBool(v)
    saveTweaks()
  except KeyError:
    return @["unknown tweak: '" & k & "'"]

#var winx,winy,winw,winh: Pint
#winx = 2
#winy = 2
#winw = 120
#winh = 120
#var showWin = false
#var scrollX,scrollY = 0

#proc inspect*[T](x: var T): proc() =
#  var xptr = x.addr
#  return proc() =
#    if G.beginWindow("inspector", winx, winy, winw, winh, showWin, gTopToBottom):
#      G.hExpand = true
#      for name, v in xptr[].fieldPairs:
#        when v is float32:
#          G.drag(name, v, float32.low, float32.high, 0.01f)
#        elif v is int:
#          G.drag(name, v, int.low, int.high, 0.1f)
#        elif v is Vec2i:
#          G.beginHorizontal(10)
#          G.hExpand = false
#          G.label(name)
#          G.drag("", v.x, int.low, int.high, 0.1f)
#          G.drag("", v.y, int.low, int.high, 0.1f)
#          G.hExpand = true
#          G.endArea()
#        elif v is Vec2f:
#          G.beginHorizontal(10)
#          G.hExpand = false
#          G.label(name)
#          G.drag("", v.x, float32.low, float32.high, 0.1f)
#          G.drag("", v.y, float32.low, float32.high, 0.1f)
#          G.hExpand = true
#          G.endArea()
#      G.endArea()

#proc tweaksGUI*() =
#  if G.beginWindow("tweaks", winx, winy, winw, winh, showWin, gTopToBottom):
#    G.hExpand = true
#    G.beginScrollArea(scrollX, scrollY)
#    var lastCat = ""
#    var open = true
#    for k,v in tweakTable:
#      let namebits = k.split('/')
#      var name = namebits[^1]
#      var cat = if namebits.len == 1: "" else: namebits[0]
#      if cat != lastCat:
#        open = G.beginDrawer(cat)
#        lastCat = cat
#
#      if open:
#        case v.kind:
#        of TweakFloat:
#          G.drag(name, v.f[], v.fmin, v.fmax, 0.01f)
#        of TweakInt:
#          G.drag(name, v.i[], v.imin, v.imax, 0.1f)
#        of TweakBool:
#          G.toggle(name, v.b[], true)
#
#    G.beginHorizontal(10)
#    G.hExpand = false
#    if G.button("save"):
#      saveTweaks()
#    if G.button("reset"):
#      reloadTweaks()
#    G.endArea()
#    G.endArea()
#    G.endArea()
#

var searchText = ""

var tweakPresetName = "tweaks"
var tweakPresets = getTweakPresets()

proc tweaksGUI2*() =
  guiSetStatus(Default)
  if guiBegin("tweaks"):
    guiHorizontal:
      if guiButton("save"):
        saveTweaks(tweakPresetName)
      if guiButton("reset"):
        reloadTweaks(tweakPresetName)
    if guiOption("", tweakPresetName, tweakPresets):
      reloadTweaks(tweakPresetName)
    if guiTextField("", searchText):
      echo "searchText ", searchText

    var lastCat = ""
    var open = true

    for k,v in tweakTable:
      let namebits = k.split('/')
      var name = namebits[^1]
      var cat = if namebits.len == 1: "" else: namebits[0]

      if cat != lastCat:
        guiSetStatus(Default)
        if lastCat != "" and open:
          guiEndFoldout()
        open = guiStartFoldout(cat)
        lastCat = cat

      if open:
        if searchText == "" or searchText.toLowerAscii() in name.toLowerAscii():
          case v.kind:
          of TweakFloat:
            guiSetStatus(if v.f[] != v.fsaved: Warning else: Default)
            if v.fmin == -Inf or v.fmax == Inf:
              guiDrag(name, v.f[], v.fsaved, v.fmin, v.fmax, 0.1f)
            else:
              guiSlider(name, v.f[], v.fsaved, v.fmin, v.fmax)
          of TweakInt:
            guiSetStatus(if v.i[] != v.isaved: Warning else: Default)
            if v.imin == int.low or v.imax == int.high:
              guiDrag(name, v.i[], v.isaved, v.imin, v.imax, 0.1f)
            else:
              guiSlider(name, v.i[], v.isaved, v.imin, v.imax)
          of TweakBool:
            guiSetStatus(if v.b[] != v.bsaved: Warning else: Default)
            guiToggle(name, v.b[])



registerConsoleCommand("tweaks", listTweaks)
registerConsoleCommand("tweak", setTweak)
registerConsoleCommand("reloadTweaks", proc(args: seq[string]): seq[string] = reloadTweaks(tweakPresetName))
registerConsoleCommand("saveTweaks", proc(args: seq[string]): seq[string] = saveTweaks(tweakPresetName))
