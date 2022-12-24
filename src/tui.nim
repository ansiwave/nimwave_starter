from illwave as iw import nil
from nimwave as nw import nil
from terminal import nil
from os import nil
from common import nil
import unicode

common.platform = common.Tui

proc deinit() =
  iw.deinit()
  terminal.showCursor()

proc init(ctx: var nw.Context[common.State]) =
  terminal.enableTrueColors()
  iw.init()
  setControlCHook(
    proc () {.noconv.} =
      deinit()
      quit(0)
  )
  terminal.hideCursor()
  common.init(ctx)

proc tick(ctx: var nw.Context[common.State], prevTb: var iw.TerminalBuffer, mouseInfo: var iw.MouseInfo) =
  let key = iw.getKey(mouseInfo)
  if key == iw.Key.Mouse:
    common.onMouse(mouseInfo)
  elif key in {iw.Key.Space .. iw.Key.Tilde}:
    common.onChar(cast[Rune](key.ord))
  elif key != iw.Key.None:
    common.onKey(key)
  ctx.tb = iw.initTerminalBuffer(terminal.terminalWidth(), terminal.terminalHeight())
  common.tick(ctx)
  iw.display(ctx.tb, prevTb)

proc main() =
  var
    ctx: nw.Context[common.State]
    prevTb: iw.TerminalBuffer
    mouseInfo: iw.MouseInfo
  init(ctx)
  while true:
    try:
      tick(ctx, prevTb, mouseInfo)
      prevTb = ctx.tb
    except Exception as ex:
      deinit()
      raise ex
    os.sleep(5)

when isMainModule:
  main()
