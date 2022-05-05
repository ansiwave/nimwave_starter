import paranim/glfw
import tables, bitops
from gui/core import nil
from nimwave/gui/input import nil

var
  window: GLFWWindow
  pixelDensity*: float

proc keyCallback(window: GLFWWindow, key: int32, scancode: int32, action: int32, mods: int32) {.cdecl.} =
  if key < 0:
    return
  let keys =
    if 0 != bitand(mods, GLFW_MOD_CONTROL):
      input.glfwToIllwaveCtrlKey
    else:
      input.glfwToIllwaveKey
  if keys.hasKey(key):
    let iwKey = keys[key]
    if action in {GLFW_PRESS, GLFW_REPEAT}:
      core.onKeyPress(iwKey)
    elif action == GLFW_RELEASE:
      core.onKeyRelease(iwKey)

proc charCallback(window: GLFWWindow, codepoint: uint32) {.cdecl.} =
  core.onChar(codepoint)

proc updateCoords(xpos: var float64, ypos: var float64) =
  let mult = pixelDensity
  xpos = xpos * mult
  ypos = ypos * mult

proc cursorPosCallback(window: GLFWWindow, xpos: float64, ypos: float64) {.cdecl.} =
  var
    mouseX = xpos
    mouseY = ypos
  updateCoords(mouseX, mouseY)
  core.onMouseMove(mouseX, mouseY)

proc mouseButtonCallback(window: GLFWWindow, button: int32, action: int32, mods: int32) {.cdecl.} =
  if input.glfwToIllwaveMouseButton.hasKey(button) and input.glfwToIllwaveMouseAction.hasKey(action):
    var
      xpos: float64
      ypos: float64
    getCursorPos(window, xpos.addr, ypos.addr)
    updateCoords(xpos, ypos)
    core.onMouseUpdate(xpos, ypos)
    core.onMouseClick(input.glfwToIllwaveMouseButton[button], input.glfwToIllwaveMouseAction[action])

proc frameSizeCallback(window: GLFWWindow, width: int32, height: int32) {.cdecl.} =
  core.game.windowWidth = width
  core.game.windowHeight = height
  core.onWindowResize(core.game.windowWidth, core.game.windowHeight)

proc scrollCallback(window: GLFWWindow, xoffset: float64, yoffset: float64) {.cdecl.} =
  discard

proc main*() =
  doAssert glfwInit()

  glfwWindowHint(GLFWContextVersionMajor, 3)
  glfwWindowHint(GLFWContextVersionMinor, 3)
  glfwWindowHint(GLFWOpenglForwardCompat, GLFW_TRUE) # Used for Mac
  glfwWindowHint(GLFWOpenglProfile, GLFW_OPENGL_CORE_PROFILE)
  glfwWindowHint(GLFWResizable, GLFW_TRUE)
  glfwWindowHint(GLFWTransparentFramebuffer, GLFW_TRUE)

  window = glfwCreateWindow(1024, 768, "NIMWAVE Starter")
  if window == nil:
    quit(-1)

  window.makeContextCurrent()
  glfwSwapInterval(1)

  discard window.setKeyCallback(keyCallback)
  discard window.setCharCallback(charCallback)
  discard window.setMouseButtonCallback(mouseButtonCallback)
  discard window.setCursorPosCallback(cursorPosCallback)
  discard window.setFramebufferSizeCallback(frameSizeCallback)
  discard window.setScrollCallback(scrollCallback)

  var width, height: int32
  window.getFramebufferSize(width.addr, height.addr)

  var windowWidth, windowHeight: int32
  window.getWindowSize(windowWidth.addr, windowHeight.addr)

  window.frameSizeCallback(width, height)

  core.init(core.game)

  pixelDensity = max(1f, width / windowWidth)
  core.fontMultiplier *= pixelDensity

  core.game.totalTime = glfwGetTime()

  while not window.windowShouldClose:
    let ts = glfwGetTime()
    core.game.deltaTime = ts - core.game.totalTime
    core.game.totalTime = ts
    core.tick(core.game)
    window.swapBuffers()
    glfwPollEvents()

  window.destroyWindow()
  glfwTerminate()

when isMainModule:
  main()

