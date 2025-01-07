package wgpu_app

import clay "shared:clay/bindings/odin/clay-odin"

Font :: struct {
  using info:   struct {
    face:   string,
    size:   int,
    bold:   bool,
    italic: bool,
  },
  using common: struct {
    line_height: int,
    base:        int,
    scale_w:     int,
    scale_h:     int,
    // num_pages:   int,
    packed:      bool,
  },
  // pages:        map[int]string,
  characters:   map[u8]Character,
}

Character :: struct {
  // id:        int,
  x:         int,
  y:         int,
  width:     int,
  height:    int,
  // page:      int,
  x_advance: int,
  x_offset:  int,
  y_offset:  int,
}

DEFAULT_FONT_ID :: 0

App_Font :: struct {
  img:        []u8 `fmt:"-"`,
  error_char: Character,
  font:       Font,
}

APP_FONTS := [?]App_Font {
  {
    img = #load("../pixel_fonts/fonts/minogram_6x10.png"),
    error_char = Character{x = 54, y = 60, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
    font = Font {
      face = "minogram_6x10",
      size = 10,
      bold = false,
      italic = false,
      line_height = 12,
      base = 10,
      scale_w = 78,
      scale_h = 70,
      packed = false,
      characters = map[u8]Character {
        'A' = {x = 0, y = 0, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'B' = {x = 6, y = 0, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'C' = {x = 12, y = 0, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'D' = {x = 18, y = 0, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'E' = {x = 24, y = 0, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'F' = {x = 30, y = 0, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'G' = {x = 36, y = 0, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'H' = {x = 42, y = 0, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'I' = {x = 48, y = 0, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'J' = {x = 54, y = 0, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'K' = {x = 60, y = 0, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'L' = {x = 66, y = 0, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'M' = {x = 72, y = 0, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'N' = {x = 0, y = 10, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'O' = {x = 6, y = 10, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'P' = {x = 12, y = 10, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'Q' = {x = 18, y = 10, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'R' = {x = 24, y = 10, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'S' = {x = 30, y = 10, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'T' = {x = 36, y = 10, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'U' = {x = 42, y = 10, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'V' = {x = 48, y = 10, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'W' = {x = 54, y = 10, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'X' = {x = 60, y = 10, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'Y' = {x = 66, y = 10, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'Z' = {x = 72, y = 10, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'a' = {x = 0, y = 20, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'b' = {x = 6, y = 20, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'c' = {x = 12, y = 20, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'd' = {x = 18, y = 20, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'e' = {x = 24, y = 20, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'f' = {x = 30, y = 20, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'g' = {x = 36, y = 20, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'h' = {x = 42, y = 20, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'i' = {x = 48, y = 20, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'j' = {x = 54, y = 20, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'k' = {x = 60, y = 20, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'l' = {x = 66, y = 20, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'm' = {x = 72, y = 20, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'n' = {x = 0, y = 30, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'o' = {x = 6, y = 30, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'p' = {x = 12, y = 30, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'q' = {x = 18, y = 30, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'r' = {x = 24, y = 30, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        's' = {x = 30, y = 30, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        't' = {x = 36, y = 30, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'u' = {x = 42, y = 30, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'v' = {x = 48, y = 30, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'w' = {x = 54, y = 30, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'x' = {x = 60, y = 30, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'y' = {x = 66, y = 30, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        'z' = {x = 72, y = 30, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        '0' = {x = 0, y = 40, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        '1' = {x = 6, y = 40, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        '2' = {x = 12, y = 40, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        '3' = {x = 18, y = 40, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        '4' = {x = 24, y = 40, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        '5' = {x = 30, y = 40, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        '6' = {x = 36, y = 40, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        '7' = {x = 42, y = 40, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        '8' = {x = 48, y = 40, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        '9' = {x = 54, y = 40, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        '+' = {x = 60, y = 40, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        '-' = {x = 66, y = 40, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        '=' = {x = 72, y = 40, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        '(' = {x = 0, y = 50, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        ')' = {x = 6, y = 50, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        '[' = {x = 12, y = 50, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        ']' = {x = 18, y = 50, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        '{' = {x = 24, y = 50, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        '}' = {x = 30, y = 50, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        '<' = {x = 36, y = 50, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        '>' = {x = 42, y = 50, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        '/' = {x = 48, y = 50, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        '*' = {x = 54, y = 50, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        ':' = {x = 60, y = 50, width = 6, height = 10, x_advance = 3, x_offset = 0, y_offset = 0},
        '#' = {x = 66, y = 50, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        '%' = {x = 72, y = 50, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        '!' = {x = 0, y = 60, width = 6, height = 10, x_advance = 3, x_offset = 0, y_offset = 0},
        '?' = {x = 6, y = 60, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        '.' = {x = 12, y = 60, width = 6, height = 10, x_advance = 4, x_offset = 0, y_offset = 0},
        ',' = {x = 18, y = 60, width = 6, height = 10, x_advance = 3, x_offset = 0, y_offset = 0},
        '\'' = {x = 24, y = 60, width = 6, height = 10, x_advance = 2, x_offset = 0, y_offset = 0},
        '"' = {x = 30, y = 60, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        '@' = {x = 36, y = 60, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        '&' = {x = 42, y = 60, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        '$' = {x = 48, y = 60, width = 6, height = 10, x_advance = 6, x_offset = 0, y_offset = 0},
        ' ' = {x = 54, y = 60, width = 6, height = 10, x_advance = 4, x_offset = 0, y_offset = 0},
      },
    },
  },
}

measure_text :: proc "c" (text: ^clay.String, config: ^clay.TextElementConfig) -> clay.Dimensions {
  context = state.ctx

  // TODO: incorporate config
  // TextElementConfig :: struct {
  //   textColor:     Color,
  //   fontId:        u16,
  //   fontSize:      u16,
  //   letterSpacing: u16,
  //   lineHeight:    u16,
  //   wrapMode:      TextWrapMode,
  // }

  font := APP_FONTS[config.fontId]

  width := 0
  height := 0

  for i in 0 ..< text.length {
    if text.chars[i] == 0 do break

    // TODO: incorporate advance, offset, etc...
    character, ok := font.font.characters[text.chars[i]]
    if !ok do character = font.error_char

    width += character.width
    height = max(height, character.height)
  }

  return {f32(width), f32(height)}
}
