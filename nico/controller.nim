when not defined(js):
  import sdl2.sdl

type NicoControllerKind* = enum
  Keyboard
  Gamepad

type NicoAxis* = enum
  pcXAxis
  pcYAxis
  pcXAxis2
  pcYAxis2
  pcLTrigger
  pcRTrigger

type NicoButton* = enum
  pcUp = "Up"
  pcDown = "Down"
  pcLeft = "Left"
  pcRight = "Right"
  pcA = "A"
  pcB = "B"
  pcX = "X"
  pcY = "Y"
  pcL1 = "L1"
  pcL2 = "L2"
  pcR1 = "R1"
  pcR2 = "R2"
  pcStart = "Start"
  pcBack = "Back"

type NicoController* = ref object
  kind*: NicoControllerKind
  name*: string
  when not defined(js):
    sdlController*: GameController # nil for keyboard
  id*: int # -1 for keyboard
  axes*: array[NicoAxis, tuple[current, previous: float]]
  buttons*: array[NicoButton, int]
  deadzone*: float
  invertX*: bool
  invertY*: bool
  useRightStick*: bool

proc newNicoController*(id: cint): NicoController =
  result = new(NicoController)
  result.id = id
  if id > -1:
    when not defined(js):
      result.sdlController = gameControllerOpen(id)
      if result.sdlController == nil:
        raise newException(Exception, "error opening game controller: " & $id)
      result.name = $result.sdlController.gameControllerName()
    result.kind = Gamepad
    result.deadzone = 0.25
  else:
    result.kind = Keyboard
    result.name = "KEYBOARD"
  echo "added game controller: ", id, ": ", result.kind, ": ", result.name

proc update*(self: NicoController) =
  for i in 0..self.buttons.high:
    if self.kind == Gamepad:
      if i == pcL2:
        if self.axes[pcLTrigger].current > self.deadzone:
          self.buttons[i] += 1
        else:
          self.buttons[i] = 0
      elif i == pcR2:
        if self.axes[pcRTrigger].current > self.deadzone:
          self.buttons[i] += 1
        else:
          self.buttons[i] = 0

    if self.buttons[i] >= 1:
      self.buttons[i] += 1

proc postUpdate*(self: NicoController) =
  for i in 0..self.axes.high:
    self.axes[i].previous = self.axes[i].current

proc btn*(self: NicoController, button: NicoButton): bool =
  return self.buttons[button] > 0

proc btnp*(self: NicoController, button: NicoButton): bool =
  return self.buttons[button] == 2

proc btnpr*(self: NicoController, button: NicoButton, repeat = 48): bool =
  let v = self.buttons[button]
  return v == 2 or v == (repeat + 2) or (v > repeat + 2 and v mod (repeat div 2) == 2)

proc setButtonState*(self: NicoController, button: NicoButton, down: bool) =
  if button > NicoButton.high:
    return
  self.buttons[button] = if down: 1 else: 0

proc setAxisValue*(self: NicoController, axis: NicoAxis, value: float) =
  if axis > NicoAxis.high:
    return
  if (axis == pcXAxis and self.invertX) or (axis == pcYAxis and self.invertY):
    self.axes[axis].current = -value
  else:
    self.axes[axis].current = value

proc axis*(self: NicoController, axis: NicoAxis): float =
  return self.axes[axis].current

proc axisp*(self: NicoController, axis: NicoAxis, value: float): bool =
  if value == -1.0:
    return self.axes[axis].current < -self.deadzone and not (self.axes[axis].previous < -self.deadzone)
  if value == 1.0:
    return self.axes[axis].current > self.deadzone and not (self.axes[axis].previous > self.deadzone)
  if value == 0.0:
    return abs(self.axes[axis].current) < self.deadzone and not (abs(self.axes[axis].previous) < self.deadzone)
