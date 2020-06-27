import nico
import nico/utils
import strutils
import std/wordwrap

type
  GuiDirection* = enum
    gTopToBottom
    gBottomToTop
    gLeftToRight
    gRightoLeft

  GuiStyle* = enum
    gInert
    gInteractable
    gHovered
    gInteracted
    gDisabled

  GuiOutcome* = enum
    gDefault
    gPrimary
    gGood
    gWarning
    gDanger

  GuiColorSet* = tuple
    modalOutline: int
    text: int
    textInteractable: int
    textHover: int
    textInteract: int
    textDisabled: int
    outline: int
    outlineHover: int
    outlineInteract: int
    outlineDisabled: int
    fill: int
    fillHover: int
    fillInteract: int
    fillDisabled: int
    sliderFill: int
    sliderHandle: int

  GuiEventKind = enum
    gRepaint
    gMouseDown
    gMouseUp
    gMouseMove
    gKeyDown

  GuiEvent = object
    kind: GuiEventKind
    x,y: int
    xrel,yrel: float32
    button: int
    keycode: Keycode

  GuiArea* = ref object
    id*: int
    minX*,minY*,maxX*,maxY*: int
    cursorX*,cursorY*: int
    direction*: GuiDirection
    modal*: bool

  Gui* = ref object
    e: GuiEvent
    element*: int
    # colors
    colorSets*: array[GuiOutcome, GuiColorSet]

    hoverElement*: int
    activeHoverElement*: int
    activeElement*: int
    downElement*: int
    wasMouseDown: bool
    areas: seq[GuiArea]
    area*: GuiArea
    currentAreaId: int
    hSpacing*,vSpacing*: int
    hPadding*,vPadding*: int
    center*: bool
    hExpand*: bool
    vExpand*: bool
    modalArea*: int
    nextAreaId: int
    hintHotkey*: Keycode
    hintOnly*: bool
    dragIntTmp: float32
    outcome*: GuiOutcome

  GuiDrawProc = proc(G: Gui, x,y,w,h: int, style: GuiStyle, ta, va: TextAlign)

var G*: Gui = new(Gui)

# default color theme
var colorSetLight*: array[GuiOutcome, GuiColorSet]
colorSetLight[gDefault].modalOutline = 0

colorSetLight[gDefault].text = 1
colorSetLight[gDefault].textInteractable = 1
colorSetLight[gDefault].textHover = 1
colorSetLight[gDefault].textInteract = 1
colorSetLight[gDefault].textDisabled = 5
colorSetLight[gDefault].outline = 5
colorSetLight[gDefault].outlineHover = 7
colorSetLight[gDefault].outlineInteract = 1
colorSetLight[gDefault].outlineDisabled = 5
colorSetLight[gDefault].fill = 13
colorSetLight[gDefault].fillHover = 13
colorSetLight[gDefault].fillInteract = 5
colorSetLight[gDefault].fillDisabled = 13
colorSetLight[gDefault].sliderFill = 6
colorSetLight[gDefault].sliderHandle = 7

for outcome in gDefault.succ..GuiOutcome.high:
  colorSetLight[outcome] = colorSetLight[gDefault]

colorSetLight[gGood].text = 11
colorSetLight[gGood].outlineHover = 11
colorSetLight[gGood].fillInteract = 3
colorSetLight[gGood].outline = 3
colorSetLight[gGood].outlineDisabled = 3

colorSetLight[gPrimary].text = 12
colorSetLight[gPrimary].outlineHover = 12
colorSetLight[gPrimary].fillInteract = 1
colorSetLight[gPrimary].outline = 1
colorSetLight[gPrimary].outlineDisabled = 1

colorSetLight[gWarning].text = 9
colorSetLight[gWarning].outlineHover = 9
colorSetLight[gWarning].outline = 9
colorSetLight[gWarning].fillInteract = 4
colorSetLight[gWarning].outline = 4
colorSetLight[gWarning].outlineDisabled = 4

colorSetLight[gDanger].text = 8
colorSetLight[gDanger].outlineHover = 8
colorSetLight[gDanger].outline = 8
colorSetLight[gDanger].fillInteract = 2
colorSetLight[gDanger].outline = 2
colorSetLight[gDanger].outlineDisabled = 2


# dark color theme
var colorSetDark*: array[GuiOutcome, GuiColorSet]

colorSetDark[gDefault].modalOutline = 0

