when defined(emscripten):
  --nimcache:tmp

  --os:linux
  --cpu:wasm32
  --cc:clang
  when defined(windows):
    --clang.exe:emcc.bat
    --clang.linkerexe:emcc.bat
    --clang.cpp.exe:emcc.bat
    --clang.cpp.linkerexe:emcc.bat
  else:
    --clang.exe:emcc
    --clang.linkerexe:emcc
    --clang.cpp.exe:emcc
    --clang.cpp.linkerexe:emcc
  --listCmd

  --mm:orc
  --exceptions:goto
  --define:noSignalHandler

  --define:useMalloc
  --opt:size
  --threads:off

  switch("passL", "-o web/index.html --shell-file src/web/index.html -s EXPORTED_FUNCTIONS=\"['_main', '_onMouseDown', '_onMouseMove', '_onMouseUp']\" -s EXPORTED_RUNTIME_METHODS=\"['ccall']\"")
else:
  --mm:orc
