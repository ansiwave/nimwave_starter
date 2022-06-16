from illwave as iw import `[]`, `[]=`, `==`
from nimwave import nil
import unicode, json, tables, deques
from strutils import nil
from sequtils import nil

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
  chars: string
  charQueue: Deque[Rune]
  key: iw.Key
  keyQueue: Deque[iw.Key]

proc onMouse*(m: iw.MouseInfo) =
  mouseQueue.addLast(m)
  # treat scrolling up/down the same as arrow up/down
  case m.scrollDir:
  of iw.ScrollDirection.sdUp:
    keyQueue.addLast(iw.Key.Up)
  of iw.ScrollDirection.sdDown:
    keyQueue.addLast(iw.Key.Down)
  else:
    discard

proc onChar*(r: Rune) =
  charQueue.addLast(r)

proc onKey*(k: iw.Key) =
  keyQueue.addLast(k)

proc init*() =
  discard

proc addFocusArea(ctx: var nimwave.Context[State]): bool =
  result = ctx.data.focusIndex == ctx.data.focusAreas[].len
  ctx.data.focusAreas[].add(ctx.tb)

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

proc mountTemperatureText(ctx: var nimwave.Context[State], node: JsonNode, state: ref nimwave.TextState): nimwave.RenderProc[State] =
  let renderText = nimwave.mountText(ctx, node, state)
  return
    proc (ctx: var nimwave.Context[State], node: JsonNode) =
      ctx = nimwave.slice(ctx, 0, 0, 10, 3)
      let focused = addFocusArea(ctx)
      ctx.components["text"] = renderText
      nimwave.render(ctx, %* {
        "type": "nimwave.hbox",
        "border": if focused: "double" else: "single",
        "children": [
          {
            "type": "text",
            "edit":
              if focused:
                %* {"keycode": key.ord, "chars": chars}
              else:
                %* {}
            ,
          }
        ]
      })

proc mountTemperatureConverter(ctx: var nimwave.Context[State], node: JsonNode): nimwave.RenderProc[State] =
  var celsiusState = new nimwave.TextState
  celsiusState.text = "5.0"
  let renderCelsius = mountTemperatureText(ctx, node, celsiusState)
  var fahrenState = new nimwave.TextState
  fahrenState.text = "41.0"
  let renderFahren = mountTemperatureText(ctx, node, fahrenState)
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
ctx.statefulComponents["counter"] = mountCounter
ctx.statefulComponents["temp-converter"] = mountTemperatureConverter
ctx.components["lyrics"] = renderLyrics

proc tick*(tb: var iw.TerminalBuffer) =
  mouse = if mouseQueue.len > 0: mouseQueue.popFirst else: iw.MouseInfo()
  chars = ""
  while charQueue.len > 0:
    chars &= charQueue.popFirst
  key = if keyQueue.len > 0: keyQueue.popFirst else: iw.Key.None

  # change focus via mouse click
  if mouse.button == iw.MouseButton.mbLeft and mouse.action == iw.MouseButtonAction.mbaPressed:
    # check the last focus areas first so child components are checked before their parents
    for i in countDown(ctx.data.focusAreas[].len-1, 0):
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
    let
      focusIndex = min(max(0, ctx.data.focusIndex + focusChange), ctx.data.focusAreas[].len-1)
      focusArea = ctx.data.focusAreas[focusIndex]
    # if the next focus area is out of view, don't change the focus
    # (doesn't apply to web because scrolling works differently there)
    if platform != Web and
      (iw.y(focusArea) < 0 or
       iw.y(focusArea) + iw.height(focusArea) > iw.height(tb)):
      focusChange = 0
    # if the next focus area doesn't exist, don't change the focus
    elif ctx.data.focusIndex + focusChange < 0 or
      ctx.data.focusIndex + focusChange >= ctx.data.focusAreas[].len:
      focusChange = 0
  ctx.data.focusIndex += focusChange
  ctx.data.focusAreas[] = @[]

  const scrollSpeed = 2

  ctx.tb = tb
  nimwave.render(
    ctx,
    %* {
      "type": "nimwave.scroll",
      "id": "main-page",
      # on the web, we want to use native scrolling,
      # so make this component grow to fit its content
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

