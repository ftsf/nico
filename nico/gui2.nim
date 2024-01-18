import std/[tables, algorithm, strformat]
import nico
import nico/debug

# gui inspired by Dear Imgui
const hPadding = 4
const vPadding = 2
const hSpacing = 2
const vSpacing = 2
const titleBarHeight = 10
const resizeBarHeight = 3
const scrollBarWidth = 5

type Rect = object
  x,y,w,h: int

proc offset(a: Rect, x = 0, y = 0): Rect =
  result = a
  result.x += x
  result.y += y

proc setSize(a: Rect, w = -1, h = -1): Rect =
  result = a
  if w >= 0:
    result.w = w
  if h >= 0:
    result.h = h

func makeRect(x,y,w,h: int): Rect =
  result = Rect(x: x, y: y, w: w, h: h)

proc clipRect(rect: Rect) =
  clip(rect.x, rect.y, rect.w, rect.h)

proc debugRect(rect: Rect, color: int = 8) =
  debugBox(rect.x, rect.y, rect.w-1, rect.h-1, color)

proc inflate(a: Rect, v: int): Rect =
  result = a
  result.x -= v
  result.y -= v
  result.w += v * 2
  result.h += v * 2

proc expandRect(a,b: Rect): Rect =
  # expands a to include b
  let minx = min(a.x, b.x)
  let maxx = max(a.x + a.w - 1, b.x + b.w - 1)
  let miny = min(a.y, b.y)
  let maxy = max(a.y + a.h - 1, b.y + b.h - 1)
  result.x = minx
  result.y = miny
  result.w = maxx - minx
  result.h = maxy - miny

proc maxx(rect: Rect): int =
  return rect.x + rect.w - 1

proc maxy(rect: Rect): int =
  return rect.y + rect.h - 1

proc addPadding(rect: Rect): Rect =
  result = rect
  result.x += hPadding
  result.y += vPadding
  result.w -= hPadding * 2
  result.h -= vPadding * 2

proc addPadding(rect: Rect, x,y: int): Rect =
  result = rect
  result.x += x
  result.y += y
  result.w -= x * 2
  result.h -= y * 2

proc leftHalf(rect: Rect): Rect =
  result = rect
  result.w = result.w div 2

proc rightHalf(rect: Rect): Rect =
  result = rect
  result.x += rect.w div 2
  result.w = result.w div 2

proc rightSplit(rect: Rect, fromRight: int): Rect =
  result = rect
  result.x += rect.w - fromRight
  result.w = fromRight

proc clipRect(a,b: Rect): Rect =
  # returns a clipped by b
  let minx = max(a.x, b.x)
  let maxx = min(a.x + a.w - 1, b.x + b.w - 1)
  let miny = max(a.y, b.y)
  let maxy = min(a.y + a.h - 1, b.y + b.h - 1)
  result.x = minx
  result.y = miny
  result.w = (maxx - minx) + 1
  result.h = (maxy - miny) + 1

func pointInRect(x,y: int, rect: Rect): bool =
  return x >= rect.x and x <= rect.x + rect.w - 1 and y >= rect.y and y <= rect.y + rect.h - 1

type WindowData = ref object
  name: string
  parent: string
  open: bool
  rect: Rect
  contentRect: Rect
  scrollX,scrollY: int
  hasScrollX,hasScrollY: bool
  hasTitleBar: bool

type GuiAlign = enum
  alignDefault
  alignLeft
  alignCenter
  alignRight

type RenderType = enum
  rtBox
  rtText

type RenderStyle* = enum
  rsBasic
  rsFlat
  rsOutset
  rsInset
  rsDisabled
  rsOutline
  rsTitlebar
  rsFocusOutline
  rsCheckboxChecked
  rsCheckboxUnchecked
  rsFillBar

type RenderStatus* = enum
  Default
  Primary
  Good
  Warning
  Danger

type RenderData = object
  kind: RenderType
  rect: Rect
  clippedRect: Rect
  status: RenderStatus
  style: RenderStyle
  focus: bool
  data: string
  align: GuiAlign
  order: int

type GuiBoxDrawFunc* = proc(x,y,w,h: int, style: RenderStyle, status: RenderStatus, focus: bool)
type GuiTextDrawFunc* = proc(text: string, x,y,w,h: int, style: RenderStyle, status: RenderStatus, align: GuiAlign, focus: bool)

type GuiSkin* = object
  textFlat*: int
  textInset*: int
  textOutset*: int
  textTitlebar*: int
  fillTitlebar*: int
  fillFlat*: int
  fillInset*: int
  outlineFlat*: int
  outlineLit*: int
  outlineDark*: int
  outlineFocus*: int
  fillBar*: int
  fillBarOutline*: int

var skin: array[RenderStatus, GuiSkin]
skin[Default].textFlat = 1
skin[Default].textTitlebar = 7
skin[Default].fillTitlebar = 12
skin[Default].fillFlat = 13
skin[Default].fillInset = 5
skin[Default].outlineFlat = 5
skin[Default].outlineLit = 6
skin[Default].outlineDark = 1
skin[Default].outlineFocus = 10
skin[Default].fillBar = 12
skin[Default].fillBarOutline = 1

skin[Primary].textFlat = 12
skin[Primary].textTitlebar = 7
skin[Primary].fillTitlebar = 12
skin[Primary].fillFlat = 13
skin[Primary].fillInset = 5
skin[Primary].outlineFlat = 5
skin[Primary].outlineLit = 6
skin[Primary].outlineDark = 1
skin[Primary].outlineFocus = 10
skin[Primary].fillBar = 12
skin[Primary].fillBarOutline = 1

skin[Warning].textFlat = 9
skin[Warning].textTitlebar = 7
skin[Warning].fillTitlebar = 12
skin[Warning].fillFlat = 13
skin[Warning].fillInset = 5
skin[Warning].outlineFlat = 5
skin[Warning].outlineLit = 6
skin[Warning].outlineDark = 1
skin[Warning].outlineFocus = 10
skin[Warning].fillBar = 12
skin[Warning].fillBarOutline = 1

