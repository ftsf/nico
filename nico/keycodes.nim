type
  Scancode* {.size: sizeof(cint).} = enum ##  \
    ##  The SDL keyboard scancode representation.
    ##
    ##  Values of this type are used to represent keyboard keys, among other
    ##  places in the ``key.keysym.scancode`` field of the Event structure.
    ##
    ##  The values in this enumeration are based on the USB usage page standard:
    ##  http://www.usb.org/developers/hidpage/Hut1_12v2.pdf
    SCANCODE_UNKNOWN = 0,

    # Usage page 0x07
    #
    # These values are from usage page 0x07 (USB keyboard page).

    SCANCODE_A = 4,  SCANCODE_B = 5,  SCANCODE_C = 6,  SCANCODE_D = 7,
    SCANCODE_E = 8,  SCANCODE_F = 9,  SCANCODE_G = 10, SCANCODE_H = 11,
    SCANCODE_I = 12, SCANCODE_J = 13, SCANCODE_K = 14, SCANCODE_L = 15,
    SCANCODE_M = 16, SCANCODE_N = 17, SCANCODE_O = 18, SCANCODE_P = 19,
    SCANCODE_Q = 20, SCANCODE_R = 21, SCANCODE_S = 22, SCANCODE_T = 23,
    SCANCODE_U = 24, SCANCODE_V = 25, SCANCODE_W = 26, SCANCODE_X = 27,
    SCANCODE_Y = 28, SCANCODE_Z = 29,
    SCANCODE_1 = 30, SCANCODE_2 = 31, SCANCODE_3 = 32, SCANCODE_4 = 33,
    SCANCODE_5 = 34, SCANCODE_6 = 35, SCANCODE_7 = 36, SCANCODE_8 = 37,
    SCANCODE_9 = 38, SCANCODE_0 = 39,
    SCANCODE_RETURN = 40, SCANCODE_ESCAPE = 41, SCANCODE_BACKSPACE = 42,
    SCANCODE_TAB = 43,    SCANCODE_SPACE = 44,
    SCANCODE_MINUS = 45,  SCANCODE_EQUALS = 46,
    SCANCODE_LEFTBRACKET = 47, SCANCODE_RIGHTBRACKET = 48,
    SCANCODE_BACKSLASH = 49, ##  \
      ##  Located at the lower left of the `return` key on ISO keyboards and
      ##  at the right end of the QWERTY row on ANSI keyboards.
      ##  Produces `REVERSE SOLIDUS` (backslash) and `VERTICAL LINE` in a US
      ##  layout, `REVERSE SOLIDUS` and `VERTICAL LINE` in a UK Mac layout,
      ##  `NUMBER SIGN` and `TILDE` in a UK Windows layout, `DOLLAR SIGN` and
      ##  `POUND SIGN` in a Swiss German layout, `NUMBER SIGN` and
      ##  `APOSTROPHE` in a German layout, `GRAVE ACCENT` and `POUND SIGN`
      ##  in a French Mac layout, and `ASTERISK` and `MICRO SIGN` in a
      ##  French Windows layout.
    SCANCODE_NONUSHASH = 50, ##  \
      ##  ISO USB keyboards actually use this code instead of `49` for the
      ##  same key, but all OSes I've seen treat the two codes identically.
      ##  So, as an implementor, unless your keyboard generates both of those
      ##  codes and your OS treats them differently, you should generate
      ##  `SDL_SCANCODE_BACKSLASH` instead of this code. As a user, you
      ##  should not rely on this code because SDL will never generate it
      ##  with most (all?) keyboards.
    SCANCODE_SEMICOLON = 51, SCANCODE_APOSTROPHE = 52,
    SCANCODE_GRAVE = 53, ##  \
      ##  Located in the top left corner (on both ANSI and ISO keyboards).
      ##  Produces `GRAVE ACCENT` and `TILDE` in a US Windows layout and in US
      ##  and UK Mac layouts on ANSI keyboards, `GRAVE ACCENT` and `NOT SIGN`
      ##  in a UK Windows layout, `SECTION SIGN` and `PLUS-MINUS SIGN` in US
      ##  and UK Mac layouts on ISO keyboards, `SECTION SIGN` and `DEGREE SIGN`
      ##  in a Swiss German layout (Mac: only on ISO keyboards),
      ##  `CIRCUMFLEX ACCENT` and `DEGREE SIGN` in a German layout (Mac: only
      ##  on ISO keyboards), `SUPERSCRIPT TWO` and `TILDE` in a French Windows
      ##  layout, `COMMERCIAL AT` and `NUMBER SIGN` in a French Mac layout on
      ##  ISO keyboards, and `LESS-THAN SIGN` and `GREATER-THAN SIGN` in a
      ##  Swiss German, German, or French Mac layout on ANSI keyboards.
    SCANCODE_COMMA = 54, SCANCODE_PERIOD = 55, SCANCODE_SLASH = 56,
    SCANCODE_CAPSLOCK = 57,
    SCANCODE_F1 = 58,  SCANCODE_F2 = 59,  SCANCODE_F3 = 60, SCANCODE_F4 = 61,
    SCANCODE_F5 = 62,  SCANCODE_F6 = 63,  SCANCODE_F7 = 64, SCANCODE_F8 = 65,
    SCANCODE_F9 = 66,  SCANCODE_F10 = 67, SCANCODE_F11 = 68, SCANCODE_F12 = 69,
    SCANCODE_PRINTSCREEN = 70, SCANCODE_SCROLLLOCK = 71, SCANCODE_PAUSE = 72,
    SCANCODE_INSERT = 73, ##  \
      ##  `insert` on PC, `help` on some Mac keyboards
      ##  (but does send code `73`, not `117`)
    SCANCODE_HOME = 74, SCANCODE_PAGEUP = 75,   SCANCODE_DELETE = 76,
    SCANCODE_END = 77,  SCANCODE_PAGEDOWN = 78, SCANCODE_RIGHT = 79,
    SCANCODE_LEFT = 80, SCANCODE_DOWN = 81,     SCANCODE_UP = 82,
    SCANCODE_NUMLOCKCLEAR = 83, ##  \
      ##  `num lock` on PC, clear on Mac keyboards
    SCANCODE_KP_DIVIDE = 84, SCANCODE_KP_MULTIPLY = 85,
    SCANCODE_KP_MINUS = 86, SCANCODE_KP_PLUS = 87, SCANCODE_KP_ENTER = 88,
    SCANCODE_KP_1 = 89, SCANCODE_KP_2 = 90, SCANCODE_KP_3 = 91,
    SCANCODE_KP_4 = 92, SCANCODE_KP_5 = 93, SCANCODE_KP_6 = 94,
    SCANCODE_KP_7 = 95, SCANCODE_KP_8 = 96, SCANCODE_KP_9 = 97,
    SCANCODE_KP_0 = 98, SCANCODE_KP_PERIOD = 99,
    SCANCODE_NONUSBACKSLASH = 100, ##  \
      ##  This is the additional key that ISO keyboards have over ANSI ones,
      ##  located between `left shift` and `Y`.
      ##  Produces `GRAVE ACCENT` and `TILDE` in a US or UK Mac layout,
      ##  `REVERSE SOLIDUS` (backslash) and `VERTICAL LINE` in a US or UK
      ##  Windows layout, and `LESS-THAN SIGN` and `GREATER-THAN SIGN` in a
      ##  Swiss German, German, or French layout.
    SCANCODE_APPLICATION = 101, ##  `windows contextual menu`, `compose`
    SCANCODE_POWER = 102, ##  \
      ##  The USB document says this is a status flag,
      ##  not a physical key - but some Mac keyboards do have a power key.
    SCANCODE_KP_EQUALS = 103,
    SCANCODE_F13 = 104, SCANCODE_F14 = 105, SCANCODE_F15 = 106,
    SCANCODE_F16 = 107, SCANCODE_F17 = 108, SCANCODE_F18 = 109,
    SCANCODE_F19 = 110, SCANCODE_F20 = 111, SCANCODE_F21 = 112,
    SCANCODE_F22 = 113, SCANCODE_F23 = 114, SCANCODE_F24 = 115,
    SCANCODE_EXECUTE = 116,  SCANCODE_HELP = 117, SCANCODE_MENU = 118,
    SCANCODE_SELECT = 119,   SCANCODE_STOP = 120, SCANCODE_AGAIN = 121, ## redo
    SCANCODE_UNDO = 122,     SCANCODE_CUT = 123,  SCANCODE_COPY = 124,
    SCANCODE_PASTE = 125,    SCANCODE_FIND = 126, SCANCODE_MUTE = 127,
    SCANCODE_VOLUMEUP = 128, SCANCODE_VOLUMEDOWN = 129,
    # not sure whether there's a reason to enable these
    # SCANCODE_LOCKINGCAPSLOCK = 130,
    # SCANCODE_LOCKINGNUMLOCK = 131,
    # SCANCODE_LOCKINGSCROLLLOCK = 132,
    SCANCODE_KP_COMMA = 133, SCANCODE_KP_EQUALSAS400 = 134,
    SCANCODE_INTERNATIONAL1 = 135, ##  \
      ##  used on Asian keyboards, see footnotes in USB doc
    SCANCODE_INTERNATIONAL2 = 136, SCANCODE_INTERNATIONAL3 = 137, ## Yen
    SCANCODE_INTERNATIONAL4 = 138, SCANCODE_INTERNATIONAL5 = 139,
    SCANCODE_INTERNATIONAL6 = 140, SCANCODE_INTERNATIONAL7 = 141,
    SCANCODE_INTERNATIONAL8 = 142, SCANCODE_INTERNATIONAL9 = 143,
    SCANCODE_LANG1 = 144, ##  Hangul/English toggle
    SCANCODE_LANG2 = 145, ##  Hanja conversion
    SCANCODE_LANG3 = 146, ##  Katakana
    SCANCODE_LANG4 = 147, ##  Hiragana
    SCANCODE_LANG5 = 148, ##  Zenkaku/Hankaku
    SCANCODE_LANG6 = 149, ##  reserved
    SCANCODE_LANG7 = 150, ##  reserved
    SCANCODE_LANG8 = 151, ##  reserved
    SCANCODE_LANG9 = 152, ##  reserved
    SCANCODE_ALTERASE = 153, ## Erase-Eaze
    SCANCODE_SYSREQ = 154, SCANCODE_CANCEL = 155,  SCANCODE_CLEAR = 156,
    SCANCODE_PRIOR = 157,  SCANCODE_RETURN2 = 158, SCANCODE_SEPARATOR = 159,
    SCANCODE_OUT = 160,    SCANCODE_OPER = 161,    SCANCODE_CLEARAGAIN = 162,
    SCANCODE_CRSEL = 163,  SCANCODE_EXSEL = 164,
    SCANCODE_KP_00 = 176,  SCANCODE_KP_000 = 177,
    SCANCODE_THOUSANDSSEPARATOR = 178,  SCANCODE_DECIMALSEPARATOR = 179,
    SCANCODE_CURRENCYUNIT = 180,        SCANCODE_CURRENCYSUBUNIT = 181,
    SCANCODE_KP_LEFTPAREN = 182,        SCANCODE_KP_RIGHTPAREN = 183,
    SCANCODE_KP_LEFTBRACE = 184,        SCANCODE_KP_RIGHTBRACE = 185,
    SCANCODE_KP_TAB = 186,              SCANCODE_KP_BACKSPACE = 187,
    SCANCODE_KP_A = 188, SCANCODE_KP_B = 189, SCANCODE_KP_C = 190,
    SCANCODE_KP_D = 191, SCANCODE_KP_E = 192, SCANCODE_KP_F = 193,
    SCANCODE_KP_XOR = 194,            SCANCODE_KP_POWER = 195,
    SCANCODE_KP_PERCENT = 196,        SCANCODE_KP_LESS = 197,
    SCANCODE_KP_GREATER = 198,        SCANCODE_KP_AMPERSAND = 199,
    SCANCODE_KP_DBLAMPERSAND = 200,   SCANCODE_KP_VERTICALBAR = 201,
    SCANCODE_KP_DBLVERTICALBAR = 202, SCANCODE_KP_COLON = 203,
    SCANCODE_KP_HASH = 204,           SCANCODE_KP_SPACE = 205,
    SCANCODE_KP_AT = 206,             SCANCODE_KP_EXCLAM = 207,
    SCANCODE_KP_MEMSTORE = 208,       SCANCODE_KP_MEMRECALL = 209,
    SCANCODE_KP_MEMCLEAR = 210,       SCANCODE_KP_MEMADD = 211,
    SCANCODE_KP_MEMSUBTRACT = 212,    SCANCODE_KP_MEMMULTIPLY = 213,
    SCANCODE_KP_MEMDIVIDE = 214,      SCANCODE_KP_PLUSMINUS = 215,
    SCANCODE_KP_CLEAR = 216,          SCANCODE_KP_CLEARENTRY = 217,
    SCANCODE_KP_BINARY = 218,         SCANCODE_KP_OCTAL = 219,
    SCANCODE_KP_DECIMAL = 220,        SCANCODE_KP_HEXADECIMAL = 221,
    SCANCODE_LCTRL = 224,
    SCANCODE_LSHIFT = 225,
    SCANCODE_LALT = 226, ##  `alt`, `option`
    SCANCODE_LGUI = 227, ##  `windows`, `command` (apple), `meta`
    SCANCODE_RCTRL = 228,
    SCANCODE_RSHIFT = 229,
    SCANCODE_RALT = 230, ##  `alt gr`, `option`
    SCANCODE_RGUI = 231, ##  `windows`, `command` (apple), `meta`
    SCANCODE_MODE = 257, ##  \
      ##  I'm not sure if this is really not covered by any of the above,
      ##  but since there's a special `KMOD_MODE` for it I'm adding it here

    # Usage page 0x0C
    #
    # These values are mapped from usage page 0x0C (USB consumer page).

    SCANCODE_AUDIONEXT = 258,   SCANCODE_AUDIOPREV = 259,
    SCANCODE_AUDIOSTOP = 260,   SCANCODE_AUDIOPLAY = 261,
    SCANCODE_AUDIOMUTE = 262,   SCANCODE_MEDIASELECT = 263,
    SCANCODE_WWW = 264,         SCANCODE_MAIL = 265,
    SCANCODE_CALCULATOR = 266,  SCANCODE_COMPUTER = 267,
    SCANCODE_AC_SEARCH = 268,   SCANCODE_AC_HOME = 269,
    SCANCODE_AC_BACK = 270,     SCANCODE_AC_FORWARD = 271,
    SCANCODE_AC_STOP = 272,     SCANCODE_AC_REFRESH = 273,
    SCANCODE_AC_BOOKMARKS = 274,

    # Walther keys
    #
    # These are values that Christian Walther added (for mac keyboard?).

    SCANCODE_BRIGHTNESSDOWN = 275, SCANCODE_BRIGHTNESSUP = 276,
    SCANCODE_DISPLAYSWITCH = 277, ##  \
      ##  display mirroring/dual display switch, video mode switch 
    SCANCODE_KBDILLUMTOGGLE = 278,
    SCANCODE_KBDILLUMDOWN = 279,  SCANCODE_KBDILLUMUP = 280,
    SCANCODE_EJECT = 281,         SCANCODE_SLEEP = 282,
    SCANCODE_APP1 = 283,          SCANCODE_APP2 = 284,

    # Usage page 0x0C (additional media keys)
    #
    # These values are mapped from usage page 0x0C (USB consumer page).

    SCANCODE_AUDIOREWIND = 285,
    SCANCODE_AUDIOFASTFORWARD = 286,

    # Add any other keys here.

    NUM_SCANCODES = 512 ##  \
      ##  not a key, just marks the number of scancodes for array bounds


