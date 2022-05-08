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

proc thing(state: var nimwave.State, opts: JsonNode, children: seq[JsonNode]) =
  iw.write(state.tb, $opts)

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
      ["rect", {"id": "hello"}, ["vbox", ["rect", {"id": "wassup"}], ["rect"]]],
      ["rect", {"id": "goodbye"}, ["thing", {"id": "wassup", "mouse": mouse}]],
    ]
  )

