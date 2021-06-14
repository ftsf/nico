import nico
import strutils
import tables
import unicode

var consoleBG: ColorId = 9
var consoleFG: ColorId = 1
var consoleRows = 5

proc setConsoleBG*(bg: ColorId) =
  consoleBG = bg

proc setConsoleFG*(fg: ColorId) =
  consoleFG = fg

proc setConsoleRows*(rows: int) =
  consoleRows = rows

var showConsole = false
var viewIndex = 0

type ConsoleCommandCallback* = proc(args: seq[string]): seq[string]

var commands = newTable[string, ConsoleCommandCallback]()

var consoleHistory = newSeq[string]()
var historyIndex: int = 0
var consoleBuffer = newSeq[string]()
var inputBuffer = ""
consoleBuffer.add("")

proc consoleKeyListener(sym: int, mods: uint16, scancode:int, down: bool): bool

nico.addKeyListener(consoleKeyListener)

proc consoleKeyListener(sym: int, mods: uint16, scancode:int, down: bool): bool =
  when defined(js):
    return false
  else:
    if sym == 96 and down:
      showConsole = not showConsole
      return true

    if showConsole:
      if down:
        if sym == 13:
          # enter: do command
          if inputBuffer == "":
            return true
          consoleHistory.add(inputBuffer)
          historyIndex = 0
          let cmd = inputBuffer.split(' ')
          consoleBuffer.add("> " & inputBuffer)
          inputBuffer = ""
          viewIndex = 0
          if cmd[0] in commands:
            let args = if cmd.len > 1: cmd[1..^1] else: @[]
            let output = commands[cmd[0]](args)
            for line in output:
              consoleBuffer.add(line)
          else:
            consoleBuffer.add("unknown command: " & cmd[0])
          return true
        elif sym == 8:
          # handle backspace
          if inputBuffer.len > 0:
            inputBuffer = inputBuffer[0..^2]
          return true
        elif sym == 32:
          # handle space
          inputBuffer.add(' ')
          return true

        elif scancode == SCANCODE_PAGEUP.int:
          if (mods and KMOD_CTRL.uint16) != 0 and consoleRows > 1:
            consoleRows -= 1
            return true
          viewIndex += 1
          if viewIndex > consoleBuffer.high:
            viewIndex = consoleBuffer.high
          return true

        elif scancode == SCANCODE_PAGEDOWN.int:
          if (mods and KMOD_CTRL.uint16) != 0:
            consoleRows += 1
            return true
          viewIndex -= 1
          if viewIndex < 0:
            viewIndex = 0
          return true

        elif scancode == SCANCODE_UP.int:
          if consoleHistory.len > 0:
            inputBuffer = consoleHistory[consoleHistory.high - historyIndex]
            historyIndex += 1
            if historyIndex > consoleHistory.high:
              historyIndex = 0
            return true
        elif scancode == SCANCODE_DOWN.int:
          if consoleHistory.len > 0:
            inputBuffer = consoleHistory[consoleHistory.high - historyIndex]
            historyIndex -= 1
            if historyIndex < 0:
              historyIndex = 0
              inputBuffer = ""
            return true
        try:
          if (mods and KMOD_CTRL.uint16) != 0:
            return false
          # enter the character, apply shifting
          let c = if ((mods and 1.uint16) != 0) or ((mods and 2.uint16) != 0): chr(sym).toUpperAscii else: chr(sym)
          if c.isAlphaNumeric or c.isSpaceAscii or c == '.':
            inputBuffer.add(c)
          return true
        except:
          debug "unhandled key: ", sym
          discard
    return false

proc drawConsole*() =
  if showConsole:
    if consoleBuffer.len >= 100:
      consoleBuffer = consoleBuffer[consoleBuffer.high-99..consoleBuffer.high]

    setColor(consoleBG)
    rectfill(0,0,screenWidth, consoleRows * 7)
    setColor(consoleFG)
    hline(0, consoleRows * 7 - 1, screenWidth)

    var y = 1

    var startLine = max(consoleBuffer.high - (consoleRows-2) - viewIndex, 0)
    var endLine = min(startLine + consoleRows - 2, consoleBuffer.high)

    setColor(consoleFG)
    for i, line in consoleBuffer[startLine..endLine]:
      print(line, 1, y)
      y += 6

    print("> " & inputBuffer, 1, y)
    print($viewIndex, screenWidth - 10,  1)

proc registerConsoleCommand*(cmd: string, callback: ConsoleCommandCallback) =
  commands[cmd] = callback

proc unregisterConsoleCommand*(cmd: string) =
  commands.del(cmd)

proc consoleLog*(args: varargs[string, `$`]) =
  consoleBuffer.add(join(args, ", "))

# example quit command
registerConsoleCommand("quit") do(args: seq[string]) -> seq[string]:
  quit()
