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

proc tick*(width: int, height: int): iw.TerminalBuffer =
  result = iw.initTerminalBuffer(width, height)
  let mouse = if mouseQueue.len > 0: mouseQueue.popFirst else: iw.MouseInfo()
  nimwave.render(
    result,
    %* [
      "hbox",
      ["rect", ["vbox", ["rect"], ["rect"]]],
      ["rect"],
    ]
  )

