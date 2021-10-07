type ColorId* = int
type Pfloat* = float32
type Pint* = int

converter toPfloat*(x: int): Pfloat =
  x.Pfloat

converter toPint*(x: float32): Pint =
  x.Pint

type NicoButton* = enum
  pcLeft = "Left"
  pcRight = "Right"
  pcUp = "Up"
  pcDown = "Down"
  pcA = "A"
  pcB = "B"
  pcX = "X"
  pcY = "Y"
  pcL1 = "L1"
  pcL2 = "L2"
  pcL3 = "L3"
  pcR1 = "R1"
  pcR2 = "R2"
  pcR3 = "R3"
  pcStart = "Start"
  pcBack = "Back"


