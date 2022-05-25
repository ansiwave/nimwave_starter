from illwave as iw import `[]`, `[]=`, `==`
from nimwave import nil
import unicode, json, tables, deques
from strutils import nil

type
  Platform* = enum
    Tui, Gui, Web,

var
  platform*: Platform
  mouse: iw.MouseInfo
  mouseQueue: Deque[iw.MouseInfo]
  rune: Rune
  runeQueue: Deque[Rune]
  key: iw.Key
  keyQueue: Deque[iw.Key]

const rollingStone = strutils.splitLines(staticRead("rollingstone.txt"))

proc onMouse*(m: iw.MouseInfo) =
  mouseQueue.addLast(m)

proc onRune*(r: Rune) =
  runeQueue.addLast(r)

proc onKey*(k: iw.Key) =
  keyQueue.addLast(k)

proc init*() =
  discard

proc page(ctx: var nimwave.Context[void], node: JsonNode): nimwave.RenderProc[void] =
  var
    scrollX = 0
    scrollY = 0
  return
    proc (ctx: var nimwave.Context[void], node: JsonNode) =
      let
        width = iw.width(ctx.tb)
        height = iw.height(ctx.tb)
        bounds = (0, 0, iw.width(ctx.tb), if platform == Web: -1 else: iw.height(ctx.tb))
      ctx = nimwave.slice(ctx, scrollX, scrollY, iw.width(ctx.tb), iw.height(ctx.tb), bounds)
      nimwave.render(ctx, %* {"type": "vbox", "children": node["children"]})
      scrollX += node["scroll-x"].num.int
      scrollX = scrollX.clamp(width - iw.width(ctx.tb), 0)
      scrollY += node["scroll-y"].num.int
      scrollY = scrollY.clamp(height - iw.height(ctx.tb) + 1, 0)

proc counter(ctx: var nimwave.Context[void], node: JsonNode): nimwave.RenderProc[void] =
  var count = 0
  return
    proc (ctx: var nimwave.Context[void], node: JsonNode) =
      proc countBtn(ctx: var nimwave.Context[void], node: JsonNode) =
        const text = "Count"
        ctx = nimwave.slice(ctx, 0, 0, text.runeLen+2, iw.height(ctx.tb))
        if mouse.action == iw.MouseButtonAction.mbaPressed and iw.contains(ctx.tb, mouse):
          count += 1
        nimwave.render(ctx, %* {"type": "hbox", "border": "single", "children": [text]})
      ctx.components["count-btn"] = countBtn
      ctx = nimwave.slice(ctx, 0, 0, 20, 3)
      nimwave.render(ctx, %* {"type": "hbox", "children": [{"type": "vbox", "children": ["", $count]}, {"type": "count-btn"}]})

var oldCtx: nimwave.Context[void]

proc tick*(tb: var iw.TerminalBuffer) =
  mouse = if mouseQueue.len > 0: mouseQueue.popFirst else: iw.MouseInfo()
  rune = if runeQueue.len > 0: runeQueue.popFirst else: Rune(0)
  key = if keyQueue.len > 0: keyQueue.popFirst else: iw.Key.None

  var ctx = nimwave.initContext[void](tb)
  if oldCtx.mountedComponents != nil:
    ctx.mountedComponents = oldCtx.mountedComponents
  oldCtx = ctx
  ctx.statefulComponents["page"] = page
  ctx.statefulComponents["counter"] = counter
  nimwave.render(
    ctx,
    %* {
      "type": "page",
      "id": "main-page",
      "scroll-x":
        case platform:
        of Tui, Gui:
          case key:
          of iw.Key.Left:
            1
          of iw.Key.Right:
            -1
          else:
            0
        of Web:
          0
      ,
      "scroll-y":
        case platform:
        of Tui, Gui:
          case key:
          of iw.Key.Up:
            1
          of iw.Key.Down:
            -1
          else:
            0
        of Web:
          0
      ,
      "children": [
        {"type": "counter", "id": "counter"},
        rollingStone,
      ],
    }
  )

