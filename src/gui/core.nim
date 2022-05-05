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
  keyQueue: Deque[(iw.Key, iw.MouseInfo)]
  charQueue: Deque[uint32]
  viewHeight*: int32
  maxViewSize*: int32

const
  monoFontRaw = staticRead("assets/3270-Regular.ttf")
  charCount = text.codepointToGlyph.len
  blockCharIndex = text.codepointToGlyph["█".toRunes[0].int32]

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
  keyQueue.addLast((key, iw.gMouseInfo))

proc onKeyRelease*(key: iw.Key) =
  discard

proc onChar*(codepoint: uint32) =
  charQueue.addLast(codepoint)

proc onMouseClick*(button: iw.MouseButton, action: iw.MouseButtonAction) =
  iw.gMouseInfo.button = button
  iw.gMouseInfo.action = action
  keyQueue.addLast((iw.Key.Mouse, iw.gMouseInfo))

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
  glClearColor(text.bgColor.arr[0], text.bgColor.arr[1], text.bgColor.arr[2], text.bgColor.arr[3])
  glClear(GL_COLOR_BUFFER_BIT)
  glViewport(0, 0, GLsizei(game.windowWidth), GLsizei(game.windowHeight))

  let
    fontWidth = fontWidth()
    fontHeight = fontHeight()

  var
    termWidth = int(game.windowWidth.float / fontWidth)
    termHeight = int(game.windowHeight.float / fontHeight)

  var tb: iw.TerminalBuffer

  var rendered = false
  while keyQueue.len > 0 or charQueue.len > 0:
    let
      (key, mouseInfo) = if keyQueue.len > 0: keyQueue.popFirst else: (iw.Key.None, iw.gMouseInfo)
      ch = if charQueue.len > 0 and key == iw.Key.None: charQueue.popFirst else: 0
    iw.gMouseInfo = mouseInfo
    tb = common.tick(termWidth, termHeight, key)
    rendered = true
  if not rendered:
    tb = common.tick(termWidth, termHeight, iw.Key.None)

  termWidth = iw.width(tb)
  termHeight = iw.height(tb)

  let vWidth = termWidth.float * fontWidth
  let vHeight = termHeight.float * fontHeight
  viewHeight = int32(vHeight)

  var e = gl.copy(textEntity)
  text.updateUniforms(e, 0, 0, false)
  for y in 0 ..< termHeight:
    var line: seq[iw.TerminalChar]
    for x in 0 ..< termWidth:
      line.add(tb[x, y])
    discard text.addLine(e, baseEntity, monoFont, text.codepointToGlyph, text.textColor, line)
  e.project(vWidth, vHeight)
  e.translate(0f, 0f)
  e.scale(fontMultiplier, fontMultiplier)
  render(game, e)

