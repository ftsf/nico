import sdl2
import sdl2.gamecontroller

type NicoControllerKind* = enum
  Keyboard
  Gamepad

type NicoAxis* = enum
  pcXAxis
  pcYAxis
  pcLTrigger
  pcRTrigger

type NicoButton* = enum
  pcUp
  pcDown
  pcLeft
  pcRight
  pcA
  pcB
  pcX
  pcY
  pcL1
  pcL2
  pcR1
  pcR2
  pcStart
  pcBack

type NicoController* = ref object of RootObj
  kind*: NicoControllerKind
  name*: string
  sdlController*: GameControllerPtr # nil for keyboard
  sdlControllerId*: int # -1 for keyboard
  axes*: array[NicoAxis.low..NicoAxis.high, tuple[current, previous: float]]
  buttons*: array[NicoButton.low..NicoButton.high, int]

proc newNicoController*(sdlControllerId: cint): NicoController =
  result = new(NicoController)
  result.sdlControllerId = sdlControllerId
  if sdlControllerId > -1:
    result.sdlController = gameControllerOpen(sdlControllerId)
    if result.sdlController == nil:
      raise newException(Exception, "error opening game controller: " & $sdlControllerId)
    result.kind = Gamepad
    result.name = $result.sdlController.name
  else:
    result.kind = Keyboard
    result.name = "KEYBOARD"
  echo "added game controller: ", sdlControllerId, ": ", result.kind, ": ", result.name

proc update*(self: NicoController) =
  for i in 0..self.buttons.high:
    if self.buttons[i] >= 1:
      self.buttons[i] += 1
    if self.buttons[i] > 48:
      self.buttons[i] = 1

proc postUpdate*(self: NicoController) =
  for i in 0..self.axes.high:
    self.axes[i].previous = self.axes[i].current

proc btn*(self: NicoController, button: NicoButton): bool =
  return self.buttons[button] > 0

proc btnp*(self: NicoController, button: NicoButton): bool =
  return self.buttons[button] == 2

proc setButtonState*(self: NicoController, button: NicoButton, down: bool) =
  if button > NicoButton.high:
    return
  self.buttons[button] = if down: 1 else: 0

proc setAxisValue*(self: NicoController, axis: NicoAxis, value: float) =
  if axis > NicoAxis.high:
    return
  self.axes[axis].current = value

proc axis*(self: NicoController, axis: NicoAxis): float =
  return self.axes[axis].current

proc axisp*(self: NicoController, axis: NicoAxis, value: float): bool =
  if value == -1.0:
    return self.axes[axis].current < -0.5 and not (self.axes[axis].previous < -0.5)
  if value == 1.0:
    return self.axes[axis].current > 0.5 and not (self.axes[axis].previous > 0.5)
  if value == 0.0:
    return abs(self.axes[axis].current) < 0.5 and not (abs(self.axes[axis].previous) < 0.5)
