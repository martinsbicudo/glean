# Glean brand kit

![Glean lockup](png/glean-lockup.png)

**The mark:** a fanned hand of three cards with the front card pulled up out of the hand. To *glean* is
to gather bit by bit: the words and phrases you pick up in meetings become cards you study, one at a time.

The palette is a graphite tile with a single purple accent, rounded-pill drawing and a clean sans wordmark.

Everything here is generated from [`generate.py`](generate.py). To change the mark or the colours, edit
that file and run `make icons` (or `./scripts/make-icons.sh`). That rebuilds the SVGs,
`Resources/AppIcon.icns`, the menu bar icons and the PNGs in `png/`.

## Colours

| Role | Name | HEX | RGB | Use |
|---|---|---|---|---|
| Primary dark | Graphite | `#16181D` | 22 24 29 | App icon tile, text, mark on light backgrounds |
| Accent on dark | Iris | `#9A7CFF` | 154 124 255 | The brand colour on graphite: app icon, reversed lockup, UI accent in dark mode |
| Accent on light | Plum | `#6B3FD4` | 107 63 212 | The brand colour on paper: mark, buttons, links |
| Light | Paper | `#F4EFE6` | 244 239 230 | Backgrounds, text on graphite |
| Support | Slate | `#5B6170` | 91 97 112 | Secondary text, captions |

The brand colour is one purple, always solid: Iris on dark backgrounds, Plum on light ones. No gradients.

Contrast: iris on graphite 5.7:1, paper on graphite 15.5:1, plum on paper 5.6:1, slate on paper 5.4:1.
Don't put Iris on paper (2.7:1); use Plum or Graphite there.

## Files

| File | Use |
|---|---|
| `svg/glean-symbol.svg` | Graphite mark, for light backgrounds |
| `svg/glean-symbol-plum.svg` | Plum mark, the coloured version for light backgrounds |
| `svg/glean-symbol-iris.svg` | Iris mark, for dark backgrounds |
| `svg/glean-symbol-black.svg` / `-white.svg` | One-colour versions |
| `svg/glean-app-icon.svg` | macOS app icon master (1024 grid) |
| `svg/glean-app-icon-small.svg` | Larger mark with wider gaps for the 16 and 32 px icon slots |
| `svg/menubar.svg` | Menu bar template (drawn black; macOS shows it white on the menu bar). When cards are due, the count appears next to it |
| `svg/glean-lockup*.svg` | Symbol + wordmark (graphite, plum, reversed) |
| `png/` | Rendered app icon and lockups for READMEs and slides |

## Construction

- 256-unit grid. Cards are 108 × 148 with 24-unit corners.
- The front card is lifted 18 units out of the hand. The side cards are the same card rotated ±15° around
  a pivot below the hand (128, 236). Only the part past a 12-unit gap from the front card is drawn.
- The text lines are 18-unit pills (52 and 28 long) cut out of the front card (even-odd fill), so the
  mark works in any single colour. One path, no masks.
- App icon: graphite rounded square (824 on a 1024 canvas, 185 corner radius) with the Iris mark.
  The small version uses a 16-unit gap and thicker lines.
- Menu bar: the same mark with a 20-unit gap and no text lines, fitted into 22 × 18.

## Usage

- **Clear space:** keep empty space at least as wide as the gap between two cards × 2 (24 units on the
  256 grid) around the mark.
- **Minimum size:** symbol 16 px; lockup 96 px wide.
- **Wordmark:** "glean", lowercase, in Inter or SF Pro Display Semibold, tracking −2.5%. The lockup SVGs
  use live text. Outline it in a vector editor before sending it to print.
- **Don't** rotate the mark, change the fan angle, recolour the text lines separately on the
  single-colour versions, add gradients or shadows, or colour the menu bar icon.
