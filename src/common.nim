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

proc scroll(ctx: var nimwave.Context[void], node: JsonNode): nimwave.RenderProc[void] =
  var
    scrollX = if "scroll-x-start" in node: node["scroll-x-start"].num.int else: 0
    scrollY = if "scroll-y-start" in node: node["scroll-y-start"].num.int else: 0
  return
    proc (ctx: var nimwave.Context[void], node: JsonNode) =
      let
        width = iw.width(ctx.tb)
        height = iw.height(ctx.tb)
        bounds =
          if platform == Web:
            (0, 0, -1, -1)
          else:
            (0, 0, iw.width(ctx.tb), iw.height(ctx.tb))
      var ctx = nimwave.slice(ctx, scrollX, scrollY, iw.width(ctx.tb), iw.height(ctx.tb), bounds)
      nimwave.render(ctx, %* node["child"])
      if "scroll-x-change" in node:
        scrollX += node["scroll-x-change"].num.int
        let minX = width - iw.width(ctx.tb)
        if minX < 0:
          scrollX = scrollX.clamp(minX, 0)
      if "scroll-y-change" in node:
        scrollY += node["scroll-y-change"].num.int
        let minY = height - iw.height(ctx.tb) + 1
        if minY < 0:
          scrollY = scrollY.clamp(minY, 0)

proc counter(ctx: var nimwave.Context[void], node: JsonNode): nimwave.RenderProc[void] =
  var count = 0
  return
    proc (ctx: var nimwave.Context[void], node: JsonNode) =
      proc countBtn(ctx: var nimwave.Context[void], node: JsonNode) =
        const text = "Count"
        ctx = nimwave.slice(ctx, 0, 0, text.runeLen+2, iw.height(ctx.tb))
        if mouse.action == iw.MouseButtonAction.mbaPressed and iw.contains(ctx.tb, mouse):
          count += 1
        nimwave.render(ctx, %* {"type": "nimwave.hbox", "border": "single", "children": [text]})
      ctx.components["count-btn"] = countBtn
      ctx = nimwave.slice(ctx, 0, 0, 20, 3)
      nimwave.render(ctx, %* {"type": "nimwave.hbox", "children": [{"type": "nimwave.vbox", "children": ["", $count]}, {"type": "count-btn"}]})

proc textField(ctx: var nimwave.Context[void], node: JsonNode, data: ref tuple[text: string, cursorX: int]): nimwave.RenderProc[void] =
  let id = node["id"].str
  return
    proc (ctx: var nimwave.Context[void], node: JsonNode) =
      proc textArea(ctx: var nimwave.Context[void], node: JsonNode) =
        nimwave.render(ctx, %* {"type": "scroll", "child": data[].text, "id": id & "-scroll"})
      ctx.components["text-area"] = textArea
      ctx = nimwave.slice(ctx, 0, 0, 10, 3)
      nimwave.render(ctx, %* {"type": "nimwave.hbox", "border": "single", "children": [{"type": "text-area"}]})

proc tempConverter(ctx: var nimwave.Context[void], node: JsonNode): nimwave.RenderProc[void] =
  var data = new tuple[text: string, cursorX: int]
  let comp = textField(ctx, node, data)
  return
    proc (ctx: var nimwave.Context[void], node: JsonNode) =
      ctx.components["text-field"] = comp
      nimwave.render(ctx, %* {"type": "text-field"})

var ctx = nimwave.initContext[void]()
ctx.statefulComponents["scroll"] = scroll
ctx.statefulComponents["counter"] = counter
ctx.statefulComponents["temp-converter"] = tempConverter

proc tick*(tb: var iw.TerminalBuffer) =
  mouse = if mouseQueue.len > 0: mouseQueue.popFirst else: iw.MouseInfo()
  rune = if runeQueue.len > 0: runeQueue.popFirst else: Rune(0)
  key = if keyQueue.len > 0: keyQueue.popFirst else: iw.Key.None

  ctx.tb = tb
  nimwave.render(
    ctx,
    %* {
      "type": "scroll",
      "id": "main-page",
      "scroll-x-change":
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
      "scroll-y-change":
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
      "child":
        {
          "type": "nimwave.vbox",
          "children": [
            {"type": "counter", "id": "counter"},
            {"type": "temp-converter", "id": "temp-converter"},
            rollingStone,
          ]
        }
      ,
    }
  )

