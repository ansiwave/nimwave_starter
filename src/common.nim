from illwave as iw import nil
from nimwave import nil
import unicode, json, tables

var
  mouse: iw.MouseInfo
  rune: Rune
  key: iw.Key

proc onMouse*(m: iw.MouseInfo) =
  mouse = m

proc onRune*(r: Rune) =
  rune = r

proc onKey*(k: iw.Key) =
  key = k

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
  mouse = iw.MouseInfo()
  rune = Rune(0)
  key = iw.Key.None

