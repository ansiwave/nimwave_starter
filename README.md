This is a sample NIMWAVE program. The main code is located in `src/common.nim`.

```
# develop for the terminal
nimble run tui

# build release version for the terminal
nimble build tui -d:release


# develop for OpenGL
nimble run gui

# build release version for OpenGL
nimble build gui -d:release --app:gui


# build release version for the web
nimble emscripten
```

NOTE: To build for the web, you must install Emscripten:

```
git clone https://github.com/emscripten-core/emsdk
cd emsdk
./emsdk install 3.1.0
./emsdk activate 3.1.0
# add the dirs that are printed by the last command to your PATH
```
