from illwave as iw import nil
import deques
from ../common import nil

var
  charQueue: Deque[int]
  mouseQueue: Deque[iw.MouseInfo]

proc onKeyPress*(key: iw.Key) =
  charQueue.addLast(key.ord)

proc onKeyRelease*(key: iw.Key) =
  discard

proc onChar*(codepoint: uint32) =
  charQueue.addLast(codepoint.int)

proc onMouseDown*(x: int, y: int) {.exportc.} =
  var info: iw.MouseInfo
  info.button = iw.MouseButton.mbLeft
  info.action = iw.MouseButtonAction.mbaPressed
  info.x = x
  info.y = y
  mouseQueue.addLast(info)

proc onMouseMove*(x: int, y: int) {.exportc.} =
  iw.gMouseInfo.x = x
  iw.gMouseInfo.y = y

proc onMouseUp*() {.exportc.} =
  var info: iw.MouseInfo
  info.button = iw.MouseButton.mbLeft
  info.action = iw.MouseButtonAction.mbaReleased
  mouseQueue.addLast(info)

proc init*() =
  common.init()

proc tick*() =
  var
    tb: iw.TerminalBuffer
    termWidth = 80
    termHeight = 40

  if charQueue.len == 0 and mouseQueue.len == 0:
    tb = common.tick(termWidth, termHeight, iw.Key.None.ord)
  else:
    while charQueue.len > 0:
      let ch = charQueue.popFirst
      tb = common.tick(termWidth, termHeight, ch)
    while mouseQueue.len > 0:
      iw.gMouseInfo = mouseQueue.popFirst
      tb = common.tick(termWidth, termHeight, iw.Key.Mouse.ord)
