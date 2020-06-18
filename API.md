# Nico API

## System
`init(org: string, app: string)`
Initialises Nico, must be called before any other Nico operation.
`org`: organisation name, used for storing preference data
`app`: application name, used for storing preference data
---
`shutdown()`
Shuts down Nico and ends the application.
---
`createWindow(title: string, width: int, height: int, scale: int, fullscreen: bool)`
Creates a window with a title of `title` and a canvas of size `width`x`height` and draws it scaled up by `scale` times.
---
`run(initFunc: proc(), updateFunc: proc(dt: float32), drawFunc: proc())`
Runs Nico, first runs `initFunc`.
Every frame it calls `updateFunc` passing `dt` as the time since the last call, and then `drawFunc`.
Continues to run until `shutdown` is called
---
## Input
```
type NicoButton = enum
  pcLeft
  pcRight
  pcUp
  pcDown
  pcA
  pcB
  pcX
  pcY
  pcL1
  pcL2
  pcL3
  pcR1
  pcR2
  pcR3
  pcStart
  pcBack
```
Common button inputs compatible with most gamepads or keyboard

### Buttons
---
`btn(b: NicoButton): bool`
Returns true while the button `b` is held down by any player
---
`btnp(b: NicoButton): bool`
Returns true as the button `b` is pressed by any player
---
`btnup(b: NicoButton): bool`
Returns true as the button `b` is released by any player
---
`btnpr(b: NicoButton, repeat: int = 48): bool`
Returns true as the button `b` is pressed and again every `repeat` frames while held down by any player.
---
---
*Also available are versions which take a player id*
`btn(b: NicoButton, player: int): bool`
Returns true while the button `b` is held down by `player`
---
`btnp(b: NicoButton, player: int): bool`
Returns true as the button `b` is pressed by `player`
---
`btnup(b: NicoButton, player: int): bool`
Returns true as the button `b` is released by `player`
---
`btnpr(b: NicoButton, player: int, repeat: int = 48): bool`
Returns true as the button `b` is pressed and again every `repeat` frames while held down by `player`.
---

### Joysticks
```
type NicoAxis = enum
  pcXAxis
  pcYAxis
  pcXAxis2
  pcYAxis2
  pcLTrigger
  pcRTrigger
```
`jaxis(axis: NicoAxis, player: int): float32`
Returns the value of a joystick axis on `player`'s controller
---