proc boxDraw(x,y,w,h: int, fill,outline: int) =
  setColor(fill)
  if w < 4 or h < 4:
    boxfill(x,y,w,h)
  else:
    rboxfill(x,y,w,h)

  if w > 2 and h > 2:
    setColor(outline)
    if w < 4 or h < 4:
      box(x,y,w,h)
    else:
      rbox(x,y,w,h)

var guiBoxDrawFunc: GuiBoxDrawFunc = proc(x,y,w,h: int, style: RenderStyle, status: RenderStatus, focus: bool) =
  if style == rsBasic:
    return

  if style == rsFillBar:
    boxDraw(x,y,w,h, skin[status].fillBar, skin[status].fillBarOutline)
    return

  if style == rsCheckboxChecked:
    setColor(skin[status].fillFlat)
    rboxfill(x,y,w,h)
    setColor(skin[status].outlineDark)
    rbox(x,y,w,h)
    setColor(skin[status].outlineDark)
    boxfill(x+2,y+2,w-4,h-4)
    return
  if style == rsCheckboxUnchecked:
    setColor(skin[status].fillInset)
    rboxfill(x,y,w,h)
    setColor(skin[status].outlineDark)
    rbox(x,y,w,h)
    return

  if style == rsFocusOutline:
    setColor(skin[status].outlineFocus)
    rbox(x,y,w,h)
    return

  if style != rsOutline:
    if style == rsTitlebar:
      setColor(skin[status].fillTitlebar)
    elif style == rsInset:
      setColor(skin[status].fillInset)
    else:
      setColor(skin[status].fillFlat)
    rboxfill(x,y,w,h)

  setColor(skin[status].outlineFlat)
  rbox(x,y,w,h)

  case style:
  of rsOutset:
    setColor(skin[status].outlineLit)
    hline(x+1,y,x+w-2)
    setColor(skin[status].outlineDark)
    hline(x+1,y+h-1,x+w-2)

    if focus:
      setColor(skin[status].outlineDark)
      hline(x+2,y+h-2,x+w-4)

  of rsInset:
    setColor(skin[status].outlineDark)
    hline(x+1,y,x+w-2)
    setColor(skin[status].outlineLit)
    hline(x+1,y+h-1,x+w-2)

    if focus:
      setColor(skin[status].outlineFocus)
      hline(x+1,y+h-1,x+w-2)
  else:
    discard


var guiTextDrawFunc: GuiTextDrawFunc = proc(text: string, x,y,w,h: int, style: RenderStyle, status: RenderStatus, align: GuiAlign, focus: bool) =
  if style == rsTitlebar:
    setColor(skin[status].textTitlebar)
  else:
    setColor(skin[status].textFlat)

  var align = align
  if align == alignDefault:
    if style == rsOutset:
      align = alignCenter
    else:
      align = alignLeft

  if align == alignLeft:
    print(text, x, y + h div 2 - fontHeight() div 2)
  elif align == alignCenter:
    printc(text, x + w div 2, y + h div 2 - fontHeight() div 2)
  elif align == alignRight:
    printr(text, x + w - 1, y + h div 2 - fontHeight() div 2)

proc guiSetBoxDrawFunc*(f: GuiBoxDrawFunc) =
  guiBoxDrawFunc = f

var
  nextX = 5
  nextY = 5
  nextW = -1
  nextH = -1
  nextOrder = 0
  nextStatus = Default
var lineStart = 0

var sameLine = false
var noAdvance = false

var lineHeight = fontHeight()

var lastMouseX = 0
var lastMouseY = 0

var windowData = initTable[string, WindowData]()
var currentWindow: string = ""
var windowDrag: string = ""
var windowDragOffset: (int,int)
var windowResize: string = ""
var windowResizeBottomLeft: bool
var windowScroll: string = ""

var currentElement: int
var activeElement: int
var dragElement: int
var textInputElement: int
var textInputEventListener: EventListener
var hoveredElement: int
var hoveredWindow: string

var dragIntTmp: float32
var dragIntTmp2: float32

proc `/`(a,b: string): string =
  result = a & "/" & b

proc guiHoveredElement*(): int =
  return hoveredElement

proc guiActiveElement*(): int =
  return activeElement

proc guiSetStatus*(status: RenderStatus) =
  nextStatus = status

var renderData: seq[RenderData]

var disableClipping: bool

proc contentArea(window: WindowData): Rect =
  result = window.rect
  result.x += hPadding
  result.y += vPadding
  result.w -= hPadding * 2
  result.h -= vPadding * 2

  if window.hasTitleBar:
    result.y += titleBarHeight
    result.h -= titleBarHeight

  if window.hasScrollY:
    result.w -= scrollBarWidth

  result.h -= 1

proc clipCurrentWindow(a: Rect): Rect =
  result = a
  if currentWindow != "" and not disableClipping and windowData.hasKey(currentWindow):
    result = a.clipRect(windowData[currentWindow].contentArea)
    var parent = windowData[currentWindow].parent
    while parent != "":
      result = result.clipRect(windowData[parent].contentArea)
      parent = windowData[parent].parent

proc paddedWidth*(window: WindowData): int =
  result = window.rect.w - hPadding * 2
  if window.hasScrollY:
    result -= scrollBarWidth

proc scrollCurrentWindow(a: Rect): Rect =
  result = a
  if currentWindow != "" and not disableClipping and windowData.hasKey(currentWindow):
    var window = windowData[currentWindow]
    result.x -= window.scrollX
    result.y -= window.scrollY

proc addRenderData(rd: RenderData) =
  var rd = rd
  if currentWindow != "":
    if not disableClipping:
      windowData[currentWindow].contentRect = windowData[currentWindow].contentRect.expandRect(rd.rect)
    rd.order = nextOrder
    rd.rect = rd.rect.scrollCurrentWindow()
    rd.clippedRect = rd.rect.clipCurrentWindow()
    renderData.add(rd)

