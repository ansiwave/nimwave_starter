from illwave as iw import `[]`, `[]=`, `==`
from nimwave as nw import nil
import unicode, tables, deques
from strutils import nil
from sequtils import nil

type
  Platform* = enum
    Tui, Gui, Web,
  State = object
    focusIndex*: int
    focusAreas*: ref seq[iw.TerminalBuffer]

include nimwave/prelude

var
  platform*: Platform
  mouseQueue: Deque[iw.MouseInfo]
  charQueue: Deque[Rune]
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

type
  Button = ref object of nw.Node
    str: string
    key: iw.Key
    mouse: iw.MouseInfo
    action: proc ()

method render*(node: Button, ctx: var nw.Context[State]) =
  ctx = nw.slice(ctx, 0, 0, node.str.runeLen+2, iw.height(ctx.tb))
  let focused = addFocusArea(ctx)
  if (node.mouse.action == iw.MouseButtonAction.mbaPressed and iw.contains(ctx.tb, node.mouse)) or
      (focused and node.key == iw.Key.Enter):
    node.action()
  render(nw.Box(
    direction: nw.Direction.Horizontal,
    border: if focused: nw.Border.Double else: nw.Border.Single,
    children: nw.seq(node.str),
  ), ctx)

type
  Counter = ref object of nw.Node
    key: iw.Key
    mouse: iw.MouseInfo
    count: int

method render*(node: Counter, ctx: var nw.Context[State]) =
  let mnode = getMounted(node, ctx)
  ctx = nw.slice(ctx, 0, 0, 15, 3)
  proc incCount() =
    mnode.count += 1
  render(
    nw.Box(
      direction: nw.Direction.Horizontal,
      border: nw.Border.None,
      children: nw.seq(
        nw.Box(
          direction: nw.Direction.Horizontal,
          border: nw.Border.Hidden,
          children: nw.seq($mnode.count),
        ),
        Button(str: "Count", key: node.key, mouse: node.mouse, action: incCount),
      ),
    ),
    ctx
  )

type
  TextField = ref object of nw.Node
    key: iw.Key
    chars: seq[Rune]
    action: proc (text: nw.Text)
    text: nw.Text
    initialText: string

method render*(node: TextField, ctx: var nw.Context[State]) =
  ctx = nw.slice(ctx, 0, 0, 10, 3)
  let focused = addFocusArea(ctx)
  node.text = getMounted(nw.Text(id: node.id & "/text", kind: nw.TextKind.Edit, str: node.initialText), ctx)
  node.text.enabled = focused
  node.text.key = node.key
  node.text.chars = node.chars
  render(
    nw.Box(
      direction: nw.Direction.Horizontal,
      border: if focused: nw.Border.Double else: nw.Border.Single,
      children: nw.seq(node.text),
    ),
    ctx
  )
  if focused and (node.key != iw.Key.None or node.chars.len > 0):
    node.action(node.text)

type
  TempConverter = ref object of nw.Node
    key: iw.Key
    chars: seq[Rune]

method render*(node: TempConverter, ctx: var nw.Context[State]) =
  ctx = nw.slice(ctx, 0, 0, iw.width(ctx.tb), 3)
  let
    celsius = getMounted(TextField(id: node.id & "/celsius", initialText: "5.0"), ctx)
    fahren = getMounted(TextField(id: node.id & "/fahrenheit", initialText: "41.0"), ctx)
  celsius.key = node.key
  celsius.chars = node.chars
  celsius.action =
    proc (text: nw.Text) =
      try:
        let c = strutils.parseFloat(text.str)
        fahren.text.str = $(c * (9 / 5) + 32f)
      except ValueError:
        fahren.text.str = ""
  fahren.key = node.key
  fahren.chars = node.chars
  fahren.action =
    proc (text: nw.Text) =
      try:
        let f = strutils.parseFloat(text.str)
        celsius.text.str = $((f - 32) * (5 / 9))
      except ValueError:
        celsius.text.str = ""
  render(
    nw.Box(
      direction: nw.Direction.Horizontal,
      children: nw.seq(
        celsius,
        nw.Box(
          direction: nw.Direction.Horizontal,
          border: nw.Border.Hidden,
          children: nw.seq(
            nw.Text(str: "Celsius = "),
          ),
        ),
        fahren,
        nw.Box(
          direction: nw.Direction.Horizontal,
          border: nw.Border.Hidden,
          children: nw.seq(
            nw.Text(str: "Fahrenheit"),
          ),
        ),
      ),
    ),
    ctx
  )

type
  Lyrics = ref object of nw.Node

method render*(node: Lyrics, ctx: var nw.Context[State]) =
  const rollingStone = strutils.splitLines(staticRead("rollingstone.txt"))
  let
    focused = addFocusArea(ctx)
    box = nw.Box(
      direction: nw.Direction.Vertical,
      border: if focused: nw.Border.Double else: nw.Border.Single,
      children: nw.seq(rollingStone),
    )
  render(box, ctx)

var ctx = nw.initContext[State]()
new ctx.data.focusAreas

proc tick*(tb: var iw.TerminalBuffer) =
  let
    mouse = if mouseQueue.len > 0: mouseQueue.popFirst else: iw.MouseInfo()
    chars = block:
      let s = sequtils.toSeq(charQueue)
      charQueue.clear
      s
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

  renderRoot(
    nw.Scroll(
      id: "main-page",
      growX: true,
      growY: true,
      child: nw.Box(
        direction: nw.Direction.Vertical,
        children: nw.seq(
          Counter(id: "counter", key: key, mouse: mouse),
          TempConverter(id: "converter", key: key, chars: chars),
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
    ),
    ctx
  )

