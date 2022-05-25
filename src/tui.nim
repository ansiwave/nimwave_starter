from illwave as iw import nil
from terminal import nil
from os import nil
from common import nil
import unicode

common.platform = common.Tui

var prevTb: iw.TerminalBuffer

proc deinit() =
  iw.deinit()
  terminal.showCursor()

proc init() =
  terminal.enableTrueColors()
  iw.init()
  setControlCHook(
    proc () {.noconv.} =
      deinit()
      quit(0)
  )
  terminal.hideCursor()
  common.init()
  prevTb = iw.initTerminalBuffer(terminal.terminalWidth(), terminal.terminalHeight())

var mouseInfo: iw.MouseInfo

proc tick() =
  let key = iw.getKey(mouseInfo)
  if key == iw.Key.Mouse:
    common.onMouse(mouseInfo)
  elif key in {iw.Key.Space .. iw.Key.Tilde}:
    common.onRune(cast[Rune](key.ord))
  elif key != iw.Key.None:
    common.onKey(key)
  var tb = iw.initTerminalBuffer(terminal.terminalWidth(), terminal.terminalHeight())
  common.tick(tb)
  iw.display(tb, prevTb)
  prevTb = tb

proc main() =
  init()
  while true:
    tick()
    os.sleep(5)

when isMainModule:
  main()