proc guiStartFrame*() =
  currentWindow = ""
  currentElement = 0

  if not mousebtn(0) and not mousebtnup(0):
    dragElement = 0

  if mousebtnp(0):
    activeElement = 0

  hoveredElement = 0
  nextX = hPadding
  nextY = vPadding
  nextW = -1
  nextH = -1
  nextStatus = Default
  renderData.setLen(0)
  sameLine = false
  disableClipping = false
  lineHeight = fontHeight()

  if windowDrag != "":
    if mousebtn(0):
      let (mx,my) = mouse()
      windowData[windowDrag].rect.x = mx - windowDragOffset[0]
      windowData[windowDrag].rect.y = my - windowDragOffset[1]
    else:
      windowDrag = ""

  if windowResize != "":
    if mousebtn(0):
      let (mx,my) = mouse()
      if windowResizeBottomLeft:
        let origX = windowData[windowResize].rect.x
        let diff = origX - mx
        windowData[windowResize].rect.x = mx
        windowData[windowResize].rect.w += diff
      else:
        windowData[windowResize].rect.w = mx - windowData[windowResize].rect.x
      if windowData[windowResize].open:
        windowData[windowResize].rect.h = my - windowData[windowResize].rect.y
    else:
      windowResize = ""

  if windowScroll != "":
    if mousebtn(0):
      let (mx,my) = mouse()
      var window = windowData[windowScroll]
      let scrollRange = window.contentRect.h - window.rect.h
      let scrollSize = window.rect.h.float32 / window.contentRect.h.float32
      let scrollBarHeight = window.rect.h - (if window.hasTitleBar: titleBarHeight else: 0)
      let scrollBarHandleHeight = (scrollSize * scrollBarHeight.float32).int
      let scrollHandleMovement = scrollBarHeight - scrollBarHandleHeight
      let scrollAmountY = clamp((my - windowDragOffset[1] - (window.rect.y + titleBarHeight )).float32 / scrollHandleMovement.float32, 0f, 1f)
      window.scrollY = (scrollRange.float32 * scrollAmountY).int
    else:
      windowScroll = ""

  if hoveredWindow != "":
    let mw = mousewheel()
    if mw != 0:
      var window = windowData[hoveredWindow]
      window.scrollY -= mw * 8
      let scrollRange = window.contentRect.h - window.rect.h
      window.scrollY = clamp(window.scrollY, 0, scrollRange)
      let scrollSize = window.rect.h.float32 / window.contentRect.h.float32
      let scrollBarHeight = window.rect.h - (if window.hasTitleBar: titleBarHeight else: 0)
      let scrollBarHandleHeight = (scrollSize * scrollBarHeight.float32).int
      #let scrollHandleMovement = scrollBarHeight - scrollBarHandleHeight
      #window.scrollAmountY = window.scrollY.float32 / scrollRange.float32


  hoveredWindow = ""



proc guiBegin*(name: string = "", titleBar = true, resizable = true, movable = true, scrollable = true): bool
proc guiEnd*()

# modifiers
proc guiSetSameLine*(on: bool) = # next widget will be on the same line
  sameLine = on

proc guiPos*(x,y: int) = # next widget will be at x,y
  nextX = x
  nextY = y

proc guiSize*(w,h: int = -1) = # next widget will have specified size, -1 = auto size on axis
  if w != -1:
    nextW = w
  if h != -1:
    nextH = h

proc guiWindowOpen*(name: string): bool =
  if windowData.hasKey(name):
    return windowData[name].open

proc guiGetCursor*(): (int,int) =
  result = (nextX,nextY)

proc guiSetCursor*(x,y: int = int.low) = # next widget will be offset by x,y, -1 = default
  if x != int.low:
    nextX = x
  if y != int.low:
    nextY = y

proc guiPreAdvance(rect: var Rect) =
  if noAdvance:
    return

  #debugRect(rect)
  #debugRect(windowData[currentWindow].rect.inflate(1), 11)
  #debugRect(windowData[currentWindow].contentArea.inflate(1), 12)
  # moves cursor to next line if not enough space for rect, if not already at start of line
  if sameLine:
    if nextX == windowData[currentWindow].rect.x + hPadding:
      # already at start of line
      return
    if rect.maxx > windowData[currentWindow].contentArea.maxx:
      nextX = windowData[currentWindow].rect.x + hPadding
      nextY += lineHeight + vSpacing
      rect.x = nextX
      rect.y = nextY

proc guiAdvance(rect: Rect) =
  if noAdvance:
    return
  # moves cursor to position for next element
  if sameLine:
    nextX += rect.w + hSpacing
  else:
    nextY += rect.h + vSpacing
    if currentWindow != "":
      nextX = windowData[currentWindow].rect.x + hPadding

proc guiAdvanceNoSpace(rect: Rect) =
  if noAdvance:
    return
  # moves cursor to position for next element
  if sameLine:
    nextX += rect.w
  else:
    nextY += rect.h
    if currentWindow != "":
      nextX = windowData[currentWindow].rect.x + hPadding

proc guiSetLineHeight*(height: int) =
  if height < 0:
    lineHeight = fontHeight()
  else:
    lineHeight = height

proc guiNewLine*() =
  nextY += 10 + vSpacing
  if currentWindow != "":
    nextX = windowData[currentWindow].rect.x + hPadding

template guiHorizontal*(body: untyped): untyped =
  let startX = nextX
  let startY = nextY
  guiSetSameLine(true)
  body
  guiSetSameLine(false)
  guiAdvance(makeRect(startX, startY, 0, lineHeight))

template guiHorizontal*(height: int = -1, body: untyped): untyped =
  let startX = nextX
  let startY = nextY
  if height != -1:
    guiSetLineHeight(height)
  guiSetSameLine(true)
  body
  guiSetSameLine(false)
  guiAdvance(makeRect(startX, startY, 0, lineHeight))
  guiSetLineHeight(-1)

template guiNoAdvance*(body: untyped): untyped =
  noAdvance = true
  body
  noAdvance = false

# primitives
proc guiResetOverrides*() =
  nextW = -1
  nextH = -1

proc getNextWidth(default = -1): int =
  if nextW == -1:
    if default == -1:
      return windowData[currentWindow].paddedWidth()
    return default
  return nextW

