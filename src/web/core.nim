from illwave as iw import `[]`, `[]=`, `==`
from ../common import nil
import unicode
from nimwave/web import nil
from nimwave/web/emscripten import nil
from strutils import format

common.platform = common.Web

proc onKeyPress*(key: iw.Key) =
  common.onKey(key)

proc onKeyRelease*(key: iw.Key) =
  discard

proc onChar*(codepoint: uint32) =
  common.onChar(cast[Rune](codepoint))

var
  lastButton: iw.MouseButton
  lastAction: iw.MouseButtonAction

proc onMouseDown*(x: int, y: int) {.exportc.} =
  var info: iw.MouseInfo
  info.button = iw.MouseButton.mbLeft
  info.action = iw.MouseButtonAction.mbaPressed
  info.x = x
  info.y = y
  common.onMouse(info)
  lastButton = iw.MouseButton.mbLeft
  lastAction = iw.MouseButtonAction.mbaPressed

proc onMouseUp*(x: int, y: int) {.exportc.} =
  var info: iw.MouseInfo
  info.button = iw.MouseButton.mbLeft
  info.action = iw.MouseButtonAction.mbaReleased
  info.x = x
  info.y = y
  common.onMouse(info)
  lastButton = iw.MouseButton.mbLeft
  lastAction = iw.MouseButtonAction.mbaReleased

proc onMouseMove*(x: int, y: int) {.exportc.} =
  var info: iw.MouseInfo
  info.button = lastButton
  info.action = lastAction
  info.x = x
  info.y = y
  info.move = true
  common.onMouse(info)

const
  padding = 0.81
  fontHeight = 20
  fontWidth = (fontHeight / 2) + padding
  options = web.Options(
    normalWidthStyle: "",
    # add some padding because double width characters are a little bit narrower
    # than two normal characters due to font differences
    doubleWidthStyle: "display: inline-block; max-width: $1px; padding-left: $2px; padding-right: $2px;".format(fontHeight, padding),
    mouseDownFn: "mouseDown",
    mouseUpFn: "mouseUp",
    mouseMoveFn: "mouseMove",
  )

proc init*() =
  common.init()

var prevTb: iw.TerminalBuffer

proc tick*() =
  var
    termWidth = int(emscripten.getClientWidth().float / fontWidth)
    termHeight = int(emscripten.getClientHeight() / fontHeight)
    tb = iw.initTerminalBuffer(termWidth, termHeight)

  common.tick(tb)
  web.display(tb, prevTb, "#content", options)
  prevTb = tb
