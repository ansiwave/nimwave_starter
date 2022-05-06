from illwave as iw import `[]`, `[]=`, `==`
from ../common import nil
import unicode
from nimwave/web/text import nil
from nimwave/web/emscripten import nil

proc onKeyPress*(key: iw.Key) =
  common.onKey(key)

proc onKeyRelease*(key: iw.Key) =
  discard

proc onChar*(codepoint: uint32) =
  common.onRune(cast[Rune](codepoint))

proc onMouseDown*(x: int, y: int) {.exportc.} =
  var info: iw.MouseInfo
  info.button = iw.MouseButton.mbLeft
  info.action = iw.MouseButtonAction.mbaPressed
  info.x = x
  info.y = y
  common.onMouse(info)

proc onMouseMove*(x: int, y: int) {.exportc.} =
  iw.gMouseInfo.x = x
  iw.gMouseInfo.y = y

proc onMouseUp*() {.exportc.} =
  var info: iw.MouseInfo
  info.button = iw.MouseButton.mbLeft
  info.action = iw.MouseButtonAction.mbaReleased
  common.onMouse(info)

proc init*() =
  common.init()

var lastTb: iw.TerminalBuffer

proc tick*() =
  var
    termWidth = 80
    termHeight = 40
    tb = common.tick(termWidth, termHeight)

  if lastTb == nil or lastTb[] != tb[]:
    let html = text.toHtml(tb)
    emscripten.setInnerHtml("#content", html)
    lastTb = tb
