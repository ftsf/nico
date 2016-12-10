
{.compile: "stb_image_write_impl.c".}
{.deadCodeElim: on.}

from stb_image import Components
export Components

proc write_png*(filename: cstring, w: cint, h: cint, comp: Components, data: pointer, stride_in_bytes: cint): cint {.importc: "stbi_write_png",cdecl.}
proc write_bmp*(filename: cstring, w: cint, h: cint, comp: Components, data: pointer): cint {.importc: "stbi_write_bmp".}
proc write_tga*(filename: cstring, w: cint, h: cint, comp: Components, data: pointer): cint {.importc: "stbi_write_tga".}
proc write_hdr*(filename: cstring, w: cint, h: cint, comp: Components, data: pointer): cint {.importc: "stbi_write_hdr".}