colorSetDark[gDefault].text = 6
colorSetDark[gDefault].textInteractable = 6
colorSetDark[gDefault].textHover = 6
colorSetDark[gDefault].textInteract = 6
colorSetDark[gDefault].textDisabled = 5
colorSetDark[gDefault].outline = 5
colorSetDark[gDefault].outlineHover = 7
colorSetDark[gDefault].outlineInteract = 6
colorSetDark[gDefault].outlineDisabled = 5
colorSetDark[gDefault].fill = 0
colorSetDark[gDefault].fillHover = 0
colorSetDark[gDefault].fillInteract = 5
colorSetDark[gDefault].fillDisabled = 0
colorSetDark[gDefault].sliderFill = 13
colorSetDark[gDefault].sliderHandle = 7

for outcome in gDefault.succ..GuiOutcome.high:
  colorSetDark[outcome] = colorSetDark[gDefault]

colorSetDark[gGood].text = 11
colorSetDark[gGood].outlineHover = 11
colorSetDark[gGood].fillInteract = 3
colorSetDark[gGood].outline = 3
colorSetDark[gGood].outlineDisabled = 3

colorSetDark[gPrimary].text = 12
colorSetDark[gPrimary].outlineHover = 12
colorSetDark[gPrimary].fillInteract = 1
colorSetDark[gPrimary].outline = 1
colorSetDark[gPrimary].outlineDisabled = 1

colorSetDark[gWarning].text = 9
colorSetDark[gWarning].outlineHover = 9
colorSetDark[gWarning].outline = 9
colorSetDark[gWarning].fillInteract = 4
colorSetDark[gWarning].outline = 4
colorSetDark[gWarning].outlineDisabled = 4

colorSetDark[gDanger].text = 8
colorSetDark[gDanger].outlineHover = 8
colorSetDark[gDanger].outline = 8
colorSetDark[gDanger].fillInteract = 2
colorSetDark[gDanger].outline = 2
colorSetDark[gDanger].outlineDisabled = 2

G.colorSets = colorSetLight

# default padding
G.hPadding = 3
G.vPadding = 3
G.hSpacing = 2
G.vSpacing = 1

var lastMouseX,lastMouseY: int
var frame: int

proc box*(G: Gui, x,y,w,h: int, style: GuiStyle = gInert)

proc pointInRect(px,py, x,y,w,h: int): bool =
  return px >= x and px <= x + w - 1 and py >= y and py <= y + h - 1

proc advance(G: Gui, w,h: int) =
  assert(G.area != nil)
  case G.area.direction:
  of gLeftToRight:
    G.area.cursorX += w + G.hSpacing
    if G.area.cursorX >= G.area.maxX:
      G.area.cursorX = G.area.minX
      G.area.cursorY += h + G.vSpacing
  of gRightoLeft:
    G.area.cursorX -= w + G.hSpacing
    if G.area.cursorX <= G.area.minX:
      G.area.cursorX = G.area.maxX
      G.area.cursorY += h + G.vSpacing
  of gTopToBottom:
    G.area.cursorY += h + G.vSpacing
    if G.area.cursorY >= G.area.maxY:
      G.area.cursorY = G.area.minY
      G.area.cursorX += w + G.hSpacing
  of gBottomToTop:
    G.area.cursorY -= h + G.vSpacing
    if G.area.cursorY <= G.area.minY:
      G.area.cursorY = G.area.maxY
      G.area.cursorX += w + G.hSpacing

proc cursor(G: Gui, w, h: int): (int,int) =
  assert(G.area != nil)
  result[0] = if G.area.direction == gRightoLeft: G.area.cursorX - w else: G.area.cursorX
  result[1] = if G.area.direction == gBottomToTop: G.area.cursorY - h else: G.area.cursorY

proc label*(G: Gui, text: string, x,y,w,h: int, box: bool = false) =
  G.element += 1
  if G.e.kind == gRepaint:
    if box:
      G.box(x,y,w,h)
    setColor(G.colorSets[G.outcome].text)
    let nLines = text.countLines()
    richPrint(text, x + (if G.center: w div 2 else: 0), y + (if G.center: h div 2 - (fontHeight() * nLines) div 2 else: 0), if G.center: taCenter else: taLeft)

  if G.e.kind == gMouseMove:
    if pointInRect(G.e.x, G.e.y, x, y, w, h):
      G.hoverElement = G.element
      G.activeHoverElement = 0