proc getNextHeight(default = -1): int =
  if nextH == -1:
    if default == -1:
      return lineHeight
    return default
  return nextH

proc getBoxRect*(padding = false): Rect =
  let w = getNextWidth()
  let h = getNextHeight() + hPadding * 2
  return makeRect(nextX, nextY, w, h)

proc guiBasicBox*(rect: Rect, style: RenderStyle = rsFlat): Rect {.discardable} =
  addRenderData(RenderData(kind: rtBox, rect: rect, style: style, status: nextStatus))
  return rect

proc guiBasicBox*(w = -1, h = -1, style: RenderStyle = rsFlat): Rect {.discardable} =
  var w = w
  var h = h
  if w == -1 and not sameLine and currentWindow != "":
    w = windowData[currentWindow].paddedWidth()
  if nextW != -1:
    w = nextW
  if nextH != -1:
    h = nextH
  let rect = makeRect(nextX, nextY, w, h)
  addRenderData(RenderData(kind: rtBox, rect: rect, style: style, status: nextStatus))
  return rect

proc getTextRect*(text: string, padding = false): Rect =
  var w = textWidth(text) + (if padding: hPadding * 2 else: 0)
  var h = lineHeight + (if padding: vPadding else: 0)
  if not sameLine and currentWindow != "":
    w = windowData[currentWindow].paddedWidth()
  if nextW != -1:
    w = nextW
  if nextH != -1:
    h = nextH
  return makeRect(nextX, nextY, w, h)

proc guiBasicText*(text: string, style: RenderStyle = rsFlat, align = alignDefault): Rect {.discardable} =
  var w = textWidth(text)
  var h = lineHeight
  if not sameLine and currentWindow != "":
    w = windowData[currentWindow].paddedWidth()

  let rect = makeRect(nextX, nextY, w, h)
  addRenderData(RenderData(kind: rtText, data: text, rect: rect, style: style, align: align, status: nextStatus))
  return rect

proc guiBasicTextBox*(text: string, style: RenderStyle = rsFlat, align = alignDefault, focus = false, rect: Rect): Rect {.discardable} =
  addRenderData(RenderData(kind: rtBox, rect: rect, style: style, focus: focus, status: nextStatus))
  addRenderData(RenderData(kind: rtText, data: text, rect: rect.addPadding(1,1), style: style, focus: focus, align: align, status: nextStatus))
  return rect

proc guiBasicTextBox*(text: string, style: RenderStyle = rsFlat, align = alignDefault, focus = false): Rect {.discardable} =
  var w = textWidth(text) + hPadding * 2
  var h = lineHeight + vPadding * 2
  if not sameLine and currentWindow != "":
    w = windowData[currentWindow].paddedWidth()

  var rect = makeRect(nextX, nextY, w, h)
  if nextW != -1:
    rect.w = nextW
  if nextH != -1:
    rect.h = nextH
  addRenderData(RenderData(kind: rtBox, rect: rect, style: style, focus: focus, status: nextStatus))
  addRenderData(RenderData(kind: rtText, data: text, rect: rect.addPadding(1,1), style: style, focus: focus, align: align, status: nextStatus))
  return rect

# widgets
proc guiLabel*(label: string) =
  currentElement += 1
  var rect = getTextRect(label)
  if nextW != -1:
    rect.w = nextW
  if nextH != -1:
    rect.h = nextH
  guiPreAdvance(rect)
  addRenderData(RenderData(kind: rtText, data: label, rect: rect, status: nextStatus))
  guiAdvance(rect)
  guiResetOverrides()

#proc guiCheckbox*(label: string, val: var bool): bool {.discardable.} =
#  guiText(label)
#  guiSameLine()
#
#  guiNoAdvance()
#  guiBox(4,4)
#  if val:
#    guiText("X")
#

proc guiButton*(label: string, box = true): bool =
  currentElement += 1
  var rect = getTextRect(label, true)
  guiPreAdvance(rect)
  let (mx,my) = mouse()
  let focus = windowDrag == "" and windowScroll == "" and windowResize == "" and pointInRect(mx,my, rect.scrollCurrentWindow().clipCurrentWindow())
  if box:
    guiBasicTextBox(label, if dragElement == currentElement: rsInset else: rsOutset, focus = focus, align = alignCenter)
  else:
    guiBasicText(label, rsFlat, align = alignLeft)

  if focus:
    hoveredElement = currentElement
  if focus and mousebtnp(0):
    activeElement = currentElement
    dragElement = currentElement

  if dragElement == currentElement and focus and mousebtnup(0):
    result = true

  guiAdvance(rect)
  guiResetOverrides()

proc guiToggle*(label: string, val: var bool): bool {.discardable} =
  # draws a checkbox toggle
  currentElement += 1
  var rect = getTextRect(label, true)
  guiPreAdvance(rect)
  let (mx,my) = mouse()
  let focus = windowDrag == "" and windowScroll == "" and windowResize == "" and pointInRect(mx,my, rect.scrollCurrentWindow().clipCurrentWindow())
  guiBasicTextBox(" " & label, if val or dragElement == currentElement: rsInset else: rsOutset, focus = focus, align = alignLeft)
  guiBasicBox(rect.rightSplit(10).setSize(6,6).offset(x = -hPadding, y = 2), if val: rsCheckboxChecked else: rsCheckboxUnchecked)

  if focus:
    hoveredElement = currentElement
  if focus and mousebtnp(0):
    activeElement = currentElement
    dragElement = currentElement

  if dragElement == currentElement and focus and mousebtnup(0):
    val = not val
    result = true

  guiAdvance(rect)
  guiResetOverrides()

