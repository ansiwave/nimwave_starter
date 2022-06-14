from illwave as iw import `[]`, `[]=`, `==`
from nimwave import nil
import unicode, json, tables, deques
from strutils import nil

type
  Platform* = enum
    Tui, Gui, Web,
  State = object
    focusIndex*: int
    focusAreas*: ref seq[iw.TerminalBuffer]

var
  platform*: Platform
  mouse: iw.MouseInfo
  mouseQueue: Deque[iw.MouseInfo]
  rune: Rune
  runeQueue: Deque[Rune]
  key: iw.Key
  keyQueue: Deque[iw.Key]

proc onMouse*(m: iw.MouseInfo) =
  if platform != Web:
    # treat scrolling up/down the same as arrow up/down
    case m.scrollDir:
    of iw.ScrollDirection.sdUp:
      keyQueue.addLast(iw.Key.Up)
    of iw.ScrollDirection.sdDown:
      keyQueue.addLast(iw.Key.Down)
    else:
      discard
  mouseQueue.addLast(m)

proc onRune*(r: Rune) =
  runeQueue.addLast(r)

proc onKey*(k: iw.Key) =
  keyQueue.addLast(k)

proc init*() =
  discard

proc addFocusArea(ctx: var nimwave.Context[State]): bool =
  result = ctx.data.focusIndex == ctx.data.focusAreas[].len
  ctx.data.focusAreas[].add(ctx.tb)

type
  ScrollState = object
    scrollX: int
    scrollY: int

proc renderScroll(ctx: var nimwave.Context[State], node: JsonNode, state: ref ScrollState) =
  let
    width = iw.width(ctx.tb)
    height = iw.height(ctx.tb)
    boundsWidth =
      if "grow-x" in node and node["grow-x"].bval:
        -1
      else:
        width
    boundsHeight =
      if "grow-y" in node and node["grow-y"].bval:
        -1
      else:
        height
    bounds = (0, 0, boundsWidth, boundsHeight)
  var ctx = nimwave.slice(ctx, state[].scrollX, state[].scrollY, width, height, bounds)
  nimwave.render(ctx, %* node["child"])
  if "change-scroll-x" in node:
    state[].scrollX += node["change-scroll-x"].num.int
    let minX = width - iw.width(ctx.tb)
    if minX < 0:
      state[].scrollX = state[].scrollX.clamp(minX, 0)
    else:
      state[].scrollX = 0
  if "change-scroll-y" in node:
    state[].scrollY += node["change-scroll-y"].num.int
    let minY = height - iw.height(ctx.tb)
    if minY < 0:
      state[].scrollY = state[].scrollY.clamp(minY, 0)
    else:
      state[].scrollY = 0

proc mountScroll(ctx: var nimwave.Context[State], node: JsonNode, state: ref ScrollState): nimwave.RenderProc[State] =
  return
    proc (ctx: var nimwave.Context[State], node: JsonNode) =
      renderScroll(ctx, node, state)

proc mountScroll(ctx: var nimwave.Context[State], node: JsonNode): nimwave.RenderProc[State] =
  var state = new ScrollState
  return mountScroll(ctx, node, state)

proc mountCounter(ctx: var nimwave.Context[State], node: JsonNode): nimwave.RenderProc[State] =
  var count = 0
  return
    proc (ctx: var nimwave.Context[State], node: JsonNode) =
      ctx = nimwave.slice(ctx, 0, 0, 15, 3)
      let focused = addFocusArea(ctx)
      proc renderCountBtn(ctx: var nimwave.Context[State], node: JsonNode) =
        const text = "Count"
        ctx = nimwave.slice(ctx, 0, 0, text.runeLen+2, iw.height(ctx.tb))
        if (mouse.action == iw.MouseButtonAction.mbaPressed and iw.contains(ctx.tb, mouse)) or (focused and key == iw.Key.Enter):
          count += 1
        nimwave.render(ctx, %* {"type": "nimwave.hbox", "border": "single", "children": [text], "border": if focused: "double" else: "single"})
      ctx.components["count-btn"] = renderCountBtn
      nimwave.render(ctx, %* {"type": "nimwave.hbox", "children": [{"type": "nimwave.vbox", "border": "none", "children": [$count]}, {"type": "count-btn"}]})

type
  TextFieldState = object
    text: string
    cursorX: int