proc label*(G: Gui, text: string, w, h: int, box: bool = false) =
  let (x,y) = G.cursor(w,h)
  G.label(text, x, y, w, h, box)
  G.advance(w,h)

proc label*(G: Gui, text: string, box: bool = false) =
  assert(G.area != nil)
  var w = 0
  var h = 0
  let maxWidth = G.area.maxX - G.area.minX
  # TODO word wrapping to fix max width
  let text = wrapWords(text, maxWidth div glyphWidth('x'), true)
  for line in text.splitLines():
    var lineW = textWidth(line)
    if lineW > w:
      w = min(lineW, maxWidth)
    h += fontHeight()
  w = if G.hExpand: G.area.maxX - G.area.minX else: w + (if box: G.hPadding * 2 else: 0)
  h = if G.vExpand: G.area.maxY - G.area.minY else: h + (if box: G.vPadding * 2 else: 0)
  G.label(text, w, h, box)

proc labelStep*(G: Gui, text: string, x,y,w,h: int, step: int, box: bool = false) =
  G.element += 1
  if G.e.kind == gRepaint:
    if box:
      G.box(x,y,w,h)
    setColor(G.colorSets[G.outcome].text)
    let nLines = text.countLines()
    richPrint(text, x + (if G.center: w div 2 else: 0), y + (if G.center: h div 2 - (fontHeight() * nLines) div 2 else: 0), if G.center: taCenter else: taLeft, false, step)

  if G.e.kind == gMouseMove:
    if pointInRect(G.e.x, G.e.y, x, y, w, h):
      G.hoverElement = G.element
      G.activeHoverElement = 0

proc labelStep*(G: Gui, text: string, w, h: int, step: int, box: bool = false) =
  let (x,y) = G.cursor(w,h)
  G.labelStep(text, x, y, w, h, step, box)
  G.advance(w,h)

proc labelStep*(G: Gui, text: string, step: int, box: bool = false) =
  assert(G.area != nil)
  var w = 0
  var h = 0
  for line in text.splitLines():
    var lineW = textWidth(line)
    if lineW > w:
      w = lineW
    h += fontHeight()
  w = if G.hExpand: G.area.maxX - G.area.minX else: w + (if box: G.hPadding * 2 else: 0)
  h = if G.vExpand: G.area.maxY - G.area.minY else: h + (if box: G.vPadding * 2 else: 0)
  G.labelStep(text, w, h, step, box)

proc drawGuiString(G: Gui, text: string, x,y,w,h: int, style: GuiStyle = gInert, ta: TextAlign = taLeft, va: TextAlign = taCenter) =
  let cs = G.colorSets[G.outcome]
  setColor(case style:
  of gInert: cs.text
  of gInteractable: cs.textInteractable
  of gHovered: cs.textHover
  of gInteracted: cs.textInteract
  of gDisabled: cs.textDisabled
  )
  let nLines = text.countLines()
  if ta == taCenter:
    richPrint(text, x + w div 2, y + (if va == taCenter: h div 2 - (fontHeight() * nLines) div 2 else: G.vPadding), ta, false, -1)
  elif ta == taLeft:
    richPrint(text, x + G.hPadding, y + (if va == taCenter: h div 2 - (fontHeight() * nLines) div 2 else: G.vPadding), ta, false, -1)
  elif ta == taRight:
    richPrint(text, x + w - G.hPadding, y + (if va == taCenter: h div 2 - (fontHeight() * nLines) div 2 else: G.vPadding), ta, false, -1)

