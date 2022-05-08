import paranim/opengl
import paranim/gl, paranim/gl/entities
from paranim/glm import vec4
from paratext/gl/text import nil
from paratext import nil
from nimwave/gui import nil
import tables
from ../common import nil
from illwave as iw import `[]`, `[]=`
import unicode

type
  Game* = object of RootGame
    deltaTime*: float
    totalTime*: float
    windowWidth*: int32
    windowHeight*: int32
    worldWidth*: int32
    worldHeight*: int32
    mouseX*: float
    mouseY*: float

var
  game*: Game
  baseEntity: text.UncompiledTextEntity
  textEntity: gui.NimwaveTextEntity
  fontMultiplier* = 1/4

const
  monoFontRaw = staticRead("../../web/3270-Regular.ttf")
  charCount = gui.codepointToGlyph.len
  blockCharIndex = gui.codepointToGlyph["█".toRunes[0].int32]
  bgColor = glm.vec4(0f/255f, 16f/255f, 64f/255f, 0.95f)
  textColor = glm.vec4(230f/255f, 235f/255f, 1f, 1f)

let
  monoFont = paratext.initFont(ttf = monoFontRaw, fontHeight = 80,
                               ranges = gui.charRanges,
                               bitmapWidth = 2048, bitmapHeight = 2048, charCount = charCount)
  blockWidth = monoFont.chars[blockCharIndex].xadvance

proc fontWidth*(): float =
  blockWidth * fontMultiplier

proc fontHeight*(): float =
  monoFont.height * fontMultiplier

proc onKeyPress*(key: iw.Key) =
  common.onKey(key)

proc onKeyRelease*(key: iw.Key) =
  discard

proc onChar*(codepoint: uint32) =
  common.onRune(cast[Rune](codepoint))

proc onMouseClick*(button: iw.MouseButton, action: iw.MouseButtonAction, xpos: float, ypos: float) =
  var info: iw.MouseInfo
  info.button = button
  info.action = action
  info.x = int(xpos / fontWidth() - 0.25)
  info.y = int(ypos / fontHeight() - 0.25)
  common.onMouse(info)

proc onMouseMove*(xpos: float, ypos: float) =
  var info: iw.MouseInfo
  info.x = int(xpos / fontWidth() - 0.25)
  info.y = int(ypos / fontHeight() - 0.25)
  common.onMouse(info)

proc onWindowResize*(windowWidth: int, windowHeight: int) =
  discard

proc init*(game: var Game) =
  doAssert glInit()

  glEnable(GL_BLEND)
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  glDisable(GL_CULL_FACE)
  glDisable(GL_DEPTH_TEST)

  baseEntity = text.initTextEntity(monoFont)
  textEntity = compile(game, gui.initInstancedEntity(baseEntity, monoFont))

proc tick*(game: Game) =
  glClearColor(bgColor.arr[0], bgColor.arr[1], bgColor.arr[2], bgColor.arr[3])
  glClear(GL_COLOR_BUFFER_BIT)
  glViewport(0, 0, GLsizei(game.windowWidth), GLsizei(game.windowHeight))

  let
    fontWidth = fontWidth()
    fontHeight = fontHeight()

  var
    termWidth = int(game.windowWidth.float / fontWidth)
    termHeight = int(game.windowHeight.float / fontHeight)

  var tb = common.tick(termWidth, termHeight)

  termWidth = iw.width(tb)
  termHeight = iw.height(tb)

  let vWidth = termWidth.float * fontWidth
  let vHeight = termHeight.float * fontHeight

  var e = gl.copy(textEntity)
  gui.updateUniforms(e, 0, 0, false)
  for y in 0 ..< termHeight:
    var line: seq[iw.TerminalChar]
    for x in 0 ..< termWidth:
      line.add(tb[x, y])
    discard gui.addLine(e, baseEntity, monoFont, gui.codepointToGlyph, textColor, line)
  e.project(vWidth, vHeight)
  e.translate(0f, 0f)
  e.scale(fontMultiplier, fontMultiplier)
  render(game, e)