proc renderTextField(ctx: var nimwave.Context[State], node: JsonNode, state: ref TextFieldState, scrollState: ref ScrollState) =
  let
    key = if "key" in node: iw.Key(node["key"].num.int) else: iw.Key.None
    rune = if "rune" in node: Rune(node["rune"].num.int) else: Rune(0)
  case key:
  of iw.Key.Backspace:
    if state[].cursorX > 0:
      let
        line = state[].text.toRunes
        x = state[].cursorX - 1
        newLine = $line[0 ..< x] & $line[x + 1 ..< line.len]
      state[].text = newLine
      state[].cursorX -= 1
  of iw.Key.Delete:
    if state[].cursorX < state[].text.runeLen:
      let
        line = state[].text.toRunes
        newLine = $line[0 ..< state[].cursorX] & $line[state[].cursorX + 1 ..< line.len]
      state[].text = newLine
  of iw.Key.Left:
    state[].cursorX -= 1
    if state[].cursorX < 0:
      state[].cursorX = 0
  of iw.Key.Right:
    state[].cursorX += 1
    if state[].cursorX > state[].text.runeLen:
      state[].cursorX = state[].text.runeLen
  of iw.Key.Home:
    state[].cursorX = 0
  of iw.Key.End:
    state[].cursorX = state[].text.runeLen
  else:
    discard
  if rune.ord >= 32:
    let
      line = state[].text.toRunes
      before = line[0 ..< state[].cursorX]
      after = line[state[].cursorX ..< line.len]
    state[].text = $before & $rune & $after
    state[].cursorX += 1
  # create scroll component
  proc mountTextFieldScroll(ctx: var nimwave.Context[State], node: JsonNode): nimwave.RenderProc[State] =
    return mountScroll(ctx, node, scrollState)
  ctx.statefulComponents["text-field-scroll"] = mountTextFieldScroll
  # update scroll position
  let cursorXDiff = scrollState[].scrollX + state[].cursorX
  if cursorXDiff >= iw.width(ctx.tb) - 1:
    scrollState[].scrollX = iw.width(ctx.tb) - 1 - state[].cursorX
  elif cursorXDiff < 0:
    scrollState[].scrollX = 0 - state[].cursorX
  # render
  ctx = nimwave.slice(ctx, 0, 0, iw.width(ctx.tb), 1)
  nimwave.render(ctx, %* {
    "type": "text-field-scroll",
    "id": "text-field-scroll",
    "child": state[].text,
  })
  if "show-cursor" in node and node["show-cursor"].bval:
    var cell = ctx.tb[scrollState[].scrollX + state[].cursorX, 0]
    cell.bg = iw.bgYellow
    cell.fg = iw.fgBlack
    ctx.tb[scrollState[].scrollX + state[].cursorX, 0] = cell

proc mountTextField(ctx: var nimwave.Context[State], node: JsonNode, state: ref TextFieldState): nimwave.RenderProc[State] =
  var scrollState = new ScrollState
  return
    proc (ctx: var nimwave.Context[State], node: JsonNode) =
      renderTextField(ctx, node, state, scrollState)

proc mountTemperatureTextField(ctx: var nimwave.Context[State], node: JsonNode, state: ref TextFieldState): nimwave.RenderProc[State] =
  let renderTextField = mountTextField(ctx, node, state)
  return
    proc (ctx: var nimwave.Context[State], node: JsonNode) =
      ctx = nimwave.slice(ctx, 0, 0, 10, 3)
      let focused = addFocusArea(ctx)
      ctx.components["text-field"] = renderTextField
      nimwave.render(ctx, %* {
        "type": "nimwave.hbox",
        "border": if focused: "double" else: "single",
        "children": [
          if focused:
            %* {"type": "text-field", "key": key.ord, "rune": rune.ord, "show-cursor": true}
          else:
            %* {"type": "text-field"}
        ]
      })

