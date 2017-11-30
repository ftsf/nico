import nico
import strutils

var n = 69
var shape = 0

type Instrument = tuple[shape: uint8, init: uint8, change: uint8]
type Row = tuple[note: uint8, inst: uint8, command: uint8, arg: uint8]
type Pattern = array[16, Row]
type SongRow = array[4, uint8]
type Song = array[64, SongRow]

var patterns: array[64, Pattern]
var song: Song
var instruments: array[64, Instrument]

type View = enum
  songView = "Song"
  patternView = "Pattern"
  instrumentView = "Inst"

var view: View
var tick = 0
var currentPattern = 0
var currentSongRow = 0
var currentChannel = 0
var currentPatternRow = 0
var currentPatternCol: range[0..3] = 0
var currentInstrument = 0
var currentInstrumentSetting: range[0..3] = 0

var songChannelCursors: array[4, uint8]

var musicTimer: int

proc musicUpdate() =
  for channel in 0..3:
    let pat = song[songChannelCursors[channel]][channel]
    if pat != 0:
      let n = patterns[pat][tick mod 16].note
      if n != 0:
        # todo get instr settings
        let i = patterns[pat][tick mod 16].inst
        let inst = instruments[i]
        if i == 0:
          pitch(channel, note(n.int))
        else:
          let change = if inst.change > 0x8.uint8: (inst.change.int - 0x8).float else: -inst.change.float
          synth(channel, inst.shape.SynthShape, note(n.int), inst.init.int * 16, change)
  tick += 1
  if tick mod 16 == 0:
    # move cursors
    for channel in 0..3:
      # check if the next row in the song has an entry
      if song[songChannelCursors[channel] + 1][channel] != 0:
        songChannelCursors[channel] += 1
      else:
        # seek up to the top of the island
        while true:
          if songChannelCursors[channel] == 0 or song[songChannelCursors[channel] - 1][channel] == 0:
            break
          else:
            songChannelCursors[channel] -= 1

proc gameInit() =
  bpm(90)
  tpb(4)
  n = 69
  shape = 0
  tick = 0
  view = songView
  currentPattern = 0
  currentSongRow = 0
  currentChannel = 0
  currentPatternRow = 0
  currentPatternCol = 0

  instruments[1].shape = 2
  instruments[1].init = 0xa
  instruments[1].change = 0x1

  instruments[2].shape = 2
  instruments[2].init = 0xa
  instruments[2].change = 0x7

  instruments[3].shape = 2
  instruments[3].init = 0xa
  instruments[3].change = 0x3

  instruments[4].shape = 4
  instruments[4].init = 0xa
  instruments[4].change = 0x1

  instruments[5].shape = 5
  instruments[5].init = 0xa
  instruments[5].change = 0x1

  setTickFunc(musicUpdate)

proc gameUpdate(dt: float) =
  if btn(pcX):
    if btnp(pcLeft):
      if view > view.low:
        view = (view.int - 1).View
      return
    if btnp(pcRight):
      if view < view.high:
        view = (view.int + 1).View
      return

  case view:
  of songView:
    if btnp(pcY):
      for i in 0..3:
        songChannelCursors[i] = currentSongRow.uint8
        tick = 0
    if btn(pcA):
      if btnp(pcLeft):
        if song[currentSongRow][currentChannel].int > 0:
          song[currentSongRow][currentChannel] -= 1
        currentPattern = song[currentSongRow][currentChannel].int
      if btnp(pcRight):
        if song[currentSongRow][currentChannel].int < 63:
          song[currentSongRow][currentChannel] += 1
        currentPattern = song[currentSongRow][currentChannel].int
      if btnp(pcUp):
        if song[currentSongRow][currentChannel].int < 63:
          song[currentSongRow][currentChannel] += 16
        currentPattern = song[currentSongRow][currentChannel].int
      if btnp(pcDown):
        if song[currentSongRow][currentChannel].int < 63:
          song[currentSongRow][currentChannel] -= 16
        currentPattern = song[currentSongRow][currentChannel].int
    elif btnp(pcB):
      song[currentSongRow][currentChannel] = 0
    else:
      if btnp(pcLeft):
        currentChannel -= 1
        if currentChannel < 0:
          currentChannel = 0
        currentPattern = song[currentSongRow][currentChannel].int
      if btnp(pcRight):
        currentChannel += 1
        if currentChannel > 3:
          currentChannel = 3
        currentPattern = song[currentSongRow][currentChannel].int
      if btnp(pcUp):
        currentSongRow -= 1
        if currentSongRow < 0:
          currentSongRow = 0
        currentPattern = song[currentSongRow][currentChannel].int
      if btnp(pcDown):
        currentSongRow += 1
        if currentSongRow > 63:
          currentSongRow = 63
        currentPattern = song[currentSongRow][currentChannel].int

  of patternView:
    if btn(pcA):
      case currentPatternCol:
      of 0:
        if patterns[currentPattern][currentPatternRow].note != 0:
          n = patterns[currentPattern][currentPatternRow].note.int
        if btnp(pcUp):
          n += 12
        if btnp(pcDown):
          n -= 12
        if btnp(pcLeft):
          n -= 1
        if btnp(pcRight):
          n += 1
        patterns[currentPattern][currentPatternRow].note = n.uint8
        patterns[currentPattern][currentPatternRow].inst = currentInstrument.uint8
      of 1:
        currentInstrument = patterns[currentPattern][currentPatternRow].inst.int
        if btnp(pcUp):
          if currentInstrument < 63:
            currentInstrument += 16
          else:
            currentInstrument = 63
        if btnp(pcDown):
          if currentInstrument > 16:
            currentInstrument -= 16
          else:
            currentInstrument = 0
        if btnp(pcLeft):
          if currentInstrument > 0:
            currentInstrument -= 1
        if btnp(pcRight):
          if currentInstrument < 15:
            currentInstrument += 1
        patterns[currentPattern][currentPatternRow].inst = currentInstrument.uint8
      of 2:
        discard
      of 3:
        discard
    elif btnp(pcB):
      case currentPatternCol:
      of 0:
        patterns[currentPattern][currentPatternRow].note = 0
      of 1:
        patterns[currentPattern][currentPatternRow].inst = 0
      of 2:
        patterns[currentPattern][currentPatternRow].command = 0
      of 3:
        patterns[currentPattern][currentPatternRow].arg = 0
    else:
      if btnp(pcUp):
        if currentPatternRow > 0:
          currentPatternRow -= 1
      if btnp(pcDown):
        if currentPatternRow < 15:
          currentPatternRow += 1
      if btnp(pcLeft):
        if currentPatternCol > 0:
          currentPatternCol -= 1
      if btnp(pcRight):
        if currentPatternCol < 3:
          currentPatternCol += 1

  of instrumentView:
    if btn(pcA):
      case currentInstrumentSetting:
      of 0:
        if btnp(pcLeft):
          instruments[currentInstrument].shape -= 1
        if btnp(pcRight):
          instruments[currentInstrument].shape += 1
      of 1:
        if btnp(pcLeft):
          instruments[currentInstrument].init -= 1
        if btnp(pcRight):
          instruments[currentInstrument].init += 1
      of 2:
        if btnp(pcLeft):
          instruments[currentInstrument].change -= 1
        if btnp(pcRight):
          instruments[currentInstrument].change += 1
      of 3:
        discard
    else:
      if btnp(pcUp):
        if currentInstrumentSetting > 0:
          currentInstrumentSetting -= 1
      if btnp(pcDown):
        if currentInstrumentSetting < 15:
          currentInstrumentSetting += 1

  else:
    discard

