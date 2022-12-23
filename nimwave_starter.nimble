# Package

version       = "0.1.0"
author        = "FIXME"
description   = "FIXME"
license       = "FIXME"
srcDir        = "src"
bin           = @["tui", "gui", "web", "web_static"]

task emscripten, "Build the emscripten release version":
  # build with emscripten
  exec "nimble build web -d:release -d:emscripten"
  # modify web/index.html to include a static view of the initial page so it renders immediately
  exec "nimble run web_static"

# Dependencies

requires "nim >= 1.6.4"
requires "nimwave >= 1.2.0"
requires "paranim >= 0.12.0"
requires "paratext >= 0.13.0"
