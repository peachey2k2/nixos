#slop

import fontforge
import sys

# Match Monaspace Krypton Regular 1.400 metrics. WezTerm lays out cells from
# the primary font, so fallback cell-filling Braille glyphs need to share its
# vertical metrics and monospace advance to avoid shifting/scaling.
EM = 2000
ASCENT = 1600
DESCENT = 400
ADVANCE = 1240

# Keep some horizontal breathing room: when this font is used as fallback,
# WezTerm scales it against Monaspace's cell and a full-width Braille outline
# bleeds into neighboring cells.
TARGET_X_MIN = 0
TARGET_X_MAX = ADVANCE - 0

# Braille needs to vertically overdraw the nominal em box a bit to avoid thin
# seams between rows. These values mirror Monaspace's own full-block glyph more
# closely than its plain ascent/descent box.
TARGET_Y_MIN = -500
TARGET_Y_MAX = 2100


def draw_rectangle(pen, x_min, y_min, x_max, y_max):
    pen.moveTo((x_min, y_max))
    pen.lineTo((x_max, y_max))
    pen.lineTo((x_max, y_min))
    pen.lineTo((x_min, y_min))
    pen.closePath()


def dot_bounds(dot: int):
    # Unicode Braille dot numbering:
    # 1 4
    # 2 5
    # 3 6
    # 7 8
    if dot < 6:
        row = dot % 3
        col = dot // 3
    else:
        row = 3
        col = dot - 6

    cell_width = TARGET_X_MAX - TARGET_X_MIN
    cell_height = TARGET_Y_MAX - TARGET_Y_MIN
    x0 = TARGET_X_MIN + col * cell_width / 2
    x1 = TARGET_X_MIN + (col + 1) * cell_width / 2
    y1 = TARGET_Y_MAX - row * cell_height / 4
    y0 = TARGET_Y_MAX - (row + 1) * cell_height / 4
    return x0, y0, x1, y1


def redraw_braille_glyph(font, codepoint: int) -> None:
    glyph = font.createChar(codepoint, f"uni{codepoint:04X}")
    glyph.clear()

    pattern = codepoint - 0x2800
    pen = glyph.glyphPen()
    for dot in range(8):
        if pattern & (1 << dot):
            draw_rectangle(pen, *dot_bounds(dot))
    pen = None
    glyph.width = ADVANCE


def fix_font(path: str) -> None:
    font = fontforge.open(path)

    font.em = EM
    font.ascent = ASCENT
    font.descent = DESCENT

    # Disable FontForge's auto metric expansion; otherwise it recalculates
    # these from glyph bounds and ignores the Monaspace-compatible values.
    font.os2_typoascent_add = 0
    font.os2_typodescent_add = 0
    font.os2_winascent_add = 0
    font.os2_windescent_add = 0
    font.hhea_ascent_add = 0
    font.hhea_descent_add = 0

    font.os2_typoascent = 1890
    font.os2_typodescent = -400
    font.os2_winascent = 1890
    font.os2_windescent = 500
    font.hhea_ascent = 1890
    font.hhea_descent = -400

    # Redraw Braille from the Unicode codepoint value instead of transforming
    # whatever nerd-font-patcher produced. That makes the dot mapping explicit
    # and avoids any bad source glyphs/references carrying through.
    for codepoint in range(0x2800, 0x2900):
        redraw_braille_glyph(font, codepoint)

    fixed = path + ".fixed.ttf"
    font.generate(fixed)
    font.close()

    # Reopen once during build to fail early if FontForge generated bad output.
    fontforge.open(fixed).close()


for font_path in sys.argv[1:]:
    fix_font(font_path)