### Mouse
`mouse(): (int,int)`
returns the current mouse position in canvas units `0,0` being the top left of the window
---
`mouserel(): (float32,float32)` 
returns the change in mouse position in canvas units but with subpixel precision
---
`mousebtn(b: range[0..2]): bool`
returns while the mouse button `b` is down. `0 = left` `1 = middle` `2 = right`
---
`mousebtnp(b: range[0..2]): bool`
returns as the mouse button `b` is pressed.
---
`mousebtnpr(b: range[0..2], repeat: int = 48): bool`
returns as the mouse button `b` is pressed and again every `repeat` frames.
---
### Keyboard
`key(keycode: Keycode): bool`
Returns true when key with `keycode` is down
---
`keyp(keycode: Keycode): bool`
Returns true as key with `keycode` is pressed
---
`keypr(keycode: Keycode, repeat: int = 48): bool`
Returns true as key with `keycode` is pressed and again every `repeat` frames
---
## Graphics
### Colors
`setColor(color: int)`
Sets the current drawing color to the palette index `color`
---
`getColor(): int`
Gets the current drawing color
---
### Pixels
`pset(x,y: int)`
Sets pixel to current color, no effect if out of bounds
---
`pget(x,y: int): int`
Gets the pixel color at `x,y`, returns `0` if out of bounds
---
### Circles and Ellipses
`circ(cx,cy,r: int)`
Draws a circle centered at `cx,cy` with radius `r`
---
`circfill(cx,cy,r: int)`
Draws a filled circle centered at `cx,cy` with radius `r`
---
`ellipsefill(cx,cy,rx,ry: int)`
Draws a filled ellipse centered at `cx,cy` with radius `rx,ry`
---
### Lines
`line(x0,y0,x1,y1: int)`
Draws a line between `x0,y0` and `x1,y1`
---
`hline(x0,y,x1: int)`
Draws a horizontal line between `x0` and `x1` on `y`
---
`vline(x,y0,y1: int)`
Draws a vertical line between `y0` and `y1` on `x`
---
### Rectangles
`rect(x0,y0,x1,y1: int)`
Draws a rectangle from `x0,y0` to `x1,y1`
---
`rectfill(x0,y0,x1,y1: int)`
Draws a filled rectangle from `x0,y0` to `x1,y1`
---
`rrect(x0,y0,x1,y1: int, r: int = 1)`
Draws a rounded rectangle from `x0,y0` to `x1,y1` with corner radius `r`
---
`rrectfill(x0,y0,x1,y1: int, r: int = 1)`
Draws a filled rounded rectangle from `x0,y0` to `x1,y1` with corner radius `r`
---
`box(x,y,w,h: int)`
Draws a rectangle with top left corner `x,y` of width and height `w,h`
---
`boxfill(x,y,w,h: int)`
Draws a filled rectangle with top left corner `x,y` of width and height `w,h`
---
`boxfill(x,y,w,h: int)`
Draws a filled rectangle with top left corner `x,y` of width and height `w,h`
---
`rectCorner(x0,y0,x1,y1: int)`
Draws only the corners of a rectangle
---
`rrectCorner(x0,y0,x1,y1: int, r: int = 1)`
Draws only the corners of a rounded rectangle
---
---
### Triangles
`trifill(ax,ay,bx,by,cx,cy: int)`
Draws a filled triangle between points `(ax,ay),(bx,by),(cx,cy)`
---
### Quads
`quadfill(ax,ay,bx,by,cx,cy,dx,dy: int)`
Draws a filled quad between points `(ax,ay),(bx,by),(cx,cy),(dx,dy)`
---
### Sprites
`loadSpritesheet(index: int, filename: string, sw, sh: int = 8)`
Loads the file at `filename` (must be a PNG file) into spritesheet slot `index`.
Each sprite will be of size `sw,sh`
---
`setSpritesheet(index: int)`
Sets the current spritesheet to `index`
---
`spr(spr: int, x,y: int)`
Draws sprites `spr` from the current spritesheet at `x,y`.
---
`spr(spr: int, x,y: int, w,h: int = 1, hflip, vflip: bool = false)`
Draws `w,h` sprites starting from `spr` from the current spritesheet at `x,y`, optionally flipped.
---
`sprs(spr: int, x,y: int, w,h: int = 1, dw,dh: int = 1, hflip, vflip: bool = false)`
Draws `w,h` tiles starting from `spr` from the current spritesheet at `x,y`, optionally flipped and scaled to `dw,dh` tiles.
---
### Text
`loadFont(index: int, filename: string)`
Loads font at `filename` into font index `index`.
`filename` must be a PNG file with a specific format see example in `examples/assets/font.png`.
`filename.dat` should also exist and contain a list of characters included in the font, see example in `examples/assets/font.png.dat`.
---
`setFont(index: int)`
sets the current font to the font loaded into index `index`
---
`glyph(c: Rune, x,y: int)`
Draws a unicode character `c` at `x,y`
---
`print(text: string, x,y: int)`
Draws `text` at `x,y` in current color
---
`printc(text: string, x,y: int)`
Draws `text` centered at `x,y` in current color
---
`printr(text: string, x,y: int)`
Draws `text` right aligned at `x,y` in current color
---
`glyphWidth(c: Rune): int`
returns the width of a unicode character `c`
---
`textWidth(text: string): int`
returns the width of `text`
---
### Tilemap
`newMap(index: int, w,h: int, tw,th: int = 8)`
create a new tilemap in index `index` with size `w,h` and each tile of size `tw,th`
---
`loadMap(index: int, filename: string)`
loads tilemap at `filename` into index `index`
`filename` should be in Tiled's json format.
---
`saveMap(index: int, filename: string)`
saves the tilemap in slot `index` to `filename` in Tiled's json format.
---
`setMap(index: int)`
use the map at index `index` for future map calls
---
`mapWidth(): int`
returns the current map's width in tiles
---
`mapHeight(): int`
returns the current map's height in tiles
---
`mapDraw(tx,ty,tw,th: int, dx,dy: int, dw,dh: int = -1, loop: bool = false, ox,oy: int = 0)`
draws current tilemap to the canvas at `dx,dy` starting from tile `tx,ty` and drawing `tw,th` tiles.
`dw,dh` can be used for scaling the tilemap.
`loop` will repeat the tilemap
`ox,oy` specifies a pixel offset for tiles
---
### Palettes
`loadPaletteFromGPL(filename: string): Palette`
Returns a loaded palette from the given filename in Gimp Palette Format.
---
`loadPaletteCGA(): Palette`
Returns a 4 color CGA Palette (Black, Cyan, Magenta, White)
---
`loadPalettePico8(): Palette`
Returns the 16 color "Pico-8" palette
---
`loadPalettePico8Extra(): Palette`
Returns the 16 color "Pico-8" palette + the 16 color secret "Pico-8" palette
---
`loadPaletteGrayscale(): Palette`
Returns at 256 level grayscale palette
---
`setPalette(palette: Palette)`
Sets the current palette
---
`pal(a,b: int)`
Maps color `a` to color `b` for subsequent drawing operations
---
`pal()`
Resets palette mapping
---
`palt(color: int, transparent: bool)`
Makes `color` transparent or not for subsequent sprite drawing operations
By default color 0 is transparent.
---
`palt()`
Resets transparent colors such that only color 0 is transparent.
---
### Dithering
`ditherPattern(pattern: uint16 = 0b1111_1111_1111_1111)`
Sets the current dither pattern for subsequent draw calls, default pattern is no dithering.
Each bit specifies a pixel in the 4x4 dithering pattern.
```
0 1 2 3
4 5 6 7
8 9 A B
C D E F
```
### Camera
`setCamera(x,y: int = 0)`
Sets the camera offset for drawing
---
`getCamera(): (int,int)`
Gets the current camera offset
---
`clip(x,y,w,h: int)`
Sets the clipping area, only pixels within the clipping area will be written do
---
`clip()`
Resets the clipping area to the full canvas
---
`getClip(): (int,int,int,int)`
Gets the current clipping area
---
### Misc Graphics
`copy(sx,sy,dx,dy,w,h: int)`
Copy a region of the canvas from source `sx,sy` to dest `dx,dy` of size `w,h`


## Audio

To be completed

## Math

To be completed