const
  K_SCANCODE_MASK* = (1 shl 30)

template scancodeToKeycode*(x: untyped): cint =
  (cint(x) or K_SCANCODE_MASK)

type
  Keycode* {.size: sizeof(cint).} = enum ##  \
    ##  The SDL virtual key representation.
    ##
    ##  Values of this type are used to represent keyboard keys using the
    ##  current layout of the keyboard.  These values include Unicode values
    ##  representing  the unmodified character that would be generated by
    ##  pressing the key, or an K_* constant for those keys that do not
    ##  generate characters.
    ##
    ##  A special exception is the number keys at the top of the keyboard which
    ##  always map to K_0...K_9, regardless of layout.
    K_UNKNOWN = 0
    K_BACKSPACE = ord '\x08'
    K_TAB = ord '\x09'
    K_RETURN = ord '\x0D'
    K_ESCAPE = ord '\x1B'
    K_SPACE = ord ' '
    K_EXCLAIM = ord '!'
    K_QUOTEDBL = ord '\"'
    K_HASH = ord '#'
    K_DOLLAR = ord '$'
    K_PERCENT = ord '%'
    K_AMPERSAND = ord '&'
    K_QUOTE = ord '\''
    K_LEFTPAREN = ord '('
    K_RIGHTPAREN = ord ')'
    K_ASTERISK = ord '*'
    K_PLUS = ord '+'
    K_COMMA = ord ','
    K_MINUS = ord '-'
    K_PERIOD = ord '.'
    K_SLASH = ord '/'
    K_0 = ord '0'
    K_1 = ord '1'
    K_2 = ord '2'
    K_3 = ord '3'
    K_4 = ord '4'
    K_5 = ord '5'
    K_6 = ord '6'
    K_7 = ord '7'
    K_8 = ord '8'
    K_9 = ord '9'
    K_COLON = ord ':'
    K_SEMICOLON = ord ';'
    K_LESS = ord '<'
    K_EQUALS = ord '='
    K_GREATER = ord '>'
    K_QUESTION = ord '?'
    K_AT = ord '@'
    #
    #       Skip uppercase letters
    #
    K_LEFTBRACKET = ord '['
    K_BACKSLASH = ord '\\'
    K_RIGHTBRACKET = ord ']'
    K_CARET = ord '^'
    K_UNDERSCORE = ord '_'
    K_BACKQUOTE = ord '`'
    K_a = ord 'a'
    K_b = ord 'b'
    K_c = ord 'c'
    K_d = ord 'd'
    K_e = ord 'e'
    K_f = ord 'f'
    K_g = ord 'g'
    K_h = ord 'h'
    K_i = ord 'i'
    K_j = ord 'j'
    K_k = ord 'k'
    K_l = ord 'l'
    K_m = ord 'm'
    K_n = ord 'n'
    K_o = ord 'o'
    K_p = ord 'p'
    K_q = ord 'q'
    K_r = ord 'r'
    K_s = ord 's'
    K_t = ord 't'
    K_u = ord 'u'
    K_v = ord 'v'
    K_w = ord 'w'
    K_x = ord 'x'
    K_y = ord 'y'
    K_z = ord 'z'
    K_DELETE = 127
    K_CAPSLOCK = scancodeToKeycode(SCANCODE_CAPSLOCK)
    K_F1 = scancodeToKeycode(SCANCODE_F1)
    K_F2 = scancodeToKeycode(SCANCODE_F2)
    K_F3 = scancodeToKeycode(SCANCODE_F3)
    K_F4 = scancodeToKeycode(SCANCODE_F4)
    K_F5 = scancodeToKeycode(SCANCODE_F5)
    K_F6 = scancodeToKeycode(SCANCODE_F6)
    K_F7 = scancodeToKeycode(SCANCODE_F7)
    K_F8 = scancodeToKeycode(SCANCODE_F8)
    K_F9 = scancodeToKeycode(SCANCODE_F9)
    K_F10 = scancodeToKeycode(SCANCODE_F10)
    K_F11 = scancodeToKeycode(SCANCODE_F11)
    K_F12 = scancodeToKeycode(SCANCODE_F12)
    K_PRINTSCREEN = scancodeToKeycode(SCANCODE_PRINTSCREEN)
    K_SCROLLLOCK = scancodeToKeycode(SCANCODE_SCROLLLOCK)
    K_PAUSE = scancodeToKeycode(SCANCODE_PAUSE)
    K_INSERT = scancodeToKeycode(SCANCODE_INSERT)
    K_HOME = scancodeToKeycode(SCANCODE_HOME)
    K_PAGEUP = scancodeToKeycode(SCANCODE_PAGEUP)
    #K_DELETE = scancodeToKeycode(SCANCODE_DELETE)
    K_END = scancodeToKeycode(SCANCODE_END)
    K_PAGEDOWN = scancodeToKeycode(SCANCODE_PAGEDOWN)
    K_RIGHT = scancodeToKeycode(SCANCODE_RIGHT)
    K_LEFT = scancodeToKeycode(SCANCODE_LEFT)
    K_DOWN = scancodeToKeycode(SCANCODE_DOWN)
    K_UP = scancodeToKeycode(SCANCODE_UP)
    K_NUMLOCKCLEAR = scancodeToKeycode(SCANCODE_NUMLOCKCLEAR)
    K_KP_DIVIDE = scancodeToKeycode(SCANCODE_KP_DIVIDE)
    K_KP_MULTIPLY = scancodeToKeycode(SCANCODE_KP_MULTIPLY)
    K_KP_MINUS = scancodeToKeycode(SCANCODE_KP_MINUS)
    K_KP_PLUS = scancodeToKeycode(SCANCODE_KP_PLUS)
    K_KP_ENTER = scancodeToKeycode(SCANCODE_KP_ENTER)
    K_KP_1 = scancodeToKeycode(SCANCODE_KP_1)
    K_KP_2 = scancodeToKeycode(SCANCODE_KP_2)
    K_KP_3 = scancodeToKeycode(SCANCODE_KP_3)
    K_KP_4 = scancodeToKeycode(SCANCODE_KP_4)
    K_KP_5 = scancodeToKeycode(SCANCODE_KP_5)
    K_KP_6 = scancodeToKeycode(SCANCODE_KP_6)
    K_KP_7 = scancodeToKeycode(SCANCODE_KP_7)
    K_KP_8 = scancodeToKeycode(SCANCODE_KP_8)
    K_KP_9 = scancodeToKeycode(SCANCODE_KP_9)
    K_KP_0 = scancodeToKeycode(SCANCODE_KP_0)
    K_KP_PERIOD = scancodeToKeycode(SCANCODE_KP_PERIOD)
    K_APPLICATION = scancodeToKeycode(SCANCODE_APPLICATION)
    K_POWER = scancodeToKeycode(SCANCODE_POWER)
    K_KP_EQUALS = scancodeToKeycode(SCANCODE_KP_EQUALS)
    K_F13 = scancodeToKeycode(SCANCODE_F13)
    K_F14 = scancodeToKeycode(SCANCODE_F14)
    K_F15 = scancodeToKeycode(SCANCODE_F15)
    K_F16 = scancodeToKeycode(SCANCODE_F16)
    K_F17 = scancodeToKeycode(SCANCODE_F17)
    K_F18 = scancodeToKeycode(SCANCODE_F18)
    K_F19 = scancodeToKeycode(SCANCODE_F19)
    K_F20 = scancodeToKeycode(SCANCODE_F20)
    K_F21 = scancodeToKeycode(SCANCODE_F21)
    K_F22 = scancodeToKeycode(SCANCODE_F22)
    K_F23 = scancodeToKeycode(SCANCODE_F23)
    K_F24 = scancodeToKeycode(SCANCODE_F24)
    K_EXECUTE = scancodeToKeycode(SCANCODE_EXECUTE)
    K_HELP = scancodeToKeycode(SCANCODE_HELP)
    K_MENU = scancodeToKeycode(SCANCODE_MENU)
    K_SELECT = scancodeToKeycode(SCANCODE_SELECT)
    K_STOP = scancodeToKeycode(SCANCODE_STOP)
    K_AGAIN = scancodeToKeycode(SCANCODE_AGAIN)
    K_UNDO = scancodeToKeycode(SCANCODE_UNDO)
    K_CUT = scancodeToKeycode(SCANCODE_CUT)
    K_COPY = scancodeToKeycode(SCANCODE_COPY)
    K_PASTE = scancodeToKeycode(SCANCODE_PASTE)
    K_FIND = scancodeToKeycode(SCANCODE_FIND)
    K_MUTE = scancodeToKeycode(SCANCODE_MUTE)
    K_VOLUMEUP = scancodeToKeycode(SCANCODE_VOLUMEUP)
    K_VOLUMEDOWN = scancodeToKeycode(SCANCODE_VOLUMEDOWN)
    K_KP_COMMA = scancodeToKeycode(SCANCODE_KP_COMMA)
    K_KP_EQUALSAS400 = scancodeToKeycode(SCANCODE_KP_EQUALSAS400)
    K_ALTERASE = scancodeToKeycode(SCANCODE_ALTERASE)
    K_SYSREQ = scancodeToKeycode(SCANCODE_SYSREQ)
    K_CANCEL = scancodeToKeycode(SCANCODE_CANCEL)
    K_CLEAR = scancodeToKeycode(SCANCODE_CLEAR)
    K_PRIOR = scancodeToKeycode(SCANCODE_PRIOR)
    K_RETURN2 = scancodeToKeycode(SCANCODE_RETURN2)
    K_SEPARATOR = scancodeToKeycode(SCANCODE_SEPARATOR)
    K_OUT = scancodeToKeycode(SCANCODE_OUT)
    K_OPER = scancodeToKeycode(SCANCODE_OPER)
    K_CLEARAGAIN = scancodeToKeycode(SCANCODE_CLEARAGAIN)
    K_CRSEL = scancodeToKeycode(SCANCODE_CRSEL)
    K_EXSEL = scancodeToKeycode(SCANCODE_EXSEL)
    K_KP_00 = scancodeToKeycode(SCANCODE_KP_00)
    K_KP_000 = scancodeToKeycode(SCANCODE_KP_000)
    K_THOUSANDSSEPARATOR = scancodeToKeycode(SCANCODE_THOUSANDSSEPARATOR)
    K_DECIMALSEPARATOR = scancodeToKeycode(SCANCODE_DECIMALSEPARATOR)
    K_CURRENCYUNIT = scancodeToKeycode(SCANCODE_CURRENCYUNIT)
    K_CURRENCYSUBUNIT = scancodeToKeycode(SCANCODE_CURRENCYSUBUNIT)
    K_KP_LEFTPAREN = scancodeToKeycode(SCANCODE_KP_LEFTPAREN)
    K_KP_RIGHTPAREN = scancodeToKeycode(SCANCODE_KP_RIGHTPAREN)
    K_KP_LEFTBRACE = scancodeToKeycode(SCANCODE_KP_LEFTBRACE)
    K_KP_RIGHTBRACE = scancodeToKeycode(SCANCODE_KP_RIGHTBRACE)
    K_KP_TAB = scancodeToKeycode(SCANCODE_KP_TAB)
    K_KP_BACKSPACE = scancodeToKeycode(SCANCODE_KP_BACKSPACE)
    K_KP_A = scancodeToKeycode(SCANCODE_KP_A)
    K_KP_B = scancodeToKeycode(SCANCODE_KP_B)
    K_KP_C = scancodeToKeycode(SCANCODE_KP_C)
    K_KP_D = scancodeToKeycode(SCANCODE_KP_D)
    K_KP_E = scancodeToKeycode(SCANCODE_KP_E)
    K_KP_F = scancodeToKeycode(SCANCODE_KP_F)
    K_KP_XOR = scancodeToKeycode(SCANCODE_KP_XOR)
    K_KP_POWER = scancodeToKeycode(SCANCODE_KP_POWER)
    K_KP_PERCENT = scancodeToKeycode(SCANCODE_KP_PERCENT)
    K_KP_LESS = scancodeToKeycode(SCANCODE_KP_LESS)
    K_KP_GREATER = scancodeToKeycode(SCANCODE_KP_GREATER)
    K_KP_AMPERSAND = scancodeToKeycode(SCANCODE_KP_AMPERSAND)
    K_KP_DBLAMPERSAND = scancodeToKeycode(SCANCODE_KP_DBLAMPERSAND)
    K_KP_VERTICALBAR = scancodeToKeycode(SCANCODE_KP_VERTICALBAR)
    K_KP_DBLVERTICALBAR = scancodeToKeycode(SCANCODE_KP_DBLVERTICALBAR)
    K_KP_COLON = scancodeToKeycode(SCANCODE_KP_COLON)
    K_KP_HASH = scancodeToKeycode(SCANCODE_KP_HASH)
    K_KP_SPACE = scancodeToKeycode(SCANCODE_KP_SPACE)
    K_KP_AT = scancodeToKeycode(SCANCODE_KP_AT)
    K_KP_EXCLAM = scancodeToKeycode(SCANCODE_KP_EXCLAM)
    K_KP_MEMSTORE = scancodeToKeycode(SCANCODE_KP_MEMSTORE)
    K_KP_MEMRECALL = scancodeToKeycode(SCANCODE_KP_MEMRECALL)
    K_KP_MEMCLEAR = scancodeToKeycode(SCANCODE_KP_MEMCLEAR)
    K_KP_MEMADD = scancodeToKeycode(SCANCODE_KP_MEMADD)
    K_KP_MEMSUBTRACT = scancodeToKeycode(SCANCODE_KP_MEMSUBTRACT)
    K_KP_MEMMULTIPLY = scancodeToKeycode(SCANCODE_KP_MEMMULTIPLY)
    K_KP_MEMDIVIDE = scancodeToKeycode(SCANCODE_KP_MEMDIVIDE)
    K_KP_PLUSMINUS = scancodeToKeycode(SCANCODE_KP_PLUSMINUS)
    K_KP_CLEAR = scancodeToKeycode(SCANCODE_KP_CLEAR)
    K_KP_CLEARENTRY = scancodeToKeycode(SCANCODE_KP_CLEARENTRY)
    K_KP_BINARY = scancodeToKeycode(SCANCODE_KP_BINARY)
    K_KP_OCTAL = scancodeToKeycode(SCANCODE_KP_OCTAL)
    K_KP_DECIMAL = scancodeToKeycode(SCANCODE_KP_DECIMAL)
    K_KP_HEXADECIMAL = scancodeToKeycode(SCANCODE_KP_HEXADECIMAL)
    K_LCTRL = scancodeToKeycode(SCANCODE_LCTRL)
    K_LSHIFT = scancodeToKeycode(SCANCODE_LSHIFT)
    K_LALT = scancodeToKeycode(SCANCODE_LALT)
    K_LGUI = scancodeToKeycode(SCANCODE_LGUI)
    K_RCTRL = scancodeToKeycode(SCANCODE_RCTRL)
    K_RSHIFT = scancodeToKeycode(SCANCODE_RSHIFT)
    K_RALT = scancodeToKeycode(SCANCODE_RALT)
    K_RGUI = scancodeToKeycode(SCANCODE_RGUI)
    K_MODE = scancodeToKeycode(SCANCODE_MODE)
    K_AUDIONEXT = scancodeToKeycode(SCANCODE_AUDIONEXT)
    K_AUDIOPREV = scancodeToKeycode(SCANCODE_AUDIOPREV)
    K_AUDIOSTOP = scancodeToKeycode(SCANCODE_AUDIOSTOP)
    K_AUDIOPLAY = scancodeToKeycode(SCANCODE_AUDIOPLAY)
    K_AUDIOMUTE = scancodeToKeycode(SCANCODE_AUDIOMUTE)
    K_MEDIASELECT = scancodeToKeycode(SCANCODE_MEDIASELECT)
    K_WWW = scancodeToKeycode(SCANCODE_WWW)
    K_MAIL = scancodeToKeycode(SCANCODE_MAIL)
    K_CALCULATOR = scancodeToKeycode(SCANCODE_CALCULATOR)
    K_COMPUTER = scancodeToKeycode(SCANCODE_COMPUTER)
    K_AC_SEARCH = scancodeToKeycode(SCANCODE_AC_SEARCH)
    K_AC_HOME = scancodeToKeycode(SCANCODE_AC_HOME)
    K_AC_BACK = scancodeToKeycode(SCANCODE_AC_BACK)
    K_AC_FORWARD = scancodeToKeycode(SCANCODE_AC_FORWARD)
    K_AC_STOP = scancodeToKeycode(SCANCODE_AC_STOP)
    K_AC_REFRESH = scancodeToKeycode(SCANCODE_AC_REFRESH)
    K_AC_BOOKMARKS = scancodeToKeycode(SCANCODE_AC_BOOKMARKS)
    K_BRIGHTNESSDOWN = scancodeToKeycode(SCANCODE_BRIGHTNESSDOWN)
    K_BRIGHTNESSUP = scancodeToKeycode(SCANCODE_BRIGHTNESSUP)
    K_DISPLAYSWITCH = scancodeToKeycode(SCANCODE_DISPLAYSWITCH)
    K_KBDILLUMTOGGLE = scancodeToKeycode(SCANCODE_KBDILLUMTOGGLE)
    K_KBDILLUMDOWN = scancodeToKeycode(SCANCODE_KBDILLUMDOWN)
    K_KBDILLUMUP = scancodeToKeycode(SCANCODE_KBDILLUMUP)
    K_EJECT = scancodeToKeycode(SCANCODE_EJECT)
    K_SLEEP = scancodeToKeycode(SCANCODE_SLEEP)
    K_APP1 = scancodeToKeycode(SCANCODE_APP1)
    K_APP2 = scancodeToKeycode(SCANCODE_APP2)
    K_AUDIOREWIND = scancodeToKeycode(SCANCODE_AUDIOREWIND)
    K_AUDIOFASTFORWARD = scancodeToKeycode(SCANCODE_AUDIOFASTFORWARD)