proc button*(G: Gui, x,y,w,h: int, enabled: bool = true, hotkey = K_UNKNOWN, draw: GuiDrawProc): bool =
  G.element += 1
  let hintBlocked = (G.hintOnly and G.hintHotkey != hotkey)
  if G.e.kind == gRepaint:

    let hovered = G.activeHoverElement == G.element
    let down = G.downElement == G.element
    let active = G.activeElement == G.element

    let style = if not enabled: gDisabled elif down: gInteracted elif hovered: gHovered else: gInteractable

    G.box(x,y,w,h,style)

    draw(G, x + G.hPadding, y + G.vPadding, w - G.hPadding * 2, h - G.vPadding * 2, style, taCenter, taCenter)

  if G.modalArea != 0:
    # check that we're underneath the modal G.area
    var inModalArea = false
    for a in G.areas:
      if a.id == G.modalArea:
        inModalArea = true
        break
    if not inModalArea:
      return

  if G.e.kind == gMouseMove:
    if G.downElement == 0 and pointInRect(G.e.x, G.e.y, x, y, w, h):
      G.hoverElement = G.element
      G.activeHoverElement = if enabled and not hintBlocked: G.element else: 0

  if enabled == false or hintBlocked:
    return false

  if G.e.kind == gMouseDown:
    if pointInRect(G.e.x, G.e.y, x, y, w, h):
      G.downElement = G.element

  elif G.e.kind == gKeyDown and hotkey != K_UNKNOWN and keyp(hotkey):
    if G.downElement != G.element:
      G.downElement = G.element
    else:
      G.activeElement = G.element
      G.downElement = 0
      return true

  elif G.e.kind == gMouseUp:
    if pointInRect(G.e.x, G.e.y, x, y, w, h):
      if G.downElement == G.element:
        G.activeElement = G.element
        G.downElement = 0
        return true

  return false

proc button*(G: Gui, text: string, x,y,w,h: int, enabled: bool = true, hotkey = K_UNKNOWN): bool =
  return G.button(x,y,w,h,enabled,hotkey,proc(G:Gui,x,y,w,h: int, style: GuiStyle, ta, va: TextAlign) =
    G.drawGuiString(text,x,y,w,h,style,ta,va)
  )

proc button*(G: Gui, text: string, w, h: int, enabled: bool = true, hotkey = K_UNKNOWN): bool =
  let (x,y) = G.cursor(w,h)
  let ret = G.button(text, x, y, w, h, enabled, hotkey)
  G.advance(w,h)
  return ret

proc button*(G: Gui, w,h: int, enabled: bool = true, hotkey = K_UNKNOWN, draw: proc(G:Gui,x,y,w,h:int, style: GuiStyle, ta, va: TextAlign)): bool =
  let (x,y) = G.cursor(w,h)
  let ret = G.button(x, y, w, h, enabled, hotkey, draw)
  G.advance(w,h)
  return ret

proc button*(G: Gui, w,h: int, enabled: bool = true, draw: GuiDrawProc): bool =
  let (x,y) = G.cursor(w,h)
  let ret = G.button(x, y, w, h, enabled, K_UNKNOWN, draw)
  G.advance(w,h)
  return ret

proc button*(G: Gui, text: string, enabled: bool = true, keycode: Keycode = K_UNKNOWN): bool =
  assert(G.area != nil)
  let w = if G.hExpand: G.area.maxX - G.area.minX else: textWidth(text) + G.hPadding * 2
  let h = if G.vExpand: G.area.maxY - G.area.minY else: fontHeight() * text.countLines() + G.vPadding * 2
  return G.button(text, w, h, enabled, keycode)

proc toggle*(G: Gui, val: var bool, x,y,w,h: int, enabled: bool = true, hotkey = K_UNKNOWN, draw: GuiDrawProc): bool {.discardable.} =
  G.element += 1
  let hintBlocked = (G.hintOnly and G.hintHotkey != hotkey)
  if G.e.kind == gRepaint:

    let hovered = G.activeHoverElement == G.element
    let down = val
    let active = G.activeElement == G.element

    let style = if not enabled: gDisabled elif down: gInteracted elif hovered: gHovered else: gInteractable

    G.box(x,y,w,h,style)

    draw(G, x + G.hPadding, y + G.vPadding, w - G.hPadding * 2, h - G.vPadding * 2, style, taCenter, taCenter)

  if G.modalArea != 0:
    # check that we're underneath the modal G.area
    var inModalArea = false
    for a in G.areas:
      if a.id == G.modalArea:
        inModalArea = true
        break
    if not inModalArea:
      return

  if G.e.kind == gMouseMove:
    if G.downElement == 0 and pointInRect(G.e.x, G.e.y, x, y, w, h):
      G.hoverElement = G.element
      G.activeHoverElement = if enabled and not hintBlocked: G.element else: 0

  if enabled == false or hintBlocked:
    return false

  if G.e.kind == gMouseDown:
    if pointInRect(G.e.x, G.e.y, x, y, w, h):
      G.downElement = G.element

  elif G.e.kind == gKeyDown and hotkey != K_UNKNOWN and keyp(hotkey):
    if G.downElement != G.element:
      G.downElement = G.element
    else:
      G.activeElement = G.element
      G.downElement = 0
      val = not val
      return true

  elif G.e.kind == gMouseUp:
    if pointInRect(G.e.x, G.e.y, x, y, w, h):
      if G.downElement == G.element:
        G.activeElement = G.element
        G.downElement = 0
        val = not val
        return true

  return false

