from illwave as iw import `[]`, `[]=`, `==`
from nimwave import nil
import unicode, json, tables, deques

var
  mouse: iw.MouseInfo
  mouseQueue: Deque[iw.MouseInfo]
  rune: Rune
  runeQueue: Deque[Rune]
  key: iw.Key
  keyQueue: Deque[iw.Key]

proc onMouse*(m: iw.MouseInfo) =
  mouseQueue.addLast(m)

proc onRune*(r: Rune) =
  runeQueue.addLast(r)

proc onKey*(k: iw.Key) =
  keyQueue.addLast(k)

proc init*() =
  discard

type
  Counter = object
    cnt: int

proc counter(ctx: var nimwave.Context[Counter], data: ref Counter, node: JsonNode, children: seq[JsonNode]) =
  proc countBtn(ctx: var nimwave.Context[Counter], _: ref Counter, node: JsonNode, children: seq[JsonNode]) =
    const text = "Count"
    ctx = nimwave.slice(ctx, 0, 0, text.runeLen+2, iw.height(ctx.tb))
    if mouse.action == iw.MouseButtonAction.mbaPressed and iw.contains(ctx.tb, mouse):
      data[].cnt += 1
    nimwave.render(ctx, %* {"type": "hbox", "border": "single", "children": [text]})
  ctx.components["count-btn"] = countBtn
  ctx = nimwave.slice(ctx, 0, 0, 20, 3)
  nimwave.render(ctx, %* {"type": "hbox", "children": [{"type": "vbox", "children": ["", $data[].cnt]}, {"type": "count-btn"}]})

var oldCtx: nimwave.Context[Counter]

proc tick*(tb: var iw.TerminalBuffer) =
  mouse = if mouseQueue.len > 0: mouseQueue.popFirst else: iw.MouseInfo()
  rune = if runeQueue.len > 0: runeQueue.popFirst else: Rune(0)
  key = if keyQueue.len > 0: keyQueue.popFirst else: iw.Key.None

  var ctx = nimwave.initContext[Counter](tb)
  if oldCtx.globalData != nil and oldCtx.localData != nil:
    ctx.globalData = oldCtx.globalData
    ctx.localData = oldCtx.localData
  oldCtx = ctx
  ctx.components["counter"] = counter
  nimwave.render(
    ctx,
    %* {
      "type": "hbox",
      "children": [
        {
          "type": "vbox",
          "id": "hello",
          "border": "single",
          "children": [
            {
              "type": "vbox",
              "children": [
                {"type": "vbox", "border": "single"},
                {"type": "vbox", "border": "single"},
              ]
            },
          ],
        },
        {
          "type": "vbox",
          "id": "goodbye",
          "border": "single",
          "children": [
            {"type": "counter", "id": "counter"},
          ],
        },
      ],
    }
  )

