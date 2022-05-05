from illwave as iw import nil
import unicode

proc init*() =
  discard

var lastKey = -1

proc tick*(width: int, height: int, key: int): iw.TerminalBuffer =
  result = iw.newTerminalBuffer(width, height)
  if key != iw.Key.None.ord:
    lastKey = key
  if lastKey < 0:
    iw.write(result, "last key pressed: ", $lastKey)
  else:
    iw.write(result, "last key pressed: ", $cast[Rune](lastKey))

