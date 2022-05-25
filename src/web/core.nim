from illwave as iw import `[]`, `[]=`, `==`
from ../common import nil
import unicode
from nimwave/web import nil
from nimwave/web/emscripten import nil
from nimwave/tui/termtools/runewidth import nil
from strutils import format

common.platform = common.Web

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

proc onMouseUp*(x: int, y: int) {.exportc.} =
  var info: iw.MouseInfo
  info.button = iw.MouseButton.mbLeft
  info.action = iw.MouseButtonAction.mbaReleased
  info.x = x
  info.y = y
  common.onMouse(info)

proc onMouseMove*(x: int, y: int) {.exportc.} =
  var info: iw.MouseInfo
  info.x = x
  info.y = y
  info.move = true
  common.onMouse(info)

const
  padding = 0.81
  fontHeight = 20
  fontWidth = (fontHeight / 2) + padding

proc charToHtml(ch: iw.TerminalChar, position: tuple[x: int, y: int] = (-1, -1)): string =
  if cast[uint32](ch.ch) == 0:
    return ""
  let
    fg = web.fgColorToString(ch)
    bg = web.bgColorToString(ch)
    additionalStyles =
      if runewidth.runeWidth(ch.ch) == 2:
        # add some padding because double width characters are a little bit narrower
        # than two normal characters due to font differences
        "display: inline-block; max-width: $1px; padding-left: $2px; padding-right: $2px;".format(fontHeight, padding)
      else:
        ""
    mouseEvents =
      if position != (-1, -1):
        "onmousedown='mouseDown($1, $2)' onmouseup='mouseUp($1, $2)' onmousemove='mouseMove($1, $2)'".format(position.x, position.y)
      else:
        ""
  return "<span style='$1 $2 $3' $4>".format(fg, bg, additionalStyles, mouseEvents) & $ch.ch & "</span>"

proc toHtml(tb: iw.TerminalBuffer): string =
  let
    termWidth = iw.width(tb)
    termHeight = iw.height(tb)

  for y in 0 ..< termHeight:
    var line = ""
    for x in 0 ..< termWidth:
      line &= charToHtml(tb[x, y], (x, y))
    result &= "<div style='user-select: none;'>" & line & "</div>"

proc init*() =
  common.init()

var lastTb: iw.TerminalBuffer

proc tick*() =
  var
    termWidth = int(emscripten.getClientWidth().float / fontWidth)
    termHeight = int(emscripten.getClientHeight() / fontHeight)
    tb = iw.initTerminalBuffer(termWidth, termHeight)

  common.tick(tb)

  if lastTb != tb:
    let html = toHtml(tb)
    emscripten.setInnerHtml("#content", html)
    lastTb = tb