proc noteString(n: int): string =
  if n == 0:
    return "..."

  let oct = n div 12
  let note = n mod 12

  case note:
  of 0:
    return "C-" & $oct
  of 1:
    return "C#" & $oct
  of 2:
    return "D-" & $oct
  of 3:
    return "D#" & $oct
  of 4:
    return "E-" & $oct
  of 5:
    return "F-" & $oct
  of 6:
    return "F#" & $oct
  of 7:
    return "G-" & $oct
  of 8:
    return "G#" & $oct
  of 9:
    return "A-" & $oct
  of 10:
    return "A#" & $oct
  of 11:
    return "B-" & $oct
  else:
    return "???"

proc gameDraw() =
  cls()

  case view:
  of songView:
    setColor(2)
    printr($view, screenWidth - 1, 1)
    for row in 0..<song.len:
      setColor(5)
      print(toHex(row, 2), 1, 1 + row * 8)
      for col in 0..3:
        if songChannelCursors[col].int == row:
          setColor(2)
          print(">", 16 + col * 16 - 4, 1 + row * 8)
        setColor(if currentSongRow == row and currentChannel == col: 7 else: 5)
        if song[row][col] == 0:
          print("..", 16 + col * 16, 1 + row * 8)
        else:
          print(toHex(song[row][col]), 16 + col * 16, 1 + row * 8)
  of patternView:
    setColor(2)
    printr($view & " " & toHex(currentPattern, 2), screenWidth - 1, 1)
    var p = patterns[currentPattern]
    for row in 0..<p.len:
      setColor(if tick mod 16 == row: 2 elif row mod 4 == 0: 3 else: 5)
      print(toHex(row, 2), 1, 1 + row * 8)
      # note
      setColor(if row == currentPatternRow and currentPatternCol == 0: 7 else: 5)
      print(noteString(p[row].note.int), 16, 1 + row * 8)
      # inst
      setColor(if row == currentPatternRow and currentPatternCol == 1: 7 else: 5)
      print(if p[row].inst == 0: " .." else: "I" & toHex(p[row].inst), 32, 1 + row * 8)
      # cmd
      setColor(if row == currentPatternRow and currentPatternCol == 2: 7 else: 5)
      print(toHex(p[row].command), 64, 1 + row * 8)
      # cmd
      setColor(if row == currentPatternRow and currentPatternCol == 3: 7 else: 5)
      print(toHex(p[row].arg), 72, 1 + row * 8)
  of instrumentView:
    setColor(2)
    printr($view & " " & toHex(currentInstrument, 2), screenWidth - 1, 1)

    setColor(if currentInstrumentSetting == 0: 7 else: 5)
    print("SHAPE:  " & $instruments[currentInstrument].shape.SynthShape, 1, 10)
    setColor(if currentInstrumentSetting == 1: 7 else: 5)
    print("INIT:   " & toHex(instruments[currentInstrument].init), 1, 30)
    setColor(if currentInstrumentSetting == 2: 7 else: 5)
    print("CHANGE: " & toHex(instruments[currentInstrument].change), 1, 40)
  else:
    discard

nico.init("nico", "audio")
integerScale(true)
fixedSize(true)
nico.createWindow("audio", 128, 128, 4)
nico.run(gameInit, gameUpdate, gameDraw)
