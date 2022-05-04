from illwave as iw import nil

proc init*() =
  discard

var lastKey = iw.Key.None

proc tick*(width: int, height: int, key: iw.Key): iw.TerminalBuffer =
  result = iw.newTerminalBuffer(width, height)
  if key != iw.Key.None:
    lastKey = key
  iw.write(result, "last key pressed: ", $lastKey)