proc guiBegin*(name: string = "", titleBar = true, resizable = true, movable = true, scrollable = true): bool =
  currentElement += 1
  windowData.withValue(name, value) do:
    result = value.open
  do:
    if currentWindow == "":
      let w = if nextW == -1: screenWidth - hPadding * 2 else: nextW
      let h = if nextW == -1: screenHeight - vPadding * 2 else: nextH
      windowData[name] = WindowData(open: true, parent: currentWindow, rect: makeRect(nextX, nextY, w, h), hasTitleBar: titleBar)
    else:
      let w = if nextW == -1: windowData[currentWindow].contentArea.w else: nextW
      let h = if nextW == -1: windowData[currentWindow].contentArea.h else: nextH
      windowData[name] = WindowData(open: true, parent: currentWindow, rect: makeRect(nextX, nextY, w, h), hasTitleBar: false)
    result = true

  var window = windowData[name]
  let (mx,my) = mouse()

  currentWindow = name
  if result:
    if pointInRect(mx,my, window.rect):
      hoveredElement = currentElement
      hoveredWindow = name

      if mousebtnp(0):
        dragElement = currentElement
        activeElement = currentElement

    # draw window frame
    renderData.add(RenderData(kind: rtBox, rect: window.rect, clippedRect: window.rect, style: rsFlat))

    nextX = window.rect.x + hPadding
    nextY = window.rect.y + (if titleBar: titleBarHeight else: 0) + vPadding

    # scrollBarRectY
    window.hasScrollY = scrollable and window.contentRect.h > window.rect.h
    if window.hasScrollY:
      window.hasScrollY = true
      var scrollBarRectY = window.rect

      if titleBar:
        scrollBarRectY.y += titleBarHeight
        scrollBarRectY.h -= titleBarHeight

      scrollBarRectY.x += scrollBarRectY.w - 5
      scrollBarRectY.w = 5
      var scrollBarRectYHandle = scrollBarRectY

      let scrollSize = window.rect.h.float32 / window.contentRect.h.float32
      let scrollRange = window.contentRect.h - window.rect.h
      let scrollAmount = window.scrollY.float32 / scrollRange.float32

      scrollBarRectYHandle.h = (scrollSize * scrollBarRectY.h.float32).int

      let scrollHandleMovement = scrollBarRectY.h - scrollBarRectYHandle.h
      #echo &"{name} content: {window.contentRect.h} window: {window.rect.h} scrollSize: {scrollSize:0.2f} scrollY: {window.scrollY} scrollAmount: {scrollAmount:0.2f} movement: {scrollHandleMovement}"

      scrollBarRectYHandle.y = scrollBarRectY.y + (scrollAmount * scrollHandleMovement.float32).int
      renderData.add(RenderData(kind: rtBox, rect: scrollBarRectY, clippedRect: scrollBarRectY, style: rsInset))
      renderData.add(RenderData(kind: rtBox, rect: scrollBarRectYHandle, clippedRect: scrollBarRectYHandle, style: rsOutset))

      if mousebtnp(0) and pointInRect(mx,my, scrollBarRectYHandle):
        windowScroll = name
        windowDragOffset = (mx - scrollBarRectYHandle.x, my - scrollBarRectYHandle.y)

  if titleBar:
    disableClipping = true
    var titleBarRect = window.rect
    titleBarRect.h = titleBarHeight
    renderData.add(RenderData(kind: rtBox, rect: titleBarRect, clippedRect: titleBarRect, style: rsTitlebar))
    renderData.add(RenderData(kind: rtText, data: name, rect: titleBarRect.addPadding(2,1), clippedRect: titleBarRect.addPadding(2,1), style: rsTitlebar))

    # minimize button
    guiNoAdvance:
      let (lastX,lastY) = guiGetCursor()
      guiSetCursor(titlebarRect.x + titlebarRect.w - 10, titlebarRect.y)
      guiSize(10, titleBarHeight)
      if guiButton(if result: "-" else: "+"):
        window.open = not window.open
      guiSetCursor(lastX, lastY)

    if mousebtnp(0) and pointInRect(mx,my, titleBarRect):
      windowDrag = name
      windowDragOffset = (mx - titlebarRect.x, my - titlebarRect.y)
    disableClipping = false

  if resizable:
    let h = if result: window.rect.h else: titleBarHeight + resizeBarHeight

    disableClipping = true
    # resizeBarRect
    var resizeBarRect = window.rect
    resizeBarRect.y += h - resizeBarHeight
    resizeBarRect.h = resizeBarHeight
    renderData.add(RenderData(kind: rtBox, rect: resizeBarRect, clippedRect: resizeBarRect, style: rsFlat))

    if mousebtnp(0) and pointInRect(mx,my, resizeBarRect):
      windowResize = name
      windowResizeBottomLeft = mx < resizeBarRect.x + resizeBarRect.w div 2
      windowDragOffset = (mx - resizeBarRect.x, my - resizeBarRect.y)

    disableClipping = false

  if result:
    window.contentRect = window.rect
    window.contentRect.x += hPadding
    window.contentRect.y += vPadding
    window.contentRect.w = 0
    window.contentRect.h = 0




proc guiStartFoldout*(name: string = ""): bool =
  currentElement += 1
  windowData.withValue(name, value) do:
    result = value.open
  do:
    windowData[name] = WindowData(open: false)
    result = false
  if guiButton((if windowData[name].open: "- " else: "+ ") & name, box = false):
    windowData[name].open = not windowData[name].open

proc guiEndFoldout*() =
  guiBasicBox(windowData[currentWindow].rect.w, 1)
  nextY += lineHeight

template guiFoldout*(name: string, body: untyped): untyped =
  if guiStartFoldout(name):
    body
    guiEndFoldout()