proc mountTemperatureConverter(ctx: var nimwave.Context[State], node: JsonNode): nimwave.RenderProc[State] =
  var celsiusState = new TextFieldState
  celsiusState.text = "5.0"
  let renderCelsius = mountTemperatureTextField(ctx, node, celsiusState)
  var fahrenState = new TextFieldState
  fahrenState.text = "41.0"
  let renderFahren = mountTemperatureTextField(ctx, node, fahrenState)
  return
    proc (ctx: var nimwave.Context[State], node: JsonNode) =
      ctx = nimwave.slice(ctx, 0, 0, iw.width(ctx.tb), 3)
      ctx.components["celsius"] = renderCelsius
      ctx.components["fahrenheit"] = renderFahren
      let
        oldCelsius = celsiusState[].text
        oldFahren = fahrenState[].text
      nimwave.render(ctx, %* {
        "type": "nimwave.hbox",
        "children": [
          {"type": "celsius", "id": "celsius"},
          {"type": "nimwave.hbox", "border": "none", "children": ["Celsius ="]},
          {"type": "fahrenheit", "id": "fahrenheit"},
          {"type": "nimwave.hbox", "border": "none", "children": ["Fahrenheit"]},
        ]
      })
      let
        newCelsius = celsiusState[].text
        newFahren = fahrenState[].text
      if oldCelsius != newCelsius:
        try:
          let c = strutils.parseFloat(newCelsius)
          fahrenState[].text = $(c * (9 / 5) + 32f)
        except ValueError:
          fahrenState[].text = ""
      elif oldFahren != newFahren:
        try:
          let f = strutils.parseFloat(newFahren)
          celsiusState[].text = $((f - 32) * (5 / 9))
        except ValueError:
          celsiusState[].text = ""

proc renderLyrics(ctx: var nimwave.Context[State], node: JsonNode) =
  const rollingStone = strutils.splitLines(staticRead("rollingstone.txt"))
  let focused = addFocusArea(ctx)
  nimwave.render(ctx, %* {"type": "nimwave.vbox", "border": if focused: "double" else: "single", "children": rollingStone})

var ctx = nimwave.initContext[State]()
new ctx.data.focusAreas
ctx.statefulComponents["scroll"] = mountScroll
ctx.statefulComponents["counter"] = mountCounter
ctx.statefulComponents["temp-converter"] = mountTemperatureConverter
ctx.components["lyrics"] = renderLyrics

proc tick*(tb: var iw.TerminalBuffer) =
  mouse = if mouseQueue.len > 0: mouseQueue.popFirst else: iw.MouseInfo()
  rune = if runeQueue.len > 0: runeQueue.popFirst else: Rune(0)
  key = if keyQueue.len > 0: keyQueue.popFirst else: iw.Key.None

  if mouse.button == iw.MouseButton.mbLeft and mouse.action == iw.MouseButtonAction.mbaPressed:
    for i in 0 ..< ctx.data.focusAreas[].len:
      let area = ctx.data.focusAreas[i]
      if iw.contains(area, mouse):
        ctx.data.focusIndex = i
        break

  var focusChange =
    case key:
    of iw.Key.Up:
      -1
    of iw.Key.Down:
      1
    else:
      0
  if focusChange != 0 and ctx.data.focusAreas[].len > 0:
    # if the next focus area is out of view, don't change the focus
    let
      focusIndex = min(max(0, ctx.data.focusIndex + focusChange), ctx.data.focusAreas[].len-1)
      focusArea = ctx.data.focusAreas[focusIndex]
    if iw.y(focusArea) < 0 or
      iw.y(focusArea) + iw.height(focusArea) > iw.height(tb) or
      ctx.data.focusIndex + focusChange < 0 or
      ctx.data.focusIndex + focusChange >= ctx.data.focusAreas[].len:
      focusChange = 0
  ctx.data.focusIndex += focusChange
  ctx.data.focusAreas[] = @[]

  const scrollSpeed = 2

  ctx.tb = tb
  nimwave.render(
    ctx,
    %* {
      "type": "scroll",
      "id": "main-page",
      # on the web, we want to use native scrolling,
      # so make this component expand to fit its content
      "grow-x": platform == Web,
      "grow-y": platform == Web,
      "change-scroll-x":
        case platform:
        of Tui, Gui:
          case key:
          of iw.Key.Left:
            scrollSpeed
          of iw.Key.Right:
            -scrollSpeed
          else:
            0
        of Web:
          0
      ,
      "change-scroll-y":
        if focusChange == 0:
          case platform:
          of Tui, Gui:
            case key:
            of iw.Key.Up:
              scrollSpeed
            of iw.Key.Down:
              -scrollSpeed
            else:
              0
          of Web:
            0
        else:
          0
      ,
      "child":
        {
          "type": "nimwave.vbox",
          "children": [
            {"type": "counter", "id": "counter"},
            {"type": "temp-converter", "id": "temp-converter"},
            {"type": "lyrics"},
          ]
        }
      ,
    }
  )