proc toggle*(G: Gui, text: string, val: var bool, x,y,w,h: int, enabled: bool = true, hotkey = K_UNKNOWN): bool {.discardable.} =
  return G.toggle(val,x,y,w,h,enabled,hotkey,proc(G:Gui,x,y,w,h: int, style: GuiStyle, ta, va: TextAlign) =
    G.drawGuiString(text,x,y,w,h,style,ta,va)
  )

proc toggle*(G: Gui, text: string, val: var bool, w, h: int, enabled: bool = true, hotkey = K_UNKNOWN): bool {.discardable.} =
  let (x,y) = G.cursor(w,h)
  let ret = G.toggle(text, val, x, y, w, h, enabled, hotkey)
  G.advance(w,h)
  return ret

proc toggle*(G: Gui, val: var bool, w,h: int, enabled: bool = true, hotkey = K_UNKNOWN, draw: proc(G:Gui,x,y,w,h:int, style: GuiStyle, ta, va: TextAlign)): bool {.discardable.} =
  let (x,y) = G.cursor(w,h)
  let ret = G.toggle(val, x, y, w, h, enabled, hotkey, draw)
  G.advance(w,h)
  return ret

proc toggle*(G: Gui, val: var bool, w,h: int, enabled: bool = true, draw: GuiDrawProc): bool {.discardable.} =
  let (x,y) = G.cursor(w,h)
  let ret = G.toggle(val, x, y, w, h, enabled, K_UNKNOWN, draw)
  G.advance(w,h)
  return ret

proc toggle*(G: Gui, text: string, val: var bool, enabled: bool = true, keycode: Keycode = K_UNKNOWN): bool {.discardable.} =
  assert(G.area != nil)
  let w = if G.hExpand: G.area.maxX - G.area.minX else: textWidth(text) + G.hPadding * 2
  let h = if G.vExpand: G.area.maxY - G.area.minY else: fontHeight() * text.countLines() + G.vPadding * 2
  return G.toggle(text, val, w, h, enabled, keycode)

proc getValueStr[T](value: T): string =
  when T is SomeFloat:
    result = value.formatFloat(ffDecimal, 2)
  else:
    result = $value

proc drag*[T](G: Gui, text: string, value: var T, min: T, max: T,sensitivity: float32, x,y,w,h: Pint, enabled: bool = true): bool =
  G.element += 1
  let hintBlocked = G.hintOnly

  if G.e.kind == gRepaint:
    let hovered = G.activeHoverElement == G.element
    let down = G.downElement == G.element

    let style = if not enabled: gDisabled elif down: gInteracted elif hovered: gHovered else: gInteractable

    G.box(x,y,w,h,style)

    G.drawGuiString(text & ": ", x + G.hPadding, y + G.vPadding, w - G.hPadding * 2, h - G.vPadding * 2, style, taLeft)
    G.drawGuiString(getValueStr(value), x + G.hPadding, y + G.vPadding, w - G.hPadding * 2, h - G.vPadding * 2, style, taRight)

  if G.modalArea != 0:
    # check that we're underneath the modal G.area
    var inModalArea = false
    for a in G.areas:
      if a.id == G.modalArea:
        inModalArea = true
        break
    if not inModalArea:
      return

  result = G.downElement == G.element

  if G.e.kind == gMouseMove:
    if G.downElement == G.element:
      var sensitivity = sensitivity
      if key(K_LCTRL) and key(K_LSHIFT):
        sensitivity *= 0.01'f
      elif key(K_LSHIFT):
        sensitivity *= 0.1'f
      elif key(K_LCTRL):
        sensitivity *= 10'f
      when T is SomeFloat:
        value += G.e.xrel * sensitivity
      else:
        G.dragIntTmp += G.e.xrel * sensitivity
        value = G.dragIntTmp.T
      value = clamp(value, min, max)

    if pointInRect(G.e.x, G.e.y, x, y, w, h):
      G.hoverElement = G.element
      G.activeHoverElement = if enabled and not hintBlocked: G.element else: 0

  if enabled == false or hintBlocked:
    return false

  if G.e.kind == gMouseDown:
    if pointInRect(G.e.x, G.e.y, x, y, w, h):
      G.downElement = G.element
      when T is not SomeFloat:
        G.dragIntTmp = value.float32

  elif G.e.kind == gMouseUp:
    if pointInRect(G.e.x, G.e.y, x, y, w, h):
      if G.downElement == G.element:
        G.activeElement = G.element
        G.downElement = 0
        return

  return