proc guiDrag*[T](name: string, val: var T, min: T = T.low, max: T = T.high, speed = 0.1f): bool {.discardable.} =
  currentElement += 1
  let rect = guiBasicBox(h = lineHeight + vPadding * 2, style = rsInset)
  let oldNextY = nextY
  nextY += vPadding
  guiBasicText(&" {name}", rsFlat, align = alignLeft)
  when T is SomeFloat:
    guiBasicText(&"{val:0.2f} ", rsFlat, align = alignRight)
  else:
    guiBasicText(&"{val} ", rsFlat, align = alignRight)
  nextY = oldNextY

  let (mx,my) = mouse()
  let focus = windowDrag == "" and windowScroll == "" and windowResize == "" and pointInRect(mx,my, rect.scrollCurrentWindow().clipCurrentWindow())
  if focus:
    hoveredElement = currentElement
  if focus and mousebtnp(0):
    activeElement = currentElement
    dragElement = currentElement
    when T is SomeInteger:
      dragIntTmp = val.float32

  if dragElement == currentElement:
    var speed = speed
    if key(K_LSHIFT) and key(K_LCTRL):
      speed *= 0.01f
    elif key(K_LSHIFT):
      speed *= 0.1f
    elif key(K_LCTRL):
      speed *= 10f

    when T is SomeInteger:
      dragIntTmp = dragIntTmp + mouseRel()[0] * speed
      val = dragIntTmp.int.clamp(min, max)
    else:
      val = clamp(val + mouseRel()[0] * speed, min, max)
    result = true

  guiAdvance(rect)

proc guiDrag*[T](name: string, val: var T, default: T, min: T = T.low, max: T = T.high, speed = 0.1f): bool {.discardable.} =
  currentElement += 1
  let rect = guiBasicBox(h = lineHeight + vPadding * 2, style = rsInset)
  let oldNextY = nextY
  nextY += vPadding
  guiBasicText(&" {name}", rsFlat, align = alignLeft)
  when T is SomeFloat:
    guiBasicText(&"{val:0.2f} ", rsFlat, align = alignRight)
  else:
    guiBasicText(&"{val} ", rsFlat, align = alignRight)
  nextY = oldNextY

  let (mx,my) = mouse()
  let focus = windowDrag == "" and windowScroll == "" and windowResize == "" and pointInRect(mx,my, rect.scrollCurrentWindow().clipCurrentWindow())
  if focus:
    hoveredElement = currentElement
  if focus and mousebtnp(0):
    dragElement = currentElement
    activeElement = currentElement
    when T is SomeInteger:
      dragIntTmp = val.float32
  if focus and mousebtnp(2):
    # reset to default value when right clicking
    val = default

  if dragElement == currentElement:
    var speed = speed
    if key(K_LSHIFT) and key(K_LCTRL):
      speed *= 0.01f
    elif key(K_LSHIFT):
      speed *= 0.1f
    elif key(K_LCTRL):
      speed *= 10f

    when T is SomeInteger:
      dragIntTmp = dragIntTmp + mouseRel()[0] * speed
      val = dragIntTmp.int.clamp(min, max)
    else:
      val = clamp(val + mouseRel()[0] * speed, min, max)
    result = true

  guiAdvance(rect)

proc guiSlider*[T](name: string, val: var T, default: T = default(T), min: T, max: T, showDefault = false): bool {.discardable.} =
  currentElement += 1
  let rect = guiBasicBox(h = lineHeight + vPadding * 2, style = rsInset)
  let range = max - min
  let fillAmount = (val - min).float32 / range.float32
  guiBasicBox(h = lineHeight + vPadding * 2, w = (rect.w.float32 * fillAmount).int, style = rsFillBar)
  let oldNextY = nextY
  nextY += vPadding
  guiBasicText(&" {name}", rsFlat, align = alignLeft)
  when T is SomeFloat:
    guiBasicText(&"{val:0.2f} ", rsFlat, align = alignRight)
  else:
    guiBasicText(&"{val} ", rsFlat, align = alignRight)
  nextY = oldNextY

  let (mx,my) = mouse()
  let drawRect = rect.scrollCurrentWindow().clipCurrentWindow()
  let focus = windowDrag == "" and windowScroll == "" and windowResize == "" and pointInRect(mx,my, drawRect)
  if focus:
    hoveredElement = currentElement
  if focus and mousebtnp(0):
    dragElement = currentElement
  if focus and mousebtnp(2):
    val = default

  if dragElement == currentElement:
    let fillAmount = clamp01((mx - drawRect.x).float32 / drawRect.w.float32)
    if key(K_LSHIFT):
      let tval = lerp(min.float32, max.float32, fillAmount).T
      val = lerp(val.float32, tval.float32, 0.1f).T
    else:
      val = lerp(min.float32, max.float32, fillAmount).T
    result = true

  guiAdvance(rect)

var multiSliderIndex = 0

proc guiMultiSliderLastIndex*(): int =
  return multiSliderIndex

proc guiMultiSlider*[T](vals: var openArray[T], min: T, max: T): bool {.discardable.} =
  # multiple sliders that can be tweaked by dragging over them
  currentElement += 1
  # label
  let (mx,my) = mouse()
  assert(min < max)
  let range = max - min
  lineHeight = 4
  var index = 0
  multiSliderIndex = -1
  for val in vals.mitems:
    val = clamp(val, min, max)
    let rect = guiBasicBox(h = lineHeight + vPadding * 2, style = rsInset)
    let fillAmount = clamp01((val - min).float32 / range.float32)
    # fillbar
    guiBasicBox(h = lineHeight + vPadding * 2, w = (rect.w.float32 * fillAmount).int, style = rsFillBar)
    let oldNextY = nextY

    let drawRect = rect.scrollCurrentWindow().clipCurrentWindow()
    let focus = windowDrag == "" and windowScroll == "" and windowResize == "" and pointInRect(mx,my, drawRect)
    if focus:
      multiSliderIndex = index
      hoveredElement = currentElement
    if focus and mousebtnp(0):
      dragElement = currentElement
      activeElement = currentElement

    if dragElement == currentElement and focus:
      let fillAmount = clamp01((mx - drawRect.x).float32 / drawRect.w.float32)
      if key(K_LSHIFT):
        let tval = lerp(min.float32, max.float32, fillAmount).T
        val = lerp(val.float32, tval.float32, 0.1f).T
      else:
        val = lerp(min.float32, max.float32, fillAmount).T
      multiSliderIndex = index
      result = true
    index += 1
    guiAdvanceNoSpace(rect)
  lineHeight = fontHeight()
  guiAdvance(makeRect(0,0,0,0))

