# tikz-flora

Watercolour flora grown in the margins of LuaLaTeX documents. Every page
grows its own plant around the text it holds: stems, leaves, blooms, sprays,
gilt, and if you like, bees, butterflies, birds and snails. Everything is
computed in Lua and drawn through PGF, with no images.

Site, live mixer and full guide: **https://flora.alpacasoft.dev**

## Origins

This project would not exist without two others:

- The r/LaTeX thread
  [How do you make these flowers in LaTeX?](https://old.reddit.com/r/LaTeX/comments/1xixznw/how_do_you_make_these_flowers_in_latex/),
  whose photographed page is the reference this renderer is measured
  against.
- Kevin Raymond's [florilegium](https://github.com/kevinraymond/florilegium)
  (MIT), whose grown margins, watch-it-grow animation and visitors this
  package follows.

The ink colours are Pilot iroshizuku ramps measured by
[madoromi](https://madoromi.moonwit.ch/#palettes/colours). The growth follows
Wong, Zongker and Salesin,
[Computer-Generated Floral Ornament](https://grail.cs.washington.edu/projects/ornament/ornament.pdf)
(SIGGRAPH 1998).

tikz-flora was written with Claude Code, Anthropic's coding agent. The art
direction, the tuning against the reference and the choice of what to keep
were done by hand.

## Setup

You need a TeX distribution with **LuaLaTeX** (TeX Live 2023 or later,
MiKTeX, or TinyTeX). Check with `lualatex --version`. The example also uses
`lipsum` (`tlmgr install lipsum` on TinyTeX).

1. Download `tikzflora.zip` from the site, or build it with `just dist`.
2. Unzip it into a folder of its own; its files sit at the zip's root. It
   holds `tikzflora.sty`, `tikzflora-boot.lua`, the generator
   in `lua/flora/`, and `example.tex`.
3. Put your document next to `tikzflora.sty` (or copy the `.sty`, the boot
   file and `lua/` next to your document).
4. Compile with LuaLaTeX: `latexmk example` (the included `latexmkrc`
   selects LuaLaTeX), or `lualatex example` twice.

To install it for every document instead, copy the three items into
`TEXMFHOME/tex/lualatex/tikzflora/` (`kpsewhich -var-value TEXMFHOME` prints
the path).

**Overleaf:** New Project, Upload Project, choose `tikzflora.zip`. The
`latexmkrc` in the zip sets the compiler to LuaLaTeX; otherwise choose it
under Menu, Compiler. The zip holds two documents; if Overleaf opens
`titles.tex`, set Menu, Main document to `example.tex`. To add flora to an
existing project, upload `tikzflora.sty`, `tikzflora-boot.lua` and the
`lua` folder to the project's top level, beside its main document.

A minimal document:

```latex
\documentclass{article}
\usepackage[left=5.5cm,right=2cm]{geometry} % room for the flora
\usepackage{tikzflora}
\florasetup{seed=7}
\begin{document}
Text.
\end{document}
```

## Settings

`\florasetup{...}` sets keys for the rest of the document, from the page it
is on. `\florathispage{...}` sets them for one page only. Mistakes stop the
compile with a message naming the key.

| Key | Values | Effect |
|---|---|---|
| `layout` | `left`, `right`, `centered`, `split`, `title`, `surround`, `flank`, `wreath`, `bouquet`, `scrollwork` | Where the flora grows (below) |
| `seed` | a number, or `random` | Which garden; each page varies it |
| `mix` | `{kind=weight, ...}` | How much of each kind: 1 usual, 0 none, 2 about double |
| `density` | 0 to 10 | Fuller (above 1) or airier (below 1) |
| `visitors` | 0 to 10 | The weight of every visitor at once |
| `palette` | `{part=ink, ...}` | What paints the `hero`, `blooms`, `leaves`, `leaflets`, `stems`, `sprays`, `ghost`, `cartouche` |
| `colourway` | `spring`, `summer`, `autumn` (or `fall`), `winter`, `ember`, `plum`, `rose`, `original` | A whole palette at once; a `palette` after it changes single parts |
| `spin` | a whole number | Picks other inks for parts set to `random`; the shapes stay |
| `ornaments` | `{kind=weight, ...}` | How often each ornament kind is picked for its place; 0 never |
| `gilt` | `raster`, `vector` | Ornament gold computed per pixel as images (the default), or built of flat-coloured strips |
| `giltdpi` | 50 to 1200 | Resolution of raster gilt; 600 by default, lower compiles faster |
| `giltenv` | `studio`, `mirror` | The look of raster gilt: a studio window over dark ground (default), or the vector relief's sky and horizon |
| `giltlook` | `{key=value, ...}` | Changes keys of that look, e.g. `giltlook={horizon=0.1, grain=0}`: light, horizon, sky, ground, highlight, grain, sparkle, shadow and more (`lua/flora/gilt_look.lua` lists every key and its range) |
| `backdrop` | `light` (default), `dark`, or a dark `#rrggbb` | What the flora is painted over. On `dark` every ink is painted light, as if lit, and gold stays gold; set the page to match, e.g. `\pagecolor[HTML]{0A1014}` |
| `cache` | `true` (default), `false` | Keeps each page's flora in a folder `<jobname>-flora/` beside the PDF so a later compile reuses it (see Long documents) |

Mix kinds: `bloom`, `soft`, `lily`, `ghost`, `umbel`, `cyme`
(forget-me-nots), `gyps` (baby's breath), `leaves`, `leaflets`, `sprays`,
`curls`, `density`, `bee`, `butterfly`, `bird`, `snail`. Visitors are off
unless you give them weight. The mix also weighs the shapes drawn:
`feather`, `acanthus` and `lance` for large leaves (small leaves are
always lance leaves), and `fan` and `round` for small blooms, so
`mix={acanthus=3, feather=0}` grows broad lobed leaves. The guide's
"Every option" lists every key and value, read from the package.

Palette values are `look` (the default gradients), an ink group (`blue`,
`blue-grey`, `teal`, `green`, `violet`, `warm`, `earth`, `gold`) or one ink
by name, such as `kon-peki` (all of them are in `lua/flora/inks.lua`).
`random` paints that part in one ink picked per page. The pick has its own
random stream, so changing `spin` changes only the colours: every stem,
leaf and bloom stays where it was.

`sprays` paints the forget-me-nots, baby's breath and umbels, `ghost` the
pale ghost bloom, and `cartouche` the sky in the star cartouche. A non-blue
ink also repaints the rims, grain and contours of the part it paints, so a
page with every part set keeps only a few navy pen lines.

Ornaments fill places on the page: the `cartouche` panel, the `header`
mark on the running-head rule, the `pendant` in the foot's corner, the
larger `gilt` in the foliage's gaps, and on title pages a `crest` where the
crown meets, a `flourish` under the title, a `tailpiece` under the last
line and a piece in each foot `corner`. The `flank` layout's foot piece is
a `crest`, and the `scrollwork` frame takes a `crest` at its head and a
`tailpiece` at its foot. Each place picks one kind by
weight, so `ornaments={moon=3, night=0}` favours the crescent moon
cartouche and drops the night sky; setting every kind of a place to 0
leaves it empty. `just gallery` (or `\floragallery` in a `tikzpicture`)
draws every kind with the name to weigh it by. The kinds:

- cartouche: `night`, `sun`, `moon`, `constellation`, `planet`,
  `armillary`, `scrolled`, `strapwork`
- header: `compass`, `rosette`, `sunburst`, `quatrefoil`
- pendant: `knot`, `medallion`, `zodiac_pendant`
- crest: `sun_crest`, `compass_rose`, `armillary_crest`, `zodiac`, `wreath`
- flourish: `swash`, `fleuron_rule`, `headpiece`
- tailpiece: `cul_de_lampe`, `hedera`, `garland`
- corner: `bracket`, `fan`, `corner_leaf`
- gilt: `gilt_cross`, `gilt_rosette`, `gilt_dotted`, `gilt_lozenge`,
  `gilt_star`, `gilt_crescent`, `gilt_trefoil`

A new kind is a Lua file that calls `register` in
`lua/flora/ornaments.lua` (which explains the fields) and is listed in its
`MODULES`; the gallery and the tests pick it up, and `tests/test_ornaments.lua`
holds it to its box.

```latex
\florasetup{layout=split, visitors=0.5, mix={lily=2, umbel=0},
  palette={hero=murasaki-shikibu, blooms=warm, leaves=teal}}
```

### Layouts

- `left`: the left margin (the default).
- `right`: the right margin.
- `centered`: both side margins, with two different plants.
- `split`: the outer margin of a two-sided document. It is on the right of
  odd pages and the left of even ones.
- `title`: a crown over a title. Wrap the title in
  `\begin{floratitle} ... \end{floratitle}`; without it the first block
  of lines is crowned.
- `surround`: a wreath round the text block, for title pages and contents.

Four more layouts are for title pages, after engraved and hand-coloured
flower books of the nineteenth century. Each frames the lines in
`floratitle` (or the first block of lines without it):

- `flank`: a plant up each side of the page's contents, their roots
  meeting at the foot round a crest.
- `wreath`: an open oval garland round the title, tied at its foot.
- `bouquet`: one upright bouquet tied with a bow, behind the title, with
  each title line on a ribbon.
- `scrollwork`: an oval gilt scroll frame round the title, with a crest at
  its head, scrolls at its foot and the flora twined over it.

The oval of `wreath` and `scrollwork` spans the page's width and keeps to
the room between the title and the nearest lines above and below it.

The flora fills whatever margins the page has, so give it room with
`geometry` (about 5 cm for a side margin, or 3 cm all round for
`surround`).

### Lettering

`\floraletters` draws a line of display capitals as an engraver lettered
them, from the font's own outlines, in the font and size in force:

```latex
{\fontsize{46}{52}\selectfont\floraletters{FLORA'S}\par}
{\fontsize{30}{36}\selectfont\floraletters[style=engraved, arch=24]{DICTIONARY}\par}
```

- `style`: `outline` (the letter drawn round), `shaded` (outlined, with a
  hatched shadow; the default) or `engraved` (the face ruled with fine
  lines over a solid shadow).
- `arch`: the degrees the baseline bends through. Positive arches the
  middle up, negative sags it; 0 (the default) keeps it straight.
- `ink`: an iroshizuku ink by name for the line work, or `black` (the
  default).

It needs an OpenType or TrueType font, as LuaLaTeX's default Latin Modern
and any `fontspec` font are; with another font the text is set as usual,
with a warning in the log. The flora keeps clear of the lettering as it
does of text.

It also grows into gaps in the text. A gap between lines taller than about
three lines (40 pt), such as a `\vspace` left for a figure, opens across
the text's full width and the flora reaches into it. The space below a
short last page fills the same way.

`tex/lorem.tex` (`example.tex` in the zip) uses the first six layouts,
with a comment at every setting; `tex/titles.tex` (`titles.tex` in the
zip) has a title page in each of the other four, lettered with
`\floraletters`.

### Long documents

Growing a page's flora takes a few seconds. Each page's flora is kept in
a folder `<jobname>-flora/` beside the PDF, named by everything it
depends on (the page's layout, the settings and the package's code), so
the next compile reuses every page whose text did not move. The second
and third runs that LaTeX and `latexmk` make cost almost nothing, and
an edit grows again only the pages it reflows. The folder holds about
as much again as the PDF; pages no compile has used for three runs are
deleted, and the folder can be deleted at any time.
`\florasetup{cache=false}` grows every page afresh and keeps nothing.

A `lualatex --draftmode` run writes no PDF, so it grows no flora.
`\floraoff` stops the flora from the page it falls on and `\floraon`
starts it again, so a long document can be drafted with the flora off
(`\floraoff` in the preamble) or with it only on the chapters being
worked on.

The flora is tens of megabytes of PDF drawing per page before
compression, so the package lowers LaTeX's compression level from 9 to
4: the PDF is about 7% larger and compiles in about half the
time. Set `\pdfvariable compresslevel=9` after `\usepackage{tikzflora}`
for the smallest file.

## Working on tikz-flora

The repository uses [just](https://github.com/casey/just). These recipes
add the TinyTeX binaries to `PATH`:

- `just build NAME [SEED]`: compile `tex/NAME.tex` to `build/` with a PNG
  preview. `just build lorem` builds the example; `just build reference`
  builds a page laid out like the reference photo, which the tuner uses.
- `just grow NAME SEED PAGE`: build `build/grow-NAME-PAGE.mp4` and `.gif`
  of a page as it grows. It needs ffmpeg, poppler (`pdftocairo`) and
  ImageMagick.
- `just gallery`: draw every ornament kind, labelled, to
  `build/gallery.pdf` (`tex/gallery.tex`).
- `just dist`: build `build/tikzflora.zip`. `just test-dist` compiles the
  example from the unpacked zip alone.
- `just test`: run the Lua and Python unit tests. `just test-tex` and
  `just test-preview` check against real compiles.
- `just site-bake`, `just site-dev`, `just test-site`, `just site-deploy`:
  build, test and publish the site. `site/README.md` explains them.
- `just tuner`: run a local web app with a slider for every setting in
  `lua/flora/tune.lua`, drawing `tex/reference.tex` beside the de-warped
  reference photo when `tex/reference/rectified.png` is present (it is not
  tracked). It needs Python 3 with numpy and Pillow, and Node.

## Licence

MIT. See `LICENSE`.
