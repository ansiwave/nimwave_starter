from nimwave/web/input import nil
from web/core import nil
import tables, unicode

when not defined(emscripten):
  {.error: "You must set -d:emscripten to build for the web".}

const EM_HTML5_SHORT_STRING_LEN_BYTES = 32

type
  EmscriptenKeyboardEvent* {.bycopy.} = object
    timestamp*: cdouble
    location*: culong
    ctrlKey*: cint
    shiftKey*: cint
    altKey*: cint
    metaKey*: cint
    repeat*: cint
    charCode*: culong
    keyCode*: culong
    which*: culong
    key*: array[EM_HTML5_SHORT_STRING_LEN_BYTES, uint8]
    code*: array[EM_HTML5_SHORT_STRING_LEN_BYTES, uint8]
    charValue*: array[EM_HTML5_SHORT_STRING_LEN_BYTES, uint8]
    locale*: array[EM_HTML5_SHORT_STRING_LEN_BYTES, uint8]
  em_key_callback_func = proc (eventType: cint, keyEvent: ptr EmscriptenKeyboardEvent, userData: pointer) {.cdecl.}

proc emscripten_set_main_loop(f: proc() {.cdecl.}, a: cint, b: bool) {.importc, header: "<emscripten/emscripten.h>".}
proc emscripten_set_keydown_callback(target: cstring, userData: pointer, useCapture: bool, callback: em_key_callback_func): cint {.importc, header: "<emscripten/html5.h>".}

proc onKeyDown(eventType: cint, keyEvent: ptr EmscriptenKeyboardEvent, userData: pointer) {.cdecl.} =
  let
    key = $cast[cstring](keyEvent.key.addr)
    keys = key.toRunes
  if keys.len == 1:
    if keyEvent.ctrlKey == 0 and keyEvent.altKey == 0 and keyEvent.metaKey == 0:
      core.onChar(uint32(keys[0]))
    elif keyEvent.ctrlKey == 1 and key in input.nameToIllwaveCtrlKey:
      core.onKeyPress(input.nameToIllwaveCtrlKey[key])
  elif keys.len > 1:
    if key in input.nameToIllwaveKey:
      core.onKeyPress(input.nameToIllwaveKey[key])

proc mainLoop() {.cdecl.} =
  try:
    core.tick()
  except Exception as ex:
    stderr.writeLine(ex.msg)
    stderr.writeLine(getStackTrace(ex))

proc main() =
  core.init()
  discard emscripten_set_keydown_callback("body", nil, true, onKeyDown)
  emscripten_set_main_loop(mainLoop, 0, true)

when isMainModule:
  main()

