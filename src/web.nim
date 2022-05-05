from illwave as iw import nil
from common import nil

when not defined(emscripten):
  {.error: "You must set -d:emscripten to build for the web".}

proc init() =
  common.init()

proc tick() =
  let tb = common.tick(100, 100, iw.Key.None)

proc main() =
  init()
  tick()

when isMainModule:
  main()