proc drag*[T](G: Gui, text: string, value: var T, min, max: T, sensitivity: float32, w, h: int, enabled: bool = true): bool =
  let (x,y) = G.cursor(w,h)
  let ret = G.drag(text, value, min, max, sensitivity, x, y, w, h, enabled)
  G.advance(w,h)
  return ret

proc drag*[T](G: Gui, text: string, value: var T, min, max: T, sensitivity: float32, enabled: bool = true): bool =
  assert(G.area != nil)
  let w = if G.hExpand: G.area.maxX - G.area.minX else: textWidth(text & ": " & getValueStr(value) & "  ") +  + G.hPadding * 2
  let h = if G.vExpand: G.area.maxY - G.area.minY else: fontHeight() * text.countLines() + G.vPadding * 2
  return G.drag(text, value, min, max, sensitivity, w, h, enabled)

proc slider*[T](G: Gui, text: string, value: var T, min: T, max: T, x,y,w,h: Pint, enabled: bool = true): bool =
  G.element += 1
  let hintBlocked = G.hintOnly

  if G.e.kind == gRepaint:
    let hovered = G.activeHoverElement == G.element
    let down = G.downElement == G.element

    let style = if not enabled: gDisabled elif down: gInteracted elif hovered: gHovered else: gInteractable

    G.box(x,y,w,h,style)
    setColor(G.colorSets[G.outcome].sliderFill)
    let fillAmount = clamp(invLerp(min.float32,max.float32,value.float32))
    let minx = x + 1
    let maxx = x + w - 2
    let range = maxx - minx
    if fillAmount > 0:
      rectfill(minx,y+1,minx + range.float32 * fillAmount,y+h-2)
    if down:
      setColor(G.colorSets[G.outcome].sliderHandle)
      rectfill(max(minx + range.float32 * fillAmount - 1, minx), y+1, min(minx + range.float32 * fillAmount + 1, maxx), y+h-2)

    G.drawGuiString(text & ": ", x + G.hPadding, y + G.vPadding, w - G.hPadding * 2, h - G.vPadding * 2, style, taLeft)
    G.drawGuiString(getValueStr(value), x + G.hPadding, y + G.vPadding, w - G.hPadding * 2, h - G.vPadding * 2, style, taRight)

  if G.modalArea != 0:
    # check that we're underneath the modal G.area
    var inModalArea = false
    for a in G.areas:
      if a.id == G.modalArea:
        inModalArea = true
        break
    if not inModalArea:
      return

  result = G.downElement == G.element

  if G.e.kind == gMouseMove:
    if G.downElement == G.element:
      when T is SomeFloat:
        value = lerp(min,max,invLerp((x+1).float32,(x+1+w-2).float32,G.e.x.float32)).T
      else:
        value = flr(lerp(min.float32,max.float32,invLerp((x+1).float32,(x+w-2).float32,G.e.x.float32)) + 0.5'f).T
      value = clamp(value, min, max)

    if pointInRect(G.e.x, G.e.y, x, y, w, h):
      G.hoverElement = G.element
      G.activeHoverElement = if enabled and not hintBlocked: G.element else: 0

  if enabled == false or hintBlocked:
    return false

  if G.e.kind == gMouseDown:
    if pointInRect(G.e.x, G.e.y, x, y, w, h):
      G.downElement = G.element
      when T is not SomeFloat:
        G.dragIntTmp = value.float32

  elif G.e.kind == gMouseUp:
    if pointInRect(G.e.x, G.e.y, x, y, w, h):
      if G.downElement == G.element:
        G.activeElement = G.element
        G.downElement = 0
        return

  return

proc slider*[T](G: Gui, text: string, value: var T, min, max: T, w, h: int, enabled: bool = true): bool =
  let (x,y) = G.cursor(w,h)
  let ret = G.slider(text, value, min, max, x, y, w, h, enabled)
  G.advance(w,h)
  return ret

proc slider*[T](G: Gui, text: string, value: var T, min, max: T, enabled: bool = true): bool =
  assert(G.area != nil)
  let w = if G.hExpand: G.area.maxX - G.area.minX else: textWidth(text & ": " & getValueStr(value) & "  ") +  + G.hPadding * 2
  let h = if G.vExpand: G.area.maxY - G.area.minY else: fontHeight() * text.countLines() + G.vPadding * 2
  return G.slider(text, value, min, max, w, h, enabled)



proc dropDown*(G: Gui, strings: openarray[string], value: int, x,y,w,h: int, enabled: bool = true, keycode: Keycode = K_UNKNOWN): int =
  var value = value
  let ret = G.button(strings[value], x,y,w,h, enabled, keycode)
  if G.activeHoverElement == G.element:
    for i,s in strings:
      let r = G.button(s, x, y + (i + 1) * fontHeight(), w, h, i != value, K_UNKNOWN)
      if r:
        value = i
  return value

proc dropDown*(G: Gui, strings: openarray[string], value: int, w,h: int, enabled: bool = true, keycode: Keycode = K_UNKNOWN): int =
  let (x,y) = G.cursor(w,h)
  let ret = G.dropDown(strings,value,x,y,w,h,enabled,keycode)
  G.advance(w,h)
  return ret

proc dropDown*(G: Gui, strings: openarray[string], value: int, enabled: bool = true, keycode = K_UNKNOWN): int =
  let w = if G.hExpand: G.area.maxX - G.area.minX else: textWidth(strings[value]) + G.hPadding * 2
  let h = if G.vExpand: G.area.maxY - G.area.minY else: fontHeight() + G.vPadding * 2
  return G.dropDown(strings, value, w, h, enabled, keycode)


proc box*(G: Gui, x,y,w,h: int, style: GuiStyle = gInert) =
  if G.e.kind == gRepaint:
    # fill
    let cs = G.colorSets[G.outcome]
    setColor(case style:
      of gInert: cs.fill
      of gInteractable: cs.fill
      of gHovered: cs.fillHover
      of gInteracted: cs.fillInteract
      of gDisabled: cs.fillDisabled
    )
    rectfill(x+1,y+1,x+w-2,y+h-2)
    # outline
    setColor(case style:
      of gInert: cs.outline
      of gInteractable: cs.outline
      of gHovered: cs.outlineHover
      of gInteracted: cs.outlineInteract
      of gDisabled: cs.outlineDisabled
    )
    rrect(x,y,x+w-1,y+h-1)
  elif G.e.kind == gMouseMove:
    if pointInRect(G.e.x, G.e.y, x,y,w,h):
      G.hoverElement = G.element
      G.activeHoverElement = 0

proc sprite*(G: Gui, spr: int, x,y,w,h: int) =
  G.element += 1
  if G.e.kind == gRepaint:
    spr(spr, x, y)

proc ssprite*(G: Gui, spr: int, x,y,w,h: int, sw,sh: int) =
  G.element += 1
  if G.e.kind == gRepaint:
    let (tw,th) = spriteSize()
    spr(spr, if G.center: x + w div 2 - tw div 2 else: x, if G.center: y + h div 2 - th div 2 else: y, sw, sh)
  G.advance(w,h)

proc ssprite*(G: Gui, spr: int, w,h: int, sw,sh: int) =
  G.element += 1
  if G.e.kind == gRepaint:
    let (x,y) = G.cursor(w,h)
    let (tw,th) = spriteSize()
    spr(spr, if G.center: x + w div 2 - tw div 2 else: x, if G.center: y + h div 2 - th div 2 else: y, sw, sh)
  G.advance(w,h)

proc sprite*(G: Gui, spr: int, w,h: int) =
  G.element += 1
  if G.e.kind == gRepaint:
    let (x,y) = G.cursor(w,h)
    let (tw,th) = spriteSize()
    spr(spr, if G.center: x + w div 2 - tw div 2 else: x, if G.center: y + h div 2 - th div 2 else: y)
  G.advance(w,h)

proc sprite*(G: Gui, spr: int) =
  assert(G.area != nil)
  let (tw,th) = spriteSize()
  let w = if G.hExpand: G.area.maxX - G.area.minX else: tw
  let h = if G.vExpand: G.area.maxY - G.area.minY else: th
  G.sprite(spr, w, h)

proc empty*(G: Gui, w, h: int) =
  G.element += 1
  G.advance(w,h)

proc beginArea*(G: Gui, x,y,w,h: Pint, direction: GuiDirection = gTopToBottom, box: bool = false, modal: bool = false) =
  G.element += 1
  G.area = new(GuiArea)
  G.area.id = G.nextAreaId
  G.area.modal = modal
  G.currentAreaId = G.area.id
  G.area.minX = x + (if box: G.hPadding else: 0)
  G.area.minY = y + (if box: G.vPadding else: 0)
  G.area.maxX = x + w - 1 - (if box: G.hPadding else: 0)
  G.area.maxY = y + h - 1 - (if box: G.vPadding else: 0)
  G.area.cursorX = x
  G.area.cursorY = y

  G.areas.add(G.area)

  G.nextAreaId += 1

  G.area.direction = direction
  case G.area.direction:
  of gLeftToRight:
    G.area.cursorX = G.area.minX + G.hSpacing
    G.area.cursorY = G.area.minY
  of gRightoLeft:
    G.area.cursorX = G.area.maxX - G.hSpacing
    G.area.cursorY = G.area.minY
  of gTopToBottom:
    G.area.cursorX = G.area.minX
    G.area.cursorY = G.area.minY + G.vSpacing
  of gBottomToTop:
    G.area.cursorY = G.area.maxY - G.vSpacing
    G.area.cursorX = G.area.minX

  if modal:
    G.modalArea = G.currentAreaId

  if box:
    if modal:
      setColor(G.colorSets[gDefault].modalOutline)
      rrectfill(x-1,y-1,x+w,y+h)
    G.box(x,y,w,h)

proc endArea*(G: Gui) =
  if G.areas.len > 0:
    var lastArea = G.area
    G.area = nil
    G.areas.delete(G.areas.high)
    if G.areas.len == 0:
      G.currentAreaId = 0
    else:
      G.currentAreaId = G.areas[G.areas.high].id
      G.area = G.areas[G.areas.high]
      if lastArea.direction == gLeftToRight:
        G.area.cursorY = lastArea.maxY
      elif lastArea.direction == gTopToBottom:
        G.area.cursorX = lastArea.maxX

proc beginHorizontal*(G: Gui, height: int, box: bool = false) =
  let area = G.areas[G.areas.high]
  G.beginArea(area.cursorX, area.cursorY, area.maxX - area.cursorX, height, gLeftToRight, box)

proc beginVertical*(G: Gui, width: int, box: bool = false) =
  let area = G.areas[G.areas.high]
  G.beginArea(area.cursorX, area.cursorY, width, area.maxY - area.cursorY, gTopToBottom, box)

proc draw*(G: Gui, onGui: proc()) =
  frame += 1
  G.nextAreaId = 1
  G.currentAreaId = 0
  G.element = 0
  G.e.kind = gRepaint
  onGui()
  if G.areas.len != 0:
    echo "ERROR: G.area was not ended correctly"

proc update*(G: Gui, onGui: proc(), dt: float32) =
  G.currentAreaId = 0
  G.activeElement = 0
  G.nextAreaId = 1
  let (mx,my) = mouse()
  let (mxrel,myrel) = mouseRel()
  var lastCount = 0
  if mx != lastMouseX or my != lastMouseY:
    G.currentAreaId = 0
    G.nextAreaId = 1
    G.hoverElement = 0
    G.activeHoverElement = 0
    G.e.kind = gMouseMove
    G.e.x = mx
    G.e.y = my
    G.e.xrel = mxrel
    G.e.yrel = myrel
    G.element = 0
    onGui()
    lastCount = G.element
  lastMouseX = mx
  lastMouseY = my
  if mousebtnp(0):
    G.currentAreaId = 0
    G.nextAreaId = 1
    G.e.kind = gMouseDown
    G.e.x = mx
    G.e.y = my
    G.element = 0
    onGui()
    G.wasMouseDown = true
  if mousebtnup(0):
    G.currentAreaId = 0
    G.nextAreaId = 1
    G.e.kind = gMouseUp
    G.element = 0
    onGui()
    G.wasMouseDown = false
    G.downElement = 0
  if anyKeyp():
    G.currentAreaId = 0
    G.nextAreaId = 1
    G.e.kind = gKeyDown
    G.element = 0
    onGui()
  if G.modalArea > G.areas.len:
    G.modalArea = 0

