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
  let
    actions = {
      "counter":
      proc (state: var nimwave.State, opts: JsonNode) =
        if mouse.action == iw.MouseButtonAction.mbaPressed and nimwave.contains(state.tb, mouse):
          counts[id] += 1
    }.toTable
  state = nimwave.slice(state, 0, 0, iw.width(state.tb), 5)
  nimwave.render(state, actions, %* ["hbox", $counts[id], ["hbox", {"border": "single", "action": "counter"}, "Count"]])

nimwave.components["counter"] = counter

proc tick*(width: int, height: int): iw.TerminalBuffer =
  result = iw.initTerminalBuffer(width, height)
  nimwave.render(
    result,
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

