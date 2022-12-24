from illwave as iw import `[]`, `[]=`, `==`
from nimwave/web import nil
from common import nil
from os import `/`
from strutils import nil

common.platform = common.Web

proc main*() =
  const path = "web" / "index.html"
  assert os.fileExists(path)
  common.init()
  var tb = iw.initTerminalBuffer(80, 20)
  common.tick(tb)
  let
    content = readFile(path)
    html = web.toHtml(tb, web.Options())
  const token ="{{{ NIMWAVE_CONTENT }}}" 
  assert strutils.find(content, token) != -1
  writeFile(path, strutils.replace(content, token, html))

when isMainModule:
  main()