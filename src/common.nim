from illwave as iw import nil
from nimwave/tui import nil
import unicode

var lastKey = ""

proc onMouse*(m: iw.MouseInfo) =
  discard

proc onRune*(r: Rune) =
  lastKey = $r

proc onKey*(k: iw.Key) =
  lastKey = $k

proc init*() =
  discard

proc tick*(width: int, height: int): iw.TerminalBuffer =
  result = iw.newTerminalBuffer(width, height)
  tui.write(result, 0, 0, "\e[38;2;155;55;50mlast\e[0m key pressed: " & lastKey)

