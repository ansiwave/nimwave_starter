from illwave as iw import nil
from terminal import nil
from os import nil

proc deinit() =
  iw.deinit()
  terminal.showCursor()

proc init() =
  iw.init(fullscreen=true, mouse=true)
  setControlCHook(
    proc () {.noconv.} =
      deinit()
      quit(0)
  )
  terminal.hideCursor()

var lastKey = iw.Key.None

proc tick() =
  var tb = iw.newTerminalBuffer(terminal.terminalWidth(), terminal.terminalHeight())
  let key = iw.getKey()
  if key != iw.Key.None:
    lastKey = key
  iw.write(tb, "last key pressed: ", $lastKey)
  iw.display(tb)

when isMainModule:
  init()
  while true:
    tick()
    os.sleep(5)
