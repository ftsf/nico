import json
import tables
import nico
import nico/console
import strutils

type TweakKind = enum
  TweakFloat
  TweakInt

type Tweak = object
  case kind: TweakKind
  of TweakFloat:
    f: ptr float
  of TweakInt:
    i: ptr int

var tweakTable = newTable[string,Tweak]()

proc addTweakFloat*(name: string, f: ptr float) =
  echo "addTweakFloat: ", name, " = ", $(f[])
  tweakTable[name] = Tweak(kind: TweakFloat, f: f)

proc addTweakInt*(name: string, i: ptr int) =
  echo "addTweakInt: ", name, " = ", $(i[])
  tweakTable[name] = Tweak(kind: TweakInt, i: i)

proc `$`*(self: Tweak): string =
  case self.kind:
  of TweakFloat:
    return $self.f[]
  of TweakInt:
    return $self.i[]

proc reloadTweaks*() =
  when true:
    try:
      var j = readJsonFile("assets/tweaks.json")
      for k,v in j.pairs():
        let tweak = tweakTable[k]
        echo "tweak: '", k, "' = ", $tweak, " => ", v
        if k in tweakTable:
          case tweak.kind:
          of TweakFloat:
            tweak.f[] = v.getFloat
          of TweakInt:
            tweak.i[] = v.getInt
        else:
          echo "unregistered tweak: ", k
    except:
      return

import macros

template tweakFloat*(x: untyped, v: float): untyped =
  var x: float = v
  addTweakFloat(x.astToStr, x.addr)

template tweakInt*(x: untyped, v: int): untyped =
  var x: int = v
  addTweakInt(x.astToStr, x.addr)

proc listTweaks(args: seq[string]): seq[string] =
  result = newSeq[string]()
  for k,v in tweakTable:
    case v.kind:
    of TweakFloat:
      result.add(k & " = " & $v.f[])
    of TweakInt:
      result.add(k & " = " & $v.i[])

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
  except KeyError:
    return @["unknown tweak: '" & k & "'"]

registerConsoleCommand("tweaks", listTweaks)
registerConsoleCommand("tweak", setTweak)
