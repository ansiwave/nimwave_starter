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

proc scroll(ctx: var nimwave.Context[State], node: JsonNode, data: ref ScrollState): nimwave.RenderProc[State] =
  return
    proc (ctx: var nimwave.Context[State], node: JsonNode) =
      let
        width = iw.width(ctx.tb)
        height = iw.height(ctx.tb)
        bounds =
          if platform == Web:
            (0, 0, -1, -1)
          else:
            (0, 0, iw.width(ctx.tb), iw.height(ctx.tb))
      var ctx = nimwave.slice(ctx, data[].scrollX, data[].scrollY, iw.width(ctx.tb), iw.height(ctx.tb), bounds)
      nimwave.render(ctx, %* node["child"])
      if "scroll-x-change" in node:
        data[].scrollX += node["scroll-x-change"].num.int
        let minX = width - iw.width(ctx.tb)
        if minX < 0:
          data[].scrollX = data[].scrollX.clamp(minX, 0)
        else:
          data[].scrollX = 0
      if "scroll-y-change" in node:
        data[].scrollY += node["scroll-y-change"].num.int
        let minY = height - iw.height(ctx.tb)
        if minY < 0:
          data[].scrollY = data[].scrollY.clamp(minY, 0)
        else:
          data[].scrollY = 0

proc scroll(ctx: var nimwave.Context[State], node: JsonNode): nimwave.RenderProc[State] =
  var data = new ScrollState
  return scroll(ctx, node, data)

proc counter(ctx: var nimwave.Context[State], node: JsonNode): nimwave.RenderProc[State] =
  var count = 0
  return
    proc (ctx: var nimwave.Context[State], node: JsonNode) =
      ctx = nimwave.slice(ctx, 0, 0, 20, 3)
      let focused = addFocusArea(ctx)
      proc countBtn(ctx: var nimwave.Context[State], node: JsonNode) =
        const text = "Count"
        ctx = nimwave.slice(ctx, 0, 0, text.runeLen+2, iw.height(ctx.tb))
        if (mouse.action == iw.MouseButtonAction.mbaPressed and iw.contains(ctx.tb, mouse)) or key == iw.Key.Enter:
          count += 1
        nimwave.render(ctx, %* {"type": "nimwave.hbox", "border": "single", "children": [text], "border": if focused: "double" else: "single"})
      ctx.components["count-btn"] = countBtn
      nimwave.render(ctx, %* {"type": "nimwave.hbox", "children": [{"type": "nimwave.vbox", "children": ["", $count]}, {"type": "count-btn"}]})

type
  TextFieldState = object
    text: string
    cursorX: int

proc textField(ctx: var nimwave.Context[State], node: JsonNode, data: ref TextFieldState): nimwave.RenderProc[State] =
  let id = node["id"].str
  return
    proc (ctx: var nimwave.Context[State], node: JsonNode) =
      let
        key = if "key" in node: iw.Key(node["key"].num.int) else: iw.Key.None
        rune = if "rune" in node: Rune(node["rune"].num.int) else: Rune(0)
      case key:
      of iw.Key.Backspace:
        if data[].cursorX > 0:
          let
            line = data[].text.toRunes
            x = data[].cursorX - 1
            newLine = $line[0 ..< x] & $line[x + 1 ..< line.len]
          data[].text = newLine
          data[].cursorX -= 1
      of iw.Key.Delete:
        if data[].cursorX < data[].text.runeLen:
          let
            line = data[].text.toRunes
            newLine = $line[0 ..< data[].cursorX] & $line[data[].cursorX + 1 ..< line.len]
          data[].text = newLine
      of iw.Key.Left:
        data[].cursorX -= 1
        if data[].cursorX < 0:
          data[].cursorX = 0
      of iw.Key.Right:
        data[].cursorX += 1
        if data[].cursorX > data[].text.runeLen:
          data[].cursorX = data[].text.runeLen
      else:
        discard
      if rune.ord >= 32:
        let
          line = data[].text.toRunes
          before = line[0 ..< data[].cursorX]
          after = line[data[].cursorX ..< line.len]
        data[].text = $before & $rune & $after
        data[].cursorX += 1
      ctx = nimwave.slice(ctx, 0, 0, iw.width(ctx.tb), 1)
      nimwave.render(ctx, %* {"type": "scroll", "child": data[].text, "id": id & "-scroll"})
      if "show-cursor" in node and node["show-cursor"].bval:
        var cell = ctx.tb[data[].cursorX, 0]
        cell.bg = iw.bgYellow
        cell.fg = iw.fgBlack
        ctx.tb[data[].cursorX, 0] = cell

proc tempConverter(ctx: var nimwave.Context[State], node: JsonNode): nimwave.RenderProc[State] =
  var data = new TextFieldState
  let comp = textField(ctx, node, data)
  return
    proc (ctx: var nimwave.Context[State], node: JsonNode) =
      ctx = nimwave.slice(ctx, 0, 0, 10, 3)
      ctx.components["text-field"] = comp
      let focused = addFocusArea(ctx)
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

proc lyrics(ctx: var nimwave.Context[State], node: JsonNode) =
  const rollingStone = strutils.splitLines(staticRead("rollingstone.txt"))
  let focused = addFocusArea(ctx)
  nimwave.render(ctx, %* {"type": "nimwave.vbox", "border": if focused: "double" else: "single", "children": rollingStone})

var ctx = nimwave.initContext[State]()
new ctx.data.focusAreas
ctx.statefulComponents["scroll"] = scroll
ctx.statefulComponents["counter"] = counter
ctx.statefulComponents["temp-converter"] = tempConverter
ctx.components["lyrics"] = lyrics

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

  ctx.tb = tb
  nimwave.render(
    ctx,
    %* {
      "type": "scroll",
      "id": "main-page",
      "scroll-x-change":
        case platform:
        of Tui, Gui:
          case key:
          of iw.Key.Left:
            1
          of iw.Key.Right:
            -1
          else:
            0
        of Web:
          0
      ,
      "scroll-y-change":
        if focusChange == 0:
          case platform:
          of Tui, Gui:
            case key:
            of iw.Key.Up:
              1
            of iw.Key.Down:
              -1
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

