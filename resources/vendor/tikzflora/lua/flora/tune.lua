-- Tunable parameters, in one table so they can be adjusted without touching
-- the generators. A file named by the FLORA_TUNE environment variable may
-- return a table of overrides; it is merged over these defaults key by key.
-- Ranges are {min, max} pairs sampled per shape.

local T = {
  gesture = {
    edge = 0.24,            -- outer line of the stems, fraction of margin width
    bows = 3,               -- inward bows up the margin; fewer is gentler
    bow_amp = { 0.20, 0.33 },  -- inward reach of each bow, fraction of margin
    bow_width = { 0.34, 0.42 }, -- half-width of each bow, fraction of its band;
                            -- above 0.5 neighbouring bows merge into a flat offset
    density_floor = 0.24,  -- spray and leaf density in the quiet stretches
    bow_density = 0.6,      -- density at each bow, relative to the hero and the foot (1)
    end_reach = 3,        -- reach of the dense hero and foot clusters (hero radii)
  },
  plant = {
    root = 0.64,            -- where the plant is rooted along the foot, fraction of page width
    lookahead = 82,         -- pt ahead on its guide the main stem steers toward; longer is lazier
    bend_radius = 91,       -- tightest bend of the main stem, pt
    bend_ease = 23,         -- pt over which a bend may build from straight to tightest
    long_shoots = 2,        -- shoots that climb with the main stem, crossing it
    shoot_start = { -0.15, 0.3 }, -- where long shoots leave, share of the rise (below 0: along the foot)
    shoot_end = { 0.6, 1.0 },     -- where they end, share of the rise; spread evenly between
    shoot_reach = { 0.24, 0.36 }, -- how far long shoots swing across the main stem, fraction of margin
    shoot_wave = { 220, 330 },    -- length of one swing of a long shoot, pt
    foot_shoots = 5,        -- shoots fanning up from the foot and corner
    foot_reach = { 34, 70 },      -- length of those shoots, pt
    shoot_bend = 29,        -- tightest bend of a shoot to a bloom or leaf, pt
    root_width = 5.8,       -- main stem width at the root, pt
    tip_width = 3,        -- narrowest the main stem gets, pt
    fork_ratio = 0.8,      -- width of a long shoot relative to its parent
    stem_l = 0.25,          -- OKLCH lightness of the main stem and long shoots
    stem_brush = 1,         -- brushwork along those stems; 0 paints them flat
  },
  hero = {
    style = "wedge",            -- bloom style (tune.blooms): fan, round, soft, obovate or wedge
    petals = 5,             -- petals of the hero bloom
    petal_width = 0.35,     -- petal half-width, fraction of the bloom's radius
    rotation = -1,          -- turn of the first petal, degrees; negative picks one per seed
    lost_edges = 0.56,      -- share of each petal's outline lost
    tilt = 35,              -- how far the bloom leans back, top away, degrees
  },
  -- Bloom styles. Each bloom picks a style by weight and draws its own
  -- count, width and so on from the style's ranges.
  blooms = {
    fan = { weight = 3, petals = { 5, 6 }, width = { 0.32, 0.40 }, ragged = 0.10, spacing = 0.10,
      rim = 0.16, rays = { 28, 44 }, ray_reach = { 0.25, 0.85 }, ray_contrast = { 0.35, 0.70 }, veins = { 10, 18 } },
    round = { weight = 2, petals = { 5, 5 }, width = { 0.52, 0.58 }, ragged = 0.08, spacing = 0.12,
      rim = 0.07, rays = { 0, 0 }, ray_reach = { 0.30, 0.80 }, ray_contrast = { 0.45, 0.80 }, veins = { 22, 22 } },
    soft = { weight = 2, petals = { 5, 5 }, width = { 0.62, 0.72 }, ragged = 0.08, spacing = 0.12,
      rim = 0.07, rays = { 0, 0 }, ray_reach = { 0.30, 0.80 }, ray_contrast = { 0.45, 0.80 }, veins = { 12, 12 } },
    obovate = { weight = 0, petals = { 5, 5 }, width = { 0.30, 0.36 }, ragged = 0.08, spacing = 0.12,
      rim = 0.11, rays = { 0, 0 }, ray_reach = { 0.30, 0.80 }, ray_contrast = { 0.45, 0.80 }, veins = { 22, 22 } },
    wedge = { weight = 3.2, petals = { 5, 5 }, width = { 0.35, 0.44 }, ragged = 0.15, spacing = 0.09,
      rim = 0.12, rays = { 30, 44 }, ray_reach = { 0.25, 0.6 }, ray_contrast = { 0.4, 0.6 }, veins = { 12, 18 },
      gap = 0.08, eye_fade = 0.28, backruns = 0.8 },
  },
  compose = {
    hero = 0.5,            -- hero bloom radius, fraction of margin width
    features = { 1.0, 1.3 },  -- size of the lily, umbels and other large blooms, picked per bloom
    leaves = 100,           -- most large leaves on a page
    leaf_size = 1.25,          -- length of large leaves
    leaf_width = { 0.17, 0.23 }, -- half-width of a large leaf, share of its length, picked per leaf
    leaf_overlap = 0.45,     -- how far leaves may grow across each other, 0-1
    leaf_spacing = { 26, 44 }, -- pt between leaf nodes along a stem, picked per node; wider where quiet
    hole_min = 7,           -- smallest hole, pt radius, that gets a bloom or spray; raised where quiet
    sprays = 150,           -- most fine sprays on a page
    small_blooms = 6,       -- small blooms the sprays may add
    curls = 0.45,            -- how often tendrils and loop flourishes appear
    leaflet_spacing = { 40, 72 }, -- pt between small leaflets along the stems, picked per gap
    leaflet_size = 17.5,    -- length of those leaflets, pt
  },
  -- How much of each kind of growth a page gets (mix.lua): 1 is the usual
  -- amount, 0 none. \florasetup{mix={...}} overrides these per document.
  mix = {
    bloom = 1, soft = 1, lily = 1, ghost = 1, umbel = 1, cyme = 1, gyps = 1,
    leaves = 1, leaflets = 1, sprays = 1, curls = 1, density = 1,
    bee = 0, butterfly = 0, bird = 0, snail = 0,
  },
  -- How often each ornament kind is picked for its slot (ornaments.lua),
  -- as weights among the slot's kinds; 0 never. A kind not listed weighs
  -- 1. \florasetup{ornaments={...}} overrides these per document.
  ornaments = {
    night = 3, sun = 1, moon = 1, constellation = 1, planet = 1, armillary = 1, scrolled = 1, strapwork = 1,
    compass = 3, rosette = 1, sunburst = 1, quatrefoil = 1,
    knot = 3, medallion = 1, zodiac_pendant = 1,
    sun_crest = 2, compass_rose = 2, armillary_crest = 1, zodiac = 1, wreath = 1,
    swash = 1, fleuron_rule = 1, headpiece = 1, copperplate = 2, swelled_rule = 2, fleuronnee = 1, rinceau = 2,
    cul_de_lampe = 1, hedera = 1, garland = 1,
    bracket = 1, fan = 1, corner_leaf = 1, acanthus_corner = 2, cornerpiece = 2, pen_corner = 1,
    gilt_cross = 4, gilt_rosette = 3, gilt_dotted = 3, gilt_lozenge = 1,
    gilt_star = 1.5, gilt_crescent = 1, gilt_trefoil = 1,
  },
  -- How ornament gold is painted: "raster", gold computed per pixel and
  -- placed as images (orn_raster.lua), or "vector", gold in relief built
  -- of flat-coloured strips (orn_relief.lua), which the pgf backend always
  -- uses. \florasetup{gilt=vector}, giltdpi=..., giltenv=... and
  -- giltlook={key=value, ...} override these per document.
  gilt = "raster",
  gilt_dpi = 600,           -- pixels per inch of raster gilt
  gilt_env = "studio",      -- which look of gilt_looks raster gilt takes
  -- The looks of raster gilt (gilt_look.lua lists each key's range): what
  -- its gold reflects, how it is cut, and its finish. Brightness runs 0-1
  -- through the gold ramp, whose stops are {brightness, {r, g, b}}.
  gilt_looks = {
    -- A studio: a soft window to the upper left over dark ground.
    studio = {
      light = 135,            -- degrees, counterclockwise from the right
      eye = 0.7,              -- viewing distance, in image diagonals
      relief = 0.45,          -- slope of a piece's rounded edge
      cushion = 0.15,         -- height of a broad piece's cushion
      facet = 0.4,            -- slope of a ray's faces
      highlight = 0.45,
      highlight_size = 0.1,
      grain = 0.035,
      grain_scale = 1,
      sparkle = 4,            -- flashes per thousand cells
      sparkle_glint = 0.35,
      shadow = 0.42,
      shadow_offset = 1,
      horizon = 0.04,
      horizon_dip = 0.22,
      horizon_soft = 0.035,
      sky = 0.5,
      sky_glow = 0.3,
      sky_lit = 0.25,
      sky_far = 0.15,
      window = 0.2,
      window_top = 0.75,
      window_foot = 0.1,
      ground = 0.26,
      ground_fall = 0.12,
      ground_lit = 0.05,
      gold = {
        { 0.00, { 0.170, 0.090, 0.030 } },
        { 0.22, { 0.380, 0.230, 0.090 } },
        { 0.45, { 0.660, 0.480, 0.220 } },
        { 0.65, { 0.820, 0.650, 0.340 } },
        { 0.82, { 0.950, 0.840, 0.560 } },
        { 1.00, { 1.000, 0.975, 0.860 } },
      },
      copper = {
        { 0.00, { 0.150, 0.060, 0.025 } },
        { 0.25, { 0.360, 0.170, 0.080 } },
        { 0.50, { 0.620, 0.360, 0.190 } },
        { 0.75, { 0.840, 0.600, 0.400 } },
        { 1.00, { 0.990, 0.900, 0.780 } },
      },
      umber = { 0.330, 0.200, 0.090 },
    },
    -- The vector relief's surroundings (orn_relief.lua): sky toward the
    -- light beyond a sharp horizon with a bright band, dark ground, and a
    -- mid gold straight ahead.
    mirror = {
      light = 135,
      eye = 0.7,
      relief = 0.45,
      cushion = 0.15,
      facet = 0.4,
      highlight = 0.45,
      highlight_size = 0.1,
      grain = 0.035,
      grain_scale = 1,
      sparkle = 4,
      sparkle_glint = 0.35,
      shadow = 0.42,
      shadow_offset = 1,
      horizon = 0.02,
      horizon_soft = 0.04,
      sky = 0.8,
      sky_glow = 0.2,
      band = 0.22,
      band_width = 0.05,
      ground = 0.14,
      ground_far = 0.22,
      front = 0.52,
      gold = {
        { 0.00, { 0.240, 0.130, 0.050 } },
        { 0.20, { 0.420, 0.270, 0.100 } },
        { 0.45, { 0.680, 0.500, 0.220 } },
        { 0.62, { 0.840, 0.670, 0.330 } },
        { 0.80, { 0.950, 0.840, 0.520 } },
        { 1.00, { 1.000, 0.970, 0.840 } },
      },
      copper = {
        { 0.00, { 0.216, 0.088, 0.030 } },
        { 0.20, { 0.378, 0.184, 0.060 } },
        { 0.45, { 0.612, 0.340, 0.132 } },
        { 0.62, { 0.756, 0.456, 0.198 } },
        { 0.80, { 0.855, 0.571, 0.312 } },
        { 1.00, { 0.900, 0.660, 0.504 } },
      },
      umber = { 0.330, 0.200, 0.090 },
    },
  },
  -- Size distributions (dist.lua): a smooth curve through control points
  -- {x, weight}, x running 0-1 across the range, so each kind of element
  -- comes in a mix of sizes.
  sizes = {
    gyps = { range = { 0.3, 1.0 }, points = { { 0, 0.35 }, { 0.25, 0.8 }, { 0.5, 1.0 }, { 0.75, 0.75 }, { 1, 0.5 } } },
    leaf = { range = { 0.35, 1.3 }, points = { { 0, 0.4 }, { 0.25, 0.9 }, { 0.5, 1.0 }, { 0.75, 0.6 }, { 1, 0.3 } } },
    leaflet = { range = { 0.5, 2.0 }, points = { { 0, 0.6 }, { 0.25, 1.0 }, { 0.5, 0.7 }, { 0.75, 0.35 }, { 1, 0.15 } } },
  },
  color = {
    hue = 263,              -- OKLCH hue of the deep tones (ultramarine)
    hue_jitter = 6,         -- per-shape hue variation, degrees either way
    hue_drift = -24,        -- base hue relative to tip (negative: cerulean)
    grey_chance = 0.12,     -- chance a leaf is a muted grey-blue
    grey_share = 0.25,      -- chroma kept by a grey-blue leaf
    -- What paints each part: "look" (the gradients below), an ink group
    -- (blue, blue-grey, teal, green, violet, warm, earth, gold) or one ink
    -- by name (lua/flora/inks.lua). Inks keep the look's lightness.
    palette = { hero = "look", blooms = "look", leaves = "blue", leaflets = "blue", stems = "chiku-rin",
      sprays = "look", ghost = "look", cartouche = "look" },
    looks = {
      vivid = { base_l = { 0.80, 0.90 }, tip_l = { 0.2, 0.32 }, chroma = { 0.65, 1.00 }, curve = { 0.4, 1.3 } },
      hero  = { base_l = { 0.74, 1 }, tip_l = { 0.36, 0.48 }, chroma = { 0.81, 1 }, curve = { 0.35, 0.75 } },
      fan   = { base_l = { 0.68, 0.80 }, tip_l = { 0.36, 0.50 }, chroma = { 0.80, 1.00 }, curve = { 0.35, 0.80 } },
      soft  = { base_l = { 0.95, 0.99 }, tip_l = { 0.48, 0.68 }, chroma = { 0.40, 0.85 }, curve = { 0.8, 1.8 } },
      ghost = { base_l = { 0.97, 0.99 }, tip_l = { 0.83, 0.88 }, chroma = { 0.25, 0.3 }, curve = { 1, 1.2 } },
      leaf  = { base_l = { 0.66, 0.8 }, tip_l = { 0.32, 0.65 }, chroma = { 0.65, 1 }, curve = { 0.4, 2.2 } },
    },
  },
  wash = {
    blotches = { 2, 4 },        -- variegated glazes per shape
    blotch_opacity = { 0.10, 0.24 },
    lifts = { 0, 1 },           -- pale back-run blooms per shape
    lift_opacity = { 0.18, 0.32 },
    blotch_hue = 10,        -- hue shift of a glaze from its shape, degrees
    tideline_chance = 0.55, -- pooled pigment along part of the contour
    streak_scale = 0.05,    -- multiplier on each look's crisp white streaks
    brush_bands = { 5, 10 },    -- broken pigment bands per shape
    brush_pale = { 10, 20 },     -- broken pale striations per shape
    brush_width = 1.0,      -- width multiplier for both
    brush_gap = 0.35,       -- how much of each stroke is left unpainted
    brush_dry = 0.3,        -- chance a stroke piece splits into threads
    band_opacity = { 0.38, 0.62 },
    pale_contrast = { 0.12, 0.65 }, -- opacity of pale streaks: barely to clearly lighter
    vein_contrast = { 0.15, 0.55 }, -- opacity of leaf side veins
    lost_edges = 0.42,      -- share of each contour whose edge is lost
    lost_fade = 1.0,        -- how far a lost edge's wash fades into the paper
    grain_clump = 0.55,     -- share of granulation specks gathered into clumps
    grain_mottle = 0.8,     -- strength of the tonal mottling under the specks
    vein_opacity = 0.34,    -- dark vein lines along each petal
  },
}

-- Labels and one-line descriptions for the tuner (tuner/), by
-- dotted path or, for settings repeated in every look, by key. Not a
-- setting itself; overrides never touch it.
T._doc = {
  gesture = { "Stem layout", "The line of action: where the main stems run and how they bow toward the text." },
  ["gesture.edge"] = { "Stem line", "How far in from the outer page edge the stems run, as a share of the margin width." },
  ["gesture.bows"] = { "Bows", "How many times the stems swing inward toward the text on the way up. Fewer is gentler." },
  ["gesture.bow_amp"] = { "Bow reach", "How far each bow swings toward the text, as a share of the margin width." },
  ["gesture.bow_width"] = { "Bow length", "How tall each bow is, as a share of its stretch of margin. Above 0.5 neighbouring bows merge and the stem straightens." },
  ["gesture.density_floor"] = { "Quiet density", "How much foliage and spray survives in the quiet stretches between bows (1 = as dense as the clusters)." },
  ["gesture.bow_density"] = { "Bow density", "How dense the foliage grows at each bow, relative to the crowded top and foot (1 = as dense)." },
  ["gesture.end_reach"] = { "Top and foot reach", "How far the dense growth around the hero and along the foot spreads, in hero radii." },
  plant = { "Plant", "One plant rooted at the bottom right: how the main stem grows and how its shoots branch off." },
  ["plant.root"] = { "Root", "Where the plant is rooted along the foot, as a share of the page width." },
  ["plant.lookahead"] = { "Steering lookahead", "How far ahead along its path the main stem steers. Longer gives lazier, broader curves." },
  ["plant.bend_radius"] = { "Tightest bend", "Smallest radius the main stem may bend to, in pt. Larger is straighter and calmer." },
  ["plant.bend_ease"] = { "Bend easing", "Length in pt over which a bend may build from straight to tightest. Longer bends build more gradually." },
  ["plant.long_shoots"] = { "Long shoots", "Shoots that leave the main stem low and climb with it, crossing it, before curling away." },
  ["plant.shoot_start"] = { "Shoot start", "Where long shoots leave the main stem, as a share of its rise from the corner to the hero. Below 0 is along the foot." },
  ["plant.shoot_end"] = { "Shoot end", "How high long shoots climb before ending, as a share of the rise from the corner to just below the hero. Their ends spread evenly between the two values." },
  ["plant.shoot_reach"] = { "Shoot swing", "How far each long shoot swings across the main stem, as a share of the margin width." },
  ["plant.shoot_wave"] = { "Shoot wave", "Length in pt of one swing of a long shoot. Shorter crosses more often." },
  ["plant.foot_shoots"] = { "Corner shoots", "Shoots that leave the stem along the foot and around the corner and sweep up toward the corner, fanning it out." },
  ["plant.foot_reach"] = { "Corner shoot length", "Length of each corner shoot, in pt." },
  ["plant.shoot_bend"] = { "Shoot bend", "Tightest bend of the shoots carrying blooms and leaves, in pt." },
  ["plant.root_width"] = { "Root width", "Main stem width at the root, in pt. It thins at every fork." },
  ["plant.tip_width"] = { "Tip width", "Narrowest the main stem gets below the hero, in pt." },
  ["plant.stem_l"] = { "Stem tone", "Lightness of the main stem and long shoots (0 black, 1 paper)." },
  ["plant.stem_brush"] = { "Stem brushwork", "Darker bands, pale streaks and broken edges along the main stems. 0 paints them flat." },
  ["plant.fork_ratio"] = { "Shoot width", "Width of a long shoot where it leaves, as a share of the main stem there." },
  hero = { "Hero bloom", "The large flower that crowns the main stem." },
  ["hero.petals"] = { "Petals", "Number of petals on the hero bloom." },
  ["hero.petal_width"] = { "Petal width", "Width of each petal as a share of the bloom's radius. Wider petals overlap." },
  ["hero.rotation"] = { "Rotation", "Turn of the first petal, in degrees. Negative picks a turn per seed." },
  ["hero.lost_edges"] = { "Hero lost edges", "Share of each hero petal's outline left undrawn, melting into the paper." },
  ["hero.tilt"] = { "Tilt", "How far the hero leans back, top away from the viewer and bottom toward, in degrees. 0 faces the page." },
  blooms = { "Bloom styles", "Each bloom picks a style by weight; each style has its own petal shape, colour look and ranges." },
  ["blooms.fan"] = { "Fan", "The reference's flower: broad round-ended petals that overlap, solid blue nearly to the eye, white rays." },
  ["blooms.round"] = { "Round", "Rounded vivid petals that pale toward the eye." },
  ["blooms.soft"] = { "Soft", "Pale, wide, rounded petals." },
  ["blooms.obovate"] = { "Obovate", "Narrower petals widest past the middle; the earlier hero." },
  ["blooms.wedge"] = { "Wedge", "The hero's petals: narrow at the eye, opening into broad rounded fans with wavy ends, each separate from the next." },
  weight = { "Weight", "How often a bloom picks this style relative to the others. 0 never." },
  petals = { "Petals", "Number of petals, picked per bloom." },
  width = { "Petal width", "Petal half-width as a share of the bloom's radius. Wider petals overlap." },
  ragged = { "Ragged", "How much petal lengths differ within one bloom." },
  spacing = { "Uneven spacing", "How unevenly petals are spaced around the eye, in radians." },
  rim = { "Rim wave", "Waviness of the petal's outer edge." },
  rays = { "Rays", "Fine white lines fanning from the eye into each petal." },
  ray_reach = { "Ray reach", "How far rays run, as a share of the way to the rim." },
  ray_contrast = { "Ray contrast", "Opacity of the rays: low sinks them into the wash, high makes them crisp." },
  veins = { "Veins", "Darker vein lines per petal." },
  gap = { "Petal gap", "Least gap between neighbouring petals, as a share of each petal's sector around the eye." },
  eye_fade = { "Fade at the eye", "Keeps the white fade of lost edges near the eye: 1 pales only toward the centre, 0 fades along every lost edge." },
  backruns = { "Back-runs", "Scales the pale back-run patches in this style's petals (0 = none)." },
  ["hero.style"] = { "Style", "The hero's bloom style: fan, round, soft, obovate or wedge." },
  ["color.looks.fan"] = { "Fan blooms", "Gradients for fan-style blooms: solid blue nearly to the eye." },
  compose = { "Composition", "How much grows, and how large: blooms, leaves, sprays and curls." },
  ["compose.hero"] = { "Hero size", "Radius of the large flower at the top, as a share of the margin width." },
  ["compose.features"] = { "Bloom size", "Size of the lily, umbels and other large blooms (1 = default), picked per bloom." },
  ["compose.leaves"] = { "Leaves", "Most large leaves on a page; fewer leaves leave more air." },
  ["compose.leaf_size"] = { "Leaf length", "Length of large leaves (1 = default)." },
  ["compose.leaf_width"] = { "Leaf width", "How broad each large leaf is: its half-width as a share of its length, picked per leaf." },
  ["compose.leaf_overlap"] = { "Leaf overlap", "How far leaves may grow across one another. 0 keeps each blade clear; near 1 they layer densely." },
  ["compose.leaf_spacing"] = { "Leaf spacing", "Distance in pt between the nodes where leaves grow along a stem, picked per node. Quiet stretches space them up to 1.7 times wider." },
  ["compose.hole_min"] = { "Smallest hole", "Radius in pt of the smallest open space that still gets a bloom or spray. Quiet stretches need up to 2.4 times this, so they stay airier." },
  ["compose.sprays"] = { "Sprays", "Most fine sprays (baby's breath, forget-me-nots, buds) on a page." },
  ["compose.small_blooms"] = { "Small blooms", "How many small flowers the sprays may add." },
  ["compose.curls"] = { "Curls", "How often tendrils and loop flourishes sprout from the stems (1 = default)." },
  ["compose.leaflet_size"] = { "Leaflet size", "Length of the small leaflets along the stems, in pt." },
  ["compose.leaflet_spacing"] = { "Leaflet spacing", "Distance between neighbouring leaflets along the stems, in pt, picked per gap. Larger is sparser." },
  gilt = { "Gilt", "How ornament gold is painted: raster (gold computed per pixel, as images) or vector (gold in relief built of flat-coloured strips)." },
  gilt_env = { "Gilt look", "Which of the gilt looks raster gilt takes: studio (a window to the upper left over dark ground) or mirror (the vector relief's sky, horizon and ground)." },
  gilt_looks = { "Gilt looks", "What raster gilt reflects, how its pieces are cut, and its finish. Each look is a full set; giltenv picks one and giltlook={key=value} changes keys of it per document." },
  ["gilt_looks.studio"] = { "Studio", "A soft window to the upper left over dark ground, under a horizon that dips toward the light. The default." },
  ["gilt_looks.mirror"] = { "Mirror", "The vector relief's surroundings: sky toward the light past a sharp horizon with a bright band, dark ground, and a mid gold straight ahead." },
  light = { "Light direction", "Where the light comes from, in degrees counterclockwise from the right (135 is the upper left). Turns the sky, the highlight, the grain and the shadow together." },
  eye = { "Viewing distance", "How far away the gold is seen from, in image diagonals. Nearer sweeps flat gold from bright at the lit corner to dark at the far one; further makes it even." },
  relief = { "Edge slope", "How steeply a piece's rounded edge leaves the page. Higher gives deeper relief: brighter lit edges and darker far rims." },
  cushion = { "Cushion", "How high a broad piece swells across its middle beyond the rounded edge. 0 leaves it flat." },
  facet = { "Facet slope", "How steeply the two faces of a ray rise to their ridge. Higher parts the gold and copper faces further in brightness." },
  highlight = { "Highlight", "Brightness of the sharp highlight where a surface faces the light." },
  highlight_size = { "Highlight size", "How wide a range of surfaces catch the highlight. Larger spreads it into a broad sheen." },
  grain = { "Grain", "Strength of the brushed grain running across the light." },
  grain_scale = { "Grain scale", "Length and spacing of the grain strokes (1 = default). Larger is coarser." },
  sparkle = { "Sparkle", "How many tiny flashes appear, per thousand cells of 0.3 pt. 0 turns them off." },
  sparkle_glint = { "Sparkle brightness", "How bright each flash is." },
  shadow = { "Shadow", "Darkness of the umber shadow the gold casts on the page." },
  shadow_offset = { "Shadow offset", "How far the shadow falls from the gold, away from the light (1 = default, 0 = under it)." },
  horizon = { "Horizon", "How high the horizon sits in what the gold reflects. Higher shows more ground: darker gold." },
  horizon_dip = { "Horizon dip", "How far the horizon drops toward the light and rises away from it: more sky on lit slopes, more ground on far ones." },
  horizon_soft = { "Horizon softness", "Width of the blend between sky and ground. Small is a sharp line between bright and dark facets; large is a soft gradient." },
  sky = { "Sky", "Brightness of the sky the gold reflects." },
  sky_glow = { "Sky glow", "How much brighter the sky gets toward the horizon (studio) or toward the light (mirror)." },
  sky_lit = { "Sky toward the light", "How much brighter the sky is toward the light." },
  sky_far = { "Sky away from the light", "How much darker the sky is away from the light." },
  window = { "Window", "Brightness of the window low in the lit quarter: the broad bright patch on slopes facing the light." },
  window_top = { "Window top", "How high the window reaches (1 = straight up). Higher spreads its light onto flatter surfaces." },
  window_foot = { "Window foot", "Where the window is fully bright, near the horizon. Must stay below the top." },
  ground = { "Ground", "Brightness of the ground the gold reflects: the far-side rims and slopes facing away. Lower is darker." },
  ground_fall = { "Ground fall", "How much brighter the ground gets toward the nadir, for surfaces tilted steeply away." },
  ground_lit = { "Ground toward the light", "How much brighter the ground is on the side toward the light." },
  ground_far = { "Ground far side", "How much brighter the ground gets toward the side away from the light." },
  band = { "Horizon band", "Brightness of the bright band just above the horizon." },
  band_width = { "Band width", "Width of the bright band above the horizon." },
  front = { "Front", "Brightness of what lies straight ahead: surfaces facing the viewer take it." },
  gold = { "Gold ramp", "Colour by brightness of the gold faces: stops {brightness, {r, g, b}}." },
  copper = { "Copper ramp", "Colour by brightness of the shaded (copper) faces: stops {brightness, {r, g, b}}." },
  umber = { "Shadow colour", "Colour {r, g, b} of the shadow the gold casts." },
  gilt_dpi = { "Gilt resolution", "Pixels per inch of raster gilt: 600 for print, lower for quick previews." },
  mix = { "Mix", "How much of each kind of growth a page gets: 1 is the usual amount, 0 none, 2 about twice as much." },
  ornaments = { "Ornaments", "How often each ornament kind is picked for its place on the page, against the other kinds for that place: 0 never." },
  ["mix.bloom"] = { "Small blooms", "Five-petalled blooms in the holes." },
  ["mix.soft"] = { "Soft blooms", "Pale, wide-petalled blooms." },
  ["mix.lily"] = { "Lilies", "Lilies seen from the side." },
  ["mix.ghost"] = { "Ghost blooms", "Faint blooms behind the stems." },
  ["mix.umbel"] = { "Umbels", "Domed clusters of florets on fine rays." },
  ["mix.cyme"] = { "Forget-me-nots", "Curled sprays of small florets." },
  ["mix.gyps"] = { "Baby's breath", "Clouds of tiny florets on hairline stems." },
  ["mix.leaves"] = { "Leaves", "Large leaves along the stems." },
  ["mix.leaflets"] = { "Leaflets", "Small leaflets along the stems." },
  ["mix.sprays"] = { "Sprays", "Fine sprays filling the gaps." },
  ["mix.curls"] = { "Curls", "Tendrils and loop flourishes." },
  ["mix.density"] = { "Density", "How full the border grows overall. Below 1 is airier." },
  ["mix.bee"] = { "Bees", "Bees on dotted flight paths." },
  ["mix.butterfly"] = { "Butterflies", "Butterflies in open spaces." },
  ["mix.bird"] = { "Birds", "A songbird perched on its own twig." },
  ["mix.snail"] = { "Snails", "A snail climbing the main stem." },
  sizes = { "Sizes", "How sizes are mixed for each kind of element, as curves: higher points are sizes that occur more often." },
  ["sizes.gyps"] = { "Baby's breath", "Share of its gap a baby's-breath spray fills: small sprigs to full clouds." },
  ["sizes.leaf"] = { "Leaves", "Length of large leaves, as a multiple of the longest leaf (Leaf length)." },
  ["sizes.leaflet"] = { "Leaflets", "Length of leaflets along the stems, as a multiple of Leaflet size." },
  range = { "Range", "Smallest and largest size the curve covers." },
  weights = { "Weights", "How often each size occurs, at evenly spaced sizes across the range." },
  points = { "Points", "Control points of the curve: {position across the range, weight}. The curve passes smoothly through them." },
  color = { "Colour", "The blue palette every petal and leaf gradient is drawn from." },
  ["color.hue"] = { "Hue", "The blue of the deepest tones, in OKLCH degrees: about 240 is cerulean, 263 ultramarine, 280 violet." },
  ["color.hue_jitter"] = { "Hue variety", "How far each shape's own blue may stray from the hue, in degrees either way." },
  ["color.hue_drift"] = { "Base hue shift", "Hue of the pale base relative to the tip. Negative leans the pale end toward cerulean." },
  ["color.grey_chance"] = { "Grey leaves", "Chance that a leaf is a muted grey-blue rather than a saturated blue." },
  ["color.grey_share"] = { "Grey saturation", "How much colour a grey-blue leaf keeps (1 = as saturated as the rest)." },
  ["color.palette"] = { "Palettes", "What paints each part: its look (the gradients below), a group of fountain pen inks, or one ink. An ink keeps the look's lightness but takes its colour from the ink's measured wash, dense to pale." },
  ["color.palette.hero"] = { "Hero", "Palette for the hero bloom." },
  ["color.palette.blooms"] = { "Blooms", "Palette for the other blooms." },
  ["color.palette.leaves"] = { "Leaves", "Palette for the large leaves; each leaf picks one ink of a group." },
  ["color.palette.leaflets"] = { "Leaflets", "Palette for the small leaflets along the stems." },
  ["color.palette.stems"] = { "Stems", "Palette for the painted main stem and long shoots." },
  ["color.palette.sprays"] = { "Sprays", "Palette for the forget-me-nots, baby's breath and umbel florets, and the sprays' line work." },
  ["color.palette.ghost"] = { "Ghost bloom", "Palette for the pale ghost bloom." },
  ["color.palette.cartouche"] = { "Cartouche", "Palette for the sky inside the star cartouche; its gilt stays gold." },
  ["color.looks"] = { "Looks", "Gradient ranges for each kind of shape: vivid blooms, soft blooms, ghost blooms and leaves." },
  ["color.looks.hero"] = { "Hero bloom", "The hero bloom's own gradients, separate from other vivid blooms." },
  ["color.looks.vivid"] = { "Vivid blooms", "The hero bloom, the lily and most small flowers." },
  ["color.looks.soft"] = { "Soft blooms", "Paler blooms and soft leaves." },
  ["color.looks.ghost"] = { "Ghost blooms", "The faint flower behind the stems." },
  ["color.looks.leaf"] = { "Leaves", "Every leaf except soft ones." },
  base_l = { "Base lightness", "Lightness where the shape joins its stem or the flower's eye (1 = paper white)." },
  tip_l = { "Tip lightness", "Lightness at the tip, the deepest point of the shape. Lower is darker and more inked." },
  chroma = { "Saturation", "Share of the most saturated blue sRGB can show at each lightness." },
  curve = { "Falloff", "How fast colour deepens from base to tip. Below 1 darkens early; above 1 stays pale longer." },
  wash = { "Painting", "Watercolour texture laid over each gradient." },
  ["wash.blotches"] = { "Glazes", "Uneven glazes per shape, in a neighbouring hue, as in wet-on-wet painting." },
  ["wash.blotch_opacity"] = { "Glaze strength", "Opacity of each glaze." },
  ["wash.blotch_hue"] = { "Glaze hue shift", "How far a glaze's hue may differ from its shape's, in degrees." },
  ["wash.lifts"] = { "Back-runs", "Pale patches per shape whose edges dry darker, where water lifted the pigment." },
  ["wash.lift_opacity"] = { "Back-run strength", "How pale a back-run is." },
  ["wash.tideline_chance"] = { "Tidelines", "Chance a shape has pooled pigment drying along part of its edge." },
  ["wash.streak_scale"] = { "Crisp streaks", "Sharp white rays from the flower's eye. 0 removes them; 1 is the old, drawn-on look." },
  ["wash.brush_bands"] = { "Pigment bands", "Broken darker brush marks per shape, running from base to tip." },
  ["wash.brush_pale"] = { "Pale striations", "Broken pale brush marks per shape, running from base to tip." },
  ["wash.brush_width"] = { "Mark width", "Width of the bands and striations (1 = default)." },
  ["wash.brush_gap"] = { "Breaks", "How much of each brush mark is left unpainted. Higher is more broken." },
  ["wash.brush_dry"] = { "Drybrush", "Chance a piece of a mark splits into thin parallel threads, as a dry brush skips the paper." },
  ["wash.band_opacity"] = { "Band strength", "Opacity of the pigment bands." },
  ["wash.pale_contrast"] = { "Striation contrast", "Opacity of the pale marks: low is barely lighter than the wash, high is near white." },
  ["wash.lost_edges"] = { "Lost edges", "Share of each outline left undrawn, mostly at the pale end, where the wash melts into the paper. 0 outlines every shape." },
  ["wash.grain_clump"] = { "Granulation clumps", "Share of the pigment specks that settle in small clumps rather than evenly, as granulating ultramarine does." },
  ["wash.grain_mottle"] = { "Mottling", "Faint darker and paler patches under the specks, a few points across (0 = none)." },
  ["wash.vein_opacity"] = { "Petal veins", "Opacity of the fine dark lines running from a petal's eye toward its rim." },
  ["wash.lost_fade"] = { "Edge fade", "How far a lost edge's wash fades into the paper (1 = default, 0 = the edge just loses its line)." },
  ["wash.vein_contrast"] = { "Vein contrast", "Opacity of leaf side veins: low sinks them into the wash, high makes them crisp." },
}

local function merge(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" and type(dst[k]) == "table" and #v == 0 then
      merge(dst[k], v)
    else
      dst[k] = v
    end
  end
end

local path = os.getenv("FLORA_TUNE")
if path and path ~= "" then
  local chunk = assert(loadfile(path, "t", {}))
  merge(T, chunk())
end

return T
