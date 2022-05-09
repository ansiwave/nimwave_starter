from illwave as iw import nil
from nimwave import nil
import unicode, json, tables, deques

var mouseQueue: Deque[iw.MouseInfo]

proc onMouse*(m: iw.MouseInfo) =
  mouseQueue.addLast(m)

proc onRune*(r: Rune) =
  discard

proc onKey*(k: iw.Key) =
  discard

proc init*() =
  discard

proc counter(state: var nimwave.State, opts: JsonNode, children: seq[JsonNode]) =
  state = nimwave.slice(state, 0, 0, iw.width(state.tb), 5)
  iw.write(state.tb, $opts)

nimwave.components["counter"] = counter

proc thing(state: var nimwave.State, opts: JsonNode, children: seq[JsonNode]) =
  let height = opts["height"].num
  state = nimwave.slice(state, 0, 0, iw.width(state.tb), height)
  iw.write(state.tb, $height)

nimwave.components["thing"] = thing

proc tick*(width: int, height: int): iw.TerminalBuffer =
  result = iw.initTerminalBuffer(width, height)
  var mouse: iw.MouseInfo
  if mouseQueue.len > 0:
    mouse = mouseQueue.popFirst
  nimwave.render(
    result,
    %* [
      "hbox",
      ["vbox", {"id": "hello", "border": "single"}, ["vbox", ["vbox", {"border": "single"}], ["vbox", {"border": "single"}]]],
      ["vbox", {"id": "goodbye", "border": "single"},
       ["counter", {"id": "counter", "mouse": mouse}],
       ["thing", {"height": 20}],
       ["thing", {"height": 10}]],
    ]
  )