type
  Keymod* {.size: sizeof(cint).} = enum ##  \
    ##  Enumeration of valid key mods (possibly OR'd together).
    KMOD_NONE = 0x00000000,
    KMOD_LSHIFT = 0x00000001,
    KMOD_RSHIFT = 0x00000002,
    KMOD_SHIFT = KMOD_LSHIFT.cint or KMOD_RSHIFT.cint,
    KMOD_LCTRL = 0x00000040,
    KMOD_RCTRL = 0x00000080,
    KMOD_CTRL  = KMOD_LCTRL.cint or KMOD_RCTRL.cint,
    KMOD_LALT = 0x00000100,
    KMOD_RALT = 0x00000200,
    KMOD_ALT   = KMOD_LALT.cint or KMOD_RALT.cint,
    KMOD_LGUI = 0x00000400,
    KMOD_RGUI = 0x00000800,
    KMOD_GUI   = KMOD_LGUI.cint or KMOD_RGUI.cint,
    KMOD_NUM = 0x00001000,
    KMOD_CAPS = 0x00002000,
    KMOD_MODE = 0x00004000,
    KMOD_RESERVED = 0x00008000

template `or`*(a, b: Keymod): Keymod =
  a.cint or b.cint

template `and`*(a, b: Keymod): bool =
  (a.cint and b.cint) > 0