proc guiMultiSliderV*[T](vals: var openArray[T], min: T, max: T): bool {.discardable.} =
  # multiple vertical sliders that can be tweaked by dragging over them
  currentElement += 1
  # label
  let (mx,my) = mouse()
  assert(min < max)
  let range = max - min
  let contentWidth = getNextWidth()
  let colWidth = contentWidth div vals.len
  let colHeight = getNextHeight(32)

  let oldNextX = nextX

  let contentRect = makeRect(nextX, nextY, contentWidth, colHeight)

  multiSliderIndex = -1
  var index = 0
  for val in vals.mitems:
    val = clamp(val, min, max)
    let colRect = makeRect(nextX, nextY, colWidth, colHeight)
    let fillAmount = clamp01((val - min).float32 / range.float32)
    let fillHeight = (colRect.h.float32 * fillAmount).int
    let fillRect = makeRect(nextX, nextY + colHeight - fillHeight, colWidth, fillHeight)
    guiBasicBox(colRect, style = rsInset)
    guiBasicBox(fillRect, style = rsFillBar)

    let drawRect = colRect.scrollCurrentWindow().clipCurrentWindow()
    let focus = windowDrag == "" and windowScroll == "" and windowResize == "" and pointInRect(mx,my, drawRect)
    if focus:
      multiSliderIndex = index
      hoveredElement = currentElement
    if focus and mousebtnp(0):
      dragElement = currentElement
      activeElement = currentElement

    if dragElement == currentElement and focus:
      let fillAmount = clamp01(1.0f - ((my - drawRect.y).float32 / drawRect.h.float32))
      if key(K_LSHIFT):
        let tval = lerp(min.float32, max.float32, fillAmount).T
        val = lerp(val.float32, tval.float32, 0.1f).T
      else:
        val = lerp(min.float32, max.float32, fillAmount).T
      result = true
    nextX += colWidth
    index += 1

  nextX = oldNextX

  guiAdvance(contentRect)

proc guiSlider2D*[T](name: string, x,y: var T, minx,miny: T = T.low, maxx,maxy: T = T.high): bool {.discardable.} =
  currentElement += 1
  let rect = guiBasicBox(h = lineHeight + vPadding * 2, style = rsInset)
  guiResetOverrides()

  let xrange = maxx - minx
  let yrange = maxy - miny
  let fillAmountX = (x - minx).float32 / xrange.float32
  let fillAmountY = (y - miny).float32 / yrange.float32
  let oldNextX = nextX
  let oldNextY = nextY

  nextX = rect.x + (fillAmountX * rect.w.float32).int - 1
  nextY = rect.y + (fillAmountY * rect.h.float32).int - 1
  guiBasicBox(h = 3, w = 3, style = rsFillBar)

  nextX = oldNextX
  nextY = oldNextY

  let (mx,my) = mouse()
  let drawRect = rect.scrollCurrentWindow().clipCurrentWindow()
  let focus = windowDrag == "" and windowScroll == "" and windowResize == "" and pointInRect(mx,my, drawRect)
  if focus:
    hoveredElement = currentElement
  if focus and mousebtnp(0):
    dragElement = currentElement
    activeElement = currentElement
    when T is SomeInteger:
      dragIntTmp = x.float32
      dragIntTmp2 = y.float32

  if dragElement == currentElement:
    #let fillAmount = clamp01((mx - drawRect.x).float32 / drawRect.w.float32)
    let fillAmountX = clamp01((mx - drawRect.x).float32 / drawRect.w.float32)
    let fillAmountY = clamp01((my - drawRect.y).float32 / drawRect.h.float32)

    if key(K_LSHIFT):
      let tx = lerp(minx.float32, maxx.float32, fillAmountX).T
      let ty = lerp(miny.float32, maxy.float32, fillAmountY).T
      x = lerp(x, tx, 0.1f)
      y = lerp(y, ty, 0.1f)
    else:
      x = lerp(minx.float32, maxx.float32, fillAmountX).T
      y = lerp(miny.float32, maxy.float32, fillAmountY).T
    result = true

  guiAdvance(rect)

proc guiOption*[T](name: string, val: var T, options: seq[T]): bool {.discardable.} =
  # dropdown for arbitary options
  currentElement += 1

  var rect = getBoxRect()
  guiPreAdvance(rect)

  guiBasicBox(rect, style = rsBasic)
  let oldNextY = nextY
  let oldNextX = nextX
  nextY += vPadding
  if name == "":
    guiBasicTextBox(&"{val} ", rsInset, align = alignLeft, rect = rect)
  else:
    guiBasicTextBox(&" {name}", rsBasic, align = alignLeft, rect = rect.leftHalf())
    guiBasicTextBox(&"{val} ", rsInset, align = alignLeft, rect = rect.rightHalf())
  nextX = oldNextX
  nextY = oldNextY

  let (mx,my) = mouse()
  let drawRect = rect.scrollCurrentWindow().clipCurrentWindow()
  let focus = windowDrag == "" and windowScroll == "" and windowResize == "" and pointInRect(mx,my, drawRect)
  if focus:
    hoveredElement = currentElement
  if focus and mousebtnp(0):
    dragElement = currentElement
    activeElement = currentElement

  if dragElement == currentElement:
    result = true
    # show popup selector
    nextOrder = 999
    disableClipping = true
    nextY = drawRect.y
    for i in options:
      let optionRect = guiBasicTextBox($i, if i == val: rsInset else: rsFlat, align = alignLeft)
      if pointInRect(mx, my, optionRect):
        guiBasicBox(optionRect, rsFocusOutline)
      if pointInRect(mx, my, optionRect) and mousebtnup(0):
        val = i
      nextY += optionRect.h
    nextOrder = 0
    disableClipping = false

  nextX = oldNextX
  nextY = oldNextY

  guiAdvance(rect)

