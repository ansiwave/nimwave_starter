from illwave as iw import `[]`, `[]=`, `==`
from nimwave as nw import nil
import unicode, json, tables, deques
from strutils import nil

type
  Platform* = enum
    Tui, Gui, Web,
  State = object
    focusIndex*: int
    focusAreas*: ref seq[iw.TerminalBuffer]

include nimwave/prelude

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

proc addFocusArea(ctx: var nw.Context[State]): bool =
  result = ctx.data.focusIndex == ctx.data.focusAreas[].len
  ctx.data.focusAreas[].add(ctx.tb)

#[

proc mountCounter(ctx: var nw.Context[State], node: JsonNode): nw.RenderProc[State] =
  var count = 0
  return
    proc (ctx: var nw.Context[State], node: JsonNode) =
      ctx = nw.slice(ctx, 0, 0, 15, 3)
      let focused = addFocusArea(ctx)
      proc renderCountBtn(ctx: var nw.Context[State], node: JsonNode) =
        const text = "Count"
        ctx = nw.slice(ctx, 0, 0, text.runeLen+2, iw.height(ctx.tb))
        if (mouse.action == iw.MouseButtonAction.mbaPressed and iw.contains(ctx.tb, mouse)) or (focused and key == iw.Key.Enter):
          count += 1
        nw.render(ctx, %* {"type": "nw.hbox", "children": [text], "border": if focused: "double" else: "single"})
      ctx.components["count-btn"] = renderCountBtn
      nw.render(ctx, %* {"type": "nw.hbox", "children": [{"type": "nw.vbox", "border": "none", "children": [$count]}, {"type": "count-btn"}]})

proc mountTemperatureText(ctx: var nw.Context[State], node: JsonNode, state: ref nw.TextState): nw.RenderProc[State] =
  let renderText = nw.mountText(ctx, node, state)
  return
    proc (ctx: var nw.Context[State], node: JsonNode) =
      ctx = nw.slice(ctx, 0, 0, 10, 3)
      let focused = addFocusArea(ctx)
      ctx.components["text"] = renderText
      nw.render(ctx, %* {
        "type": "nw.hbox",
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

proc mountTemperatureConverter(ctx: var nw.Context[State], node: JsonNode): nw.RenderProc[State] =
  var celsiusState = new nw.TextState
  celsiusState.text = "5.0"
  let renderCelsius = mountTemperatureText(ctx, node, celsiusState)
  var fahrenState = new nw.TextState
  fahrenState.text = "41.0"
  let renderFahren = mountTemperatureText(ctx, node, fahrenState)
  return
    proc (ctx: var nw.Context[State], node: JsonNode) =
      ctx = nw.slice(ctx, 0, 0, iw.width(ctx.tb), 3)
      ctx.components["celsius"] = renderCelsius
      ctx.components["fahrenheit"] = renderFahren
      let
        oldCelsius = celsiusState[].text
        oldFahren = fahrenState[].text
      nw.render(ctx, %* {
        "type": "nw.hbox",
        "children": [
          {"type": "celsius", "id": "celsius"},
          {"type": "nw.hbox", "border": "none", "children": ["Celsius ="]},
          {"type": "fahrenheit", "id": "fahrenheit"},
          {"type": "nw.hbox", "border": "none", "children": ["Fahrenheit"]},
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
]#

type
  Lyrics = ref object of nw.Component

method render*(node: Lyrics, ctx: var nw.Context[State]) =
  procCall render(nw.Component(node), ctx)
  const rollingStone = strutils.splitLines(staticRead("rollingstone.txt"))
  let focused = addFocusArea(ctx)
  var lines: seq[nw.Component]
  for line in rollingStone:
    lines.add(Text(content: line))
  let box = Box(
    direction: Direction.Vertical,
    border: if focused: Border.Double else: Border.Single,
    children: lines,
  )
  render(box, ctx)

var ctx = nw.initContext[State]()
new ctx.data.focusAreas

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
    # if the next focus area doesn't exist, don't change the focus
    if ctx.data.focusIndex + focusChange < 0 or
      ctx.data.focusIndex + focusChange >= ctx.data.focusAreas[].len:
      focusChange = 0
    # if the next focus area is out of view, don't change the focus
    else:
      let focusArea = ctx.data.focusAreas[ctx.data.focusIndex + focusChange]
      if iw.y(focusArea) < 0 or iw.y(focusArea) > iw.height(tb):
        focusChange = 0
  ctx.data.focusIndex += focusChange
  ctx.data.focusAreas[] = @[]

  const scrollSpeed = 2

  ctx.tb = tb
  let root = Scroll(
    id: "main-page",
    # on the web, we want to use native scrolling,
    # so make this component grow to fit its content
    growX: platform == Web,
    growY: platform == Web,
    child: Box(
      direction: Direction.Vertical,
      children: nw.all(
        Lyrics(),
      )
    ),
    changeScrollX:
      # don't scroll x if text fields are focused
      if ctx.data.focusIndex notin {1, 2}:
        case key:
        of iw.Key.Left:
          scrollSpeed
        of iw.Key.Right:
          -scrollSpeed
        else:
          0
      else:
        0
    ,
    changeScrollY:
      if focusChange == 0:
        case key:
        of iw.Key.Up:
          scrollSpeed
        of iw.Key.Down:
          -scrollSpeed
        else:
          0
      else:
        0
  )
  renderRoot(root, ctx)

