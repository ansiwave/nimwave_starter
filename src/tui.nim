from illwave as iw import nil
from terminal import nil
from os import nil
from nimwave_starter/common import nil

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
  common.init()

proc tick() =
  let tb = common.tick(terminal.terminalWidth(), terminal.terminalHeight(), iw.getKey())
  iw.display(tb)

when isMainModule:
  init()
  while true:
    tick()
    os.sleep(5)