proc guiOption*[T](name: string, val: var SomeInteger, options: openarray[T]): bool {.discardable.} =
  # dropdown for arbitary options
  currentElement += 1

  let rect = guiBasicBox(h = lineHeight + vPadding * 2, style = rsBasic)
  let oldNextY = nextY
  let oldNextX = nextX
  nextY += vPadding
  if name == "":
    guiBasicTextBox(&"{val} ", rsInset, align = alignLeft, rect = rect)
  else:
    guiBasicTextBox(&" {name}", rsBasic, align = alignLeft, rect = rect.leftHalf())
    guiBasicTextBox(&"{options[val]} ", rsInset, align = alignLeft, rect = rect.rightHalf())
  nextX = oldNextX
  nextY = oldNextY

  let (mx,my) = mouse()
  let drawRect = rect.scrollCurrentWindow().clipCurrentWindow()
  let focus = windowDrag == "" and windowScroll == "" and windowResize == "" and pointInRect(mx,my, drawRect)
  if focus:
    hoveredElement = currentElement
  if focus and mousebtnp(0):
    dragElement = currentElement
    activeElement = currentElement

  if dragElement == currentElement:
    result = true
    # show popup selector
    nextOrder = 999
    disableClipping = true
    nextY = drawRect.y
    for i,v in options:
      let optionRect = guiBasicTextBox($v, if i == val: rsInset else: rsFlat, align = alignLeft)
      if pointInRect(mx, my, optionRect):
        guiBasicBox(optionRect, rsFocusOutline)
      if pointInRect(mx, my, optionRect) and mousebtnup(0):
        val = i
      nextY += optionRect.h
    nextOrder = 0
    disableClipping = false

  nextX = oldNextX
  nextY = oldNextY

  guiAdvance(rect)

proc guiOption*[T](name: string, val: var T): bool {.discardable.} =
  # dropdown for enums
  currentElement += 1

  let rect = guiBasicBox(h = lineHeight + vPadding * 2, style = rsBasic)
  let oldNextY = nextY
  let oldNextX = nextX
  nextY += vPadding
  if name == "":
    guiBasicTextBox(&"{val} ", rsInset, align = alignLeft, rect = rect)
  else:
    guiBasicTextBox(&" {name}", rsBasic, align = alignLeft, rect = rect.leftHalf())
    guiBasicTextBox(&"{val} ", rsInset, align = alignLeft, rect = rect.rightHalf())
  nextX = oldNextX
  nextY = oldNextY

  let (mx,my) = mouse()
  let drawRect = rect.scrollCurrentWindow().clipCurrentWindow()
  let focus = windowDrag == "" and windowScroll == "" and windowResize == "" and pointInRect(mx,my, drawRect)
  if focus:
    hoveredElement = currentElement
  if focus and mousebtnp(0):
    dragElement = currentElement
    activeElement = currentElement

  if dragElement == currentElement:
    result = true
    # show popup selector
    nextOrder = 999
    disableClipping = true
    nextY = drawRect.y
    for i in T.low..T.high:
      let optionRect = guiBasicTextBox($i, if i == val: rsInset else: rsFlat, align = alignLeft)
      if pointInRect(mx, my, optionRect):
        guiBasicBox(optionRect, rsFocusOutline)
      if pointInRect(mx, my, optionRect) and mousebtnup(0):
        val = i
      nextY += optionRect.h
    nextOrder = 0
    disableClipping = false

  nextX = oldNextX
  nextY = oldNextY

  guiAdvance(rect)

proc guiTextField*(name: string, val: var string, default: string = ""): bool {.discardable.} =
  currentElement += 1

  var rect = getBoxRect()
  guiPreAdvance(rect)

  guiBasicBox(rect = rect, style = rsBasic)
  let oldNextY = nextY
  let oldNextX = nextX
  nextY += vPadding
  if name == "":
    guiBasicTextBox(&"{val} ", rsInset, align = alignLeft, rect = rect, focus = textInputElement == currentElement)
  else:
    guiBasicTextBox(&" {name}", rsBasic, align = alignLeft, rect = rect.leftHalf())
    guiBasicTextBox(val, rsInset, align = alignLeft, rect = rect.rightHalf())
  nextX = oldNextX
  nextY = oldNextY

  let (mx,my) = mouse()
  let drawRect = rect.scrollCurrentWindow().clipCurrentWindow()
  let focus = windowDrag == "" and windowScroll == "" and windowResize == "" and pointInRect(mx,my, drawRect)
  if focus:
    hoveredElement = currentElement
  if focus and mousebtnp(0):
    activeElement = currentElement
    textInputElement = currentElement
    startTextInput()
    var textptr = val.addr
    if textInputEventListener != nil:
      removeEventListener(textInputEventListener)
    echo "enabling text input"
    textInputEventListener = addEventListener(proc(e: Event): bool =
      if e.kind == ekTextInput:
        echo "got text event ", e.text
        textptr[] &= e.text
        return true
      if e.kind == ekTextEditing:
        echo "got text editing event ", e.text
        return true
      if e.kind == ekKeyDown:
        if e.keycode == K_BACKSPACE:
          if textptr[].len > 0:
            textptr[].setLen(textptr[].len - 1)
          return true
    )

  if textInputElement == currentElement:
    if activeElement != currentElement:
      stopTextInput()
      textInputElement = 0
      echo "disabling text input"
      if textInputEventListener != nil:
        removeEventListener(textInputEventListener)

  if focus and mousebtnp(2):
    val = default
    result = true

  nextX = oldNextX
  nextY = oldNextY

  guiAdvance(rect)


proc guiEnd*() =
  discard

proc guiDraw*() =
  clip()
  for rd in renderData.sortedByIt(it.order):
    if rd.rect.w == 0 or rd.rect.h == 0:
      continue
    case rd.kind:
    of rtBox:
      clipRect(rd.clippedRect)
      guiBoxDrawFunc(rd.rect.x, rd.rect.y, rd.rect.w, rd.rect.h, rd.style, rd.status, rd.focus)
    of rtText:
      clipRect(rd.clippedRect)
      guiTextDrawFunc(rd.data, rd.rect.x, rd.rect.y, rd.rect.w, rd.rect.h, rd.style, rd.status, rd.align, rd.focus)

  let (mx,my) = mouse()
  lastMouseX = mx
  lastMouseY = my
  clip()

proc guiUpdate*(dt: float32) =
  discard
