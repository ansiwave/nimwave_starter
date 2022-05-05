import paranim/opengl
import paranim/gl, paranim/gl/entities
from paranim/glm import vec4
from paratext/gl/text as ptext import nil
import paratext
from nimwave/gui/text import nil
import deques
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
  baseEntity: ptext.UncompiledTextEntity
  textEntity: text.AnsiwaveTextEntity
  fontMultiplier* = 1/4
  charQueue: Deque[int]
  mouseQueue: Deque[iw.MouseInfo]

const
  monoFontRaw = staticRead("../../web/3270-Regular.ttf")
  charCount = text.codepointToGlyph.len
  blockCharIndex = text.codepointToGlyph["█".toRunes[0].int32]
  bgColor = glm.vec4(0f/255f, 16f/255f, 64f/255f, 0.95f)
  textColor = glm.vec4(230f/255f, 235f/255f, 1f, 1f)

let
  monoFont = initFont(ttf = monoFontRaw, fontHeight = 80,
                       ranges = text.charRanges,
                       bitmapWidth = 2048, bitmapHeight = 2048, charCount = charCount)
  blockWidth = monoFont.chars[blockCharIndex].xadvance

proc fontWidth*(): float =
  blockWidth * fontMultiplier

proc fontHeight*(): float =
  monoFont.height * fontMultiplier

proc onKeyPress*(key: iw.Key) =
  charQueue.addLast(key.ord)

proc onKeyRelease*(key: iw.Key) =
  discard

proc onChar*(codepoint: uint32) =
  charQueue.addLast(codepoint.int)

proc onMouseClick*(button: iw.MouseButton, action: iw.MouseButtonAction) =
  var info: iw.MouseInfo
  info.button = button
  info.action = action
  mouseQueue.addLast(info)

proc onMouseUpdate*(xpos: float, ypos: float) =
  iw.gMouseInfo.x = int(xpos / fontWidth() - 0.25)
  iw.gMouseInfo.y = int(ypos / fontHeight() - 0.25)

proc onMouseMove*(xpos: float, ypos: float) =
  onMouseUpdate(xpos, ypos)

proc onWindowResize*(windowWidth: int, windowHeight: int) =
  discard

proc init*(game: var Game) =
  doAssert glInit()

  glEnable(GL_BLEND)
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  glDisable(GL_CULL_FACE)
  glDisable(GL_DEPTH_TEST)

  baseEntity = ptext.initTextEntity(monoFont)
  textEntity = compile(game, text.initInstancedEntity(baseEntity, monoFont))

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

  var tb: iw.TerminalBuffer

  if charQueue.len == 0 and mouseQueue.len == 0:
    tb = common.tick(termWidth, termHeight, iw.Key.None.ord)
  else:
    while charQueue.len > 0:
      let ch = charQueue.popFirst
      tb = common.tick(termWidth, termHeight, ch)
    while mouseQueue.len > 0:
      iw.gMouseInfo = mouseQueue.popFirst
      tb = common.tick(termWidth, termHeight, iw.Key.Mouse.ord)

  termWidth = iw.width(tb)
  termHeight = iw.height(tb)

  let vWidth = termWidth.float * fontWidth
  let vHeight = termHeight.float * fontHeight

  var e = gl.copy(textEntity)
  text.updateUniforms(e, 0, 0, false)
  for y in 0 ..< termHeight:
    var line: seq[iw.TerminalChar]
    for x in 0 ..< termWidth:
      line.add(tb[x, y])
    discard text.addLine(e, baseEntity, monoFont, text.codepointToGlyph, textColor, line)
  e.project(vWidth, vHeight)
  e.translate(0f, 0f)
  e.scale(fontMultiplier, fontMultiplier)
  render(game, e)

