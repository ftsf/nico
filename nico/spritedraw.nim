type SpriteDraw* = object
  spriteSheet*,spriteIndex*,x*,y*,w*,h*: int
  flipX*,flipY*: bool

proc initSpriteDraw*(spriteSheet, spriteIndex, x, y  : int, w = 1 ,h = 1, flipX = false, flipY = false ): SpriteDraw=
  SpriteDraw(spriteSheet : spriteSheet,
    spriteIndex : spriteIndex,
    x : x,
    y : y,
    w : w,
    h : h,
    flipX  : flipX,
    flipY : flipY)