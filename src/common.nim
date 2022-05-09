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

proc counter(state: var nimwave.State, id: string, opts: JsonNode, children: seq[JsonNode]) =
  if id notin counts:
    counts[id] = 0
  proc countBtn(state: var nimwave.State, childId: string, opts: JsonNode, children: seq[JsonNode]) =
    if mouse.action == iw.MouseButtonAction.mbaPressed and nimwave.contains(state.tb, mouse):
      counts[id] += 1
    nimwave.render(state, %* ["hbox", {"border": "single"}, "Count"])
  nimwave.addComponent(state, "count-btn", countBtn)
  state = nimwave.slice(state, 0, 0, iw.width(state.tb), 5)
  nimwave.render(state, %* ["hbox", $counts[id], ["count-btn"]])

proc tick*(width: int, height: int): iw.TerminalBuffer =
  result = iw.initTerminalBuffer(width, height)
  var state = nimwave.initState(result)
  nimwave.addComponent(state, "counter", counter)
  nimwave.render(
    state,
    %* [
      "hbox",
      ["vbox", {"id": "hello", "border": "single"}, ["vbox", ["vbox", {"border": "single"}], ["vbox", {"border": "single"}]]],
      ["vbox", {"id": "goodbye", "border": "single"},
       ["counter", {"id": "counter"}]],
    ]
  )
  mouse = iw.MouseInfo()
  rune = Rune(0)
  key = iw.Key.None

