from illwave as iw import `[]`, `[]=`, `==`
from nimwave as nw import nil
import unicode, json, tables, deques
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
  Button = ref object of nw.Component
    text: string
    key: iw.Key
    mouse: iw.MouseInfo
    action: proc ()

method render*(node: Button, ctx: var nw.Context[State]) =
  procCall render(nw.Component(node), ctx)
  ctx = nimwave.slice(ctx, 0, 0, node.text.runeLen+2, iw.height(ctx.tb))
  let focused = addFocusArea(ctx)
  if (node.mouse.action == iw.MouseButtonAction.mbaPressed and iw.contains(ctx.tb, node.mouse)) or
      (focused and node.key == iw.Key.Enter):
    node.action()
  render(nw.Box(
    direction: nw.Direction.Horizontal,
    border: if focused: nw.Border.Double else: nw.Border.Single,
    children: nw.all(
      nw.Text(text: node.text),
    ),
  ), ctx)

type
  Counter = ref object of nw.Component
    key: iw.Key
    mouse: iw.MouseInfo
    count: int

method render*(node: Counter, ctx: var nw.Context[State]) =
  procCall render(nw.Component(node), ctx)
  let mnode = getMounted(node, ctx)
  ctx = nw.slice(ctx, 0, 0, 15, 3)
  proc incCount() =
    mnode.count += 1
  render(nw.Box(
    direction: nw.Direction.Horizontal,
    border: nw.Border.None,
    children: nw.all(
      nw.Box(
        direction: nw.Direction.Horizontal,
        border: nw.Border.Hidden,
        children: nw.all(
          nw.Text(text: $mnode.count),
        ),
      ),
      Button(text: "Count", key: node.key, mouse: node.mouse, action: incCount),
    ),
  ), ctx)

type
  TempConverter = ref object of nw.Component
    key: iw.Key
    chars: seq[Rune]

method render*(node: TempConverter, ctx: var nw.Context[State]) =
  procCall render(nw.Component(node), ctx)
  ctx = nw.slice(ctx, 0, 0, 10, 3)
  let focused = addFocusArea(ctx)
  render(nw.Box(
    direction: nw.Direction.Horizontal,
    border: if focused: nw.Border.Double else: nw.Border.Single,
    children: nw.all(
      nw.Text(id: "edit", kind: nw.TextKind.Edit, enabled: focused, key: node.key, chars: node.chars),
    ),
  ), ctx)

type
  Lyrics = ref object of nw.Component

method render*(node: Lyrics, ctx: var nw.Context[State]) =
  procCall render(nw.Component(node), ctx)
  const rollingStone = strutils.splitLines(staticRead("rollingstone.txt"))
  let focused = addFocusArea(ctx)
  var lines: seq[nw.Component]
  for line in rollingStone:
    lines.add(nw.Text(text: line))
  let box = nw.Box(
    direction: nw.Direction.Vertical,
    border: if focused: nw.Border.Double else: nw.Border.Single,
    children: lines,
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
  let root = nw.Scroll(
    id: "main-page",
    # on the web, we want to use native scrolling,
    # so make this component grow to fit its content
    growX: platform == Web,
    growY: platform == Web,
    child: nw.Box(
      direction: nw.Direction.Vertical,
      children: nw.all(
        Counter(id: "counter", key: key, mouse: mouse),
        TempConverter(key: key, chars: chars),
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

