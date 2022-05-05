from illwave as iw import nil
import deques
from ../common import nil

var
  keyQueue: Deque[(iw.Key, iw.MouseInfo)]
  charQueue: Deque[uint32]

proc onKeyPress*(key: iw.Key) =
  keyQueue.addLast((key, iw.gMouseInfo))

proc onKeyRelease*(key: iw.Key) =
  discard

proc onChar*(codepoint: uint32) =
  charQueue.addLast(codepoint)

proc onMouseDown*(x: int, y: int) {.exportc.} =
  iw.gMouseInfo.button = iw.MouseButton.mbLeft
  iw.gMouseInfo.action = iw.MouseButtonAction.mbaPressed
  iw.gMouseInfo.x = x
  iw.gMouseInfo.y = y
  keyQueue.addLast((iw.Key.Mouse, iw.gMouseInfo))

proc onMouseMove*(x: int, y: int) {.exportc.} =
  iw.gMouseInfo.x = x
  iw.gMouseInfo.y = y

proc onMouseUp*() {.exportc.} =
  iw.gMouseInfo.button = iw.MouseButton.mbLeft
  iw.gMouseInfo.action = iw.MouseButtonAction.mbaReleased
  keyQueue.addLast((iw.Key.Mouse, iw.gMouseInfo))

proc init*() =
  common.init()

proc tick*() =
  var
    tb: iw.TerminalBuffer
    termWidth = 80
    termHeight = 40
    rendered = false

  while keyQueue.len > 0 or charQueue.len > 0:
    let
      (key, mouseInfo) = if keyQueue.len > 0: keyQueue.popFirst else: (iw.Key.None, iw.gMouseInfo)
      ch = if charQueue.len > 0 and key == iw.Key.None: charQueue.popFirst else: 0
    iw.gMouseInfo = mouseInfo
    tb = common.tick(termWidth, termHeight, key)
    rendered = true
  if not rendered:
    tb = common.tick(termWidth, termHeight, iw.Key.None)
