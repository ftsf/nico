
{.compile: "stb_image_impl.c".}
{.deadCodeElim: on.}

type
  Components* {.size: sizeof(cint).} = enum
    Default = 0 # req_comp only
    Grey = 1
    GreyAlpha = 2
    Rgb = 3
    RgbAlpha = 4

  IoCallbacks* {.final.} = object
    read*: proc(user: pointer, data: ptr cchar, size: cint): cint
    skip*: proc(user: pointer, n: cint)
    user*: proc(user: pointer): cint

proc load*(filename: cstring, x: ptr cint, y: ptr cint, comp: ptr Components, req_comp: Components): ptr cuchar {.importc: "stbi_load",cdecl.}
proc load_from_memory*(buffer: ptr cuchar, len: cint, x: ptr cint, y: ptr cint, comp: ptr Components, req_comp: Components): ptr cuchar {.importc: "stbi_load_from_memory".}
proc load_from_callbacks*(clbk: ptr IoCallbacks, user: pointer, x: ptr cint, y: ptr cint, comp: ptr Components, req_comp: Components): ptr cuchar {.importc: "stbi_load_from_callbacks".}
proc load_from_file*(f: ptr FileHandle, x: ptr cint, y: ptr cint, comp: ptr Components, req_comp: Components): ptr cuchar {.importc: "stbi_load_from_file".}

proc loadf*(filename: cstring, x: ptr cint, y: ptr cint, comp: ptr Components, req_comp: Components): ptr cfloat {.importc: "stbi_loadf".}
proc loadf_from_memory*(buffer: ptr cuchar, x: ptr cint, y: ptr cint, comp: ptr Components, req_comp: Components): ptr cfloat {.importc: "stbi_loadf_from_memory".}
proc loadf_from_callbacks*(clbk: ptr IoCallbacks, user: pointer, x: ptr cint, y: ptr cint, comp: ptr Components, req_comp: Components): ptr cfloat {.importc: "stbi_loadf_from_callbacks".}
proc loadf_from_file*(f: ptr FileHandle, x: ptr cint, y: ptr cint, comp: ptr Components, req_comp: Components): ptr cfloat {.importc: "stbi_loadf_from_file".}

proc hdr_to_ldr_gamma*(gamma: cfloat) {.importc: "stbi_hdr_to_ldr_gamma".}
proc hdr_to_ldr_scale*(scale: cfloat) {.importc: "stbi_hdr_to_ldr_scale".}

proc ldr_to_hdr_gamma*(gamma: cfloat) {.importc: "stbi_ldr_to_hdr_gamma".}
proc ldr_to_hdr_scale*(scale: cfloat) {.importc: "stbi_ldr_to_hdr_scale".}

proc is_hdr*(filename: cstring): cint {.importc: "stbi_is_hdr".}
proc is_hdr_from_memory*(buffer: ptr cuchar, len: cint): cint {.importc: "stbi_is_hdr_from_memory".}
proc is_hdr_from_callbacks*(clbk: ptr IoCallbacks, user: pointer): cint {.importc: "stbi_is_hdr_from_callbacks".}
proc is_hdr_from_file*(f: ptr FileHandle): cint {.importc: "stbi_is_hdr_from_file".}

proc failure_reason*(): cstring {.importc: "stbi_failure_reason".}
proc image_free*(retval_from_stbi_load: pointer) {.importc: "stbi_image_free".}

proc info*(filename: cstring, x: ptr cint, y: ptr cint, comp: ptr Components): cint {.importc: "stbi_info".}
proc info_from_memory*(buffer: ptr cuchar, len: cint, x: ptr cint, y: ptr cint, comp: ptr Components): cint {.importc: "stbi_info_from_memory".}
proc info_from_callbacks*(clbk: ptr IoCallbacks, user: pointer, x: ptr cint, y: ptr cint, comp: ptr Components): cint {.importc: "stbi_info_from_callbacks".}
proc info_from_file*(f: ptr FileHandle, x: ptr cint, y: ptr cint, comp: ptr Components): cint {.importc: "info_from_file".}

proc set_unpremultiply_on_load*(flag_true_if_should_unpremultiply: cint) {.importc: "stbi_set_unpremultiply_on_load".}
proc convert_iphone_png_to_rgb*(flag_true_if_should_convert: cint) {.importc: "stbi_convert_iphone_png_to_rgb".}
proc set_flip_vertically_on_load*(flag_true_if_should_flip: cint) {.importc: "stbi_set_flip_vertically_on_load".}

proc zlib_decode_malloc_guesssize*(buffer: ptr cchar, len: cint, initial_size: cint, outlen: ptr cint): ptr cchar {.importc: "stbi_zlib_decode_malloc_guesssize".}
proc zlib_decode_malloc_guesssize_headerflag*(buffer: ptr cchar, len: cint, initial_size: cint, outlen: ptr cint, parse_header: cint): ptr cchar {.importc: "stbi_zlib_decode_malloc_guesssize_headerflag".}
proc zlib_decode_malloc*(buffer: ptr cchar, len: cint, outlen: ptr cint): ptr cchar {.importc: "stbi_zlib_decode_malloc".}
proc zlib_decode_buffer*(obuffer: ptr cchar, olen: cint, ibuffer: ptr cchar, ilen: cint): cint {.importc: "stbi_zlib_decode_buffer".}
proc zlib_decode_noheader_malloc*(buffer: ptr cchar, len: cint, outlen: ptr cint): ptr cchar {.importc: "stbi_zlib_decode_noheader_malloc".}
proc zlib_decode_noheader_buffer*(obuffer: ptr cchar, olen: cint, ibuffer: ptr cchar, ilen: cint): cint {.importc: "stbi_zlib_decode_noheader_buffer".}
