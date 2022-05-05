from illwave as iw import nil
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
  iw.write(result, "last key pressed: ", lastKey)

