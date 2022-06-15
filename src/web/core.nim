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
  return "<span class='col" & $position.x & "' style='$1 $2 $3' $4>".format(fg, bg, additionalStyles, mouseEvents) & $ch.ch & "</span>"

proc toLine(innerHtml: string, y: int): string =
  "<div class='row" & $y & "' style='user-select: none;'>" & innerHtml & "</div>"

proc toHtml(tb: iw.TerminalBuffer): string =
  let
    termWidth = iw.width(tb)
    termHeight = iw.height(tb)

  for y in 0 ..< termHeight:
    var line = ""
    for x in 0 ..< termWidth:
      line &= charToHtml(tb[x, y], (x, y))
    result &= toLine(line, y)

proc init*() =
  common.init()

type
  ActionKind = enum
    Insert, Update, Remove,
  Action = object
    case kind: ActionKind
    of Insert, Update:
      ch: iw.TerminalChar
    of Remove:
      discard
    x: int
    y: int

proc getLineLen(tb: iw.TerminalBuffer, line: int): int =
  if line > tb.buf[].chars.len - 1:
    0
  else:
    tb.buf[].chars[line].len

proc diff(tb: iw.TerminalBuffer, prevTb: iw.TerminalBuffer): seq[Action] =
  for y in 0 ..< max(tb.buf[].chars.len, prevTb.buf[].chars.len):
    for x in 0 ..< max(tb.getLineLen(y), prevTb.getLineLen(y)):
      if y > prevTb.buf[].chars.len-1 or x > prevTb.buf[].chars[y].len-1:
        result.add(Action(kind: Insert, ch: tb[x, y], x: x, y: y))
      elif y > tb.buf[].chars.len-1 or x > tb.buf[].chars[y].len-1:
        result.add(Action(kind: Remove, x: x, y: y))
      elif tb[x, y] != prevTb[x, y]:
        result.add(Action(kind: Update, ch: tb[x, y], x: x, y: y))

var lastTb: iw.TerminalBuffer

proc tick*() =
  var
    termWidth = int(emscripten.getClientWidth().float / fontWidth)
    termHeight = int(emscripten.getClientHeight() / fontHeight)
    tb = iw.initTerminalBuffer(termWidth, termHeight)

  common.tick(tb)

  if lastTb.buf == nil:
    let html = toHtml(tb)
    emscripten.setInnerHtml("#content", html)
    lastTb = tb
  elif lastTb != tb:
    for action in diff(tb, lastTb):
      case action.kind:
      of Insert:
        if not emscripten.insertHtml(".row" & $action.y, "beforeend", charToHtml(action.ch, (action.x, action.y))):
          doAssert emscripten.insertHtml("#content", "beforeend", toLine("", action.y))
          doAssert emscripten.insertHtml(".row" & $action.y, "beforeend", charToHtml(action.ch, (action.x, action.y))):
      of Update:
        doAssert emscripten.insertHtml(".row" & $action.y & " .col" & $action.x, "afterend", charToHtml(action.ch, (action.x, action.y)))
        doAssert emscripten.removeHtml(".row" & $action.y & " .col" & $action.x)
      of Remove:
        doAssert emscripten.removeHtml(".row" & $action.y & " .col" & $action.x)
    lastTb = tb
