from illwave as iw import `[]`, `[]=`, `==`
from nimwave import nil
import unicode, json, tables, deques

var
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

var counts: Table[string, int]

proc counter(ctx: var nimwave.Context, id: string, opts: JsonNode, children: seq[JsonNode]) =
  if id notin counts:
    counts[id] = 0
  proc countBtn(ctx: var nimwave.Context, childId: string, opts: JsonNode, children: seq[JsonNode]) =
    if mouse.action == iw.MouseButtonAction.mbaPressed and nimwave.contains(ctx.tb, mouse):
      counts[id] += 1
    nimwave.render(ctx, %* ["hbox", {"border": "single"}, "Count"])
  ctx.components["count-btn"] = countBtn
  ctx = nimwave.slice(ctx, 0, 0, iw.width(ctx.tb), 5)
  nimwave.render(ctx, %* ["hbox", $counts[id], ["count-btn"]])

proc tick*(width: int, height: int): iw.TerminalBuffer =
  mouse = if mouseQueue.len > 0: mouseQueue.popFirst else: iw.MouseInfo()
  rune = if runeQueue.len > 0: runeQueue.popFirst else: Rune(0)
  key = if keyQueue.len > 0: keyQueue.popFirst else: iw.Key.None

  result = iw.initTerminalBuffer(width, height)
  var ctx = nimwave.initContext(result)
  ctx.components["counter"] = counter
  nimwave.render(
    ctx,
    %* [
      "hbox",
      ["vbox", {"id": "hello", "border": "single"},
       ["vbox", ["vbox", {"border": "single"}],
       ["vbox", {"border": "single"}]]],
      ["vbox", {"id": "goodbye", "border": "single"},
       ["counter", {"id": "counter"}]],
    ]
  )

