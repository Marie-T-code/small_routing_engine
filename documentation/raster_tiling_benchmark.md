# Raster tiling — tile-size benchmark

This document records **why the DEM is imported with `-t 64x64`** in
`import_dem.sh`. It captures a one-shot benchmark, the reasoning behind
the choice, and — more usefully for the future — a dimensioning principle
for tiling *any* raster, not just this one.

**A note on how to read this document.** It deliberately separates three
kinds of statement, because they carry different weight:

- **Measured** — figures this benchmark actually produced. Asserted
  plainly.
- **Theory** — the mechanism (PostgreSQL pages, TOAST) that *explains*
  the figures. Attributed to a source, and never claimed as something
  this benchmark observed. It could not have: TOAST is invisible to
  `EXPLAIN` (see section 2), so its role here is *inferred from
  consistency with the literature*, not seen.
- **Inference** — the tile-size choice itself, which follows from the
  measured figures converging with the theory. It is the author's
  conclusion for this raster, not a recommendation lifted from a source.

The benchmark script lives at
[`raster_tile_size_benchmark.sh`](./raster_tile_size_benchmark.sh). It is
a one-shot exploratory tool, not part of the pipeline: it runs once,
produces a decision, and is archived. The raw capture is in
`raster_tile_size_benchmark_raw.txt`.

---

## 1. What was measured

The DEM (`dem_nevers.tif` — IGN RGE ALTI, Int16, 5 m pixel, EPSG:2154,
~4.5 MB, ~7300 × 7000 px) was imported four times into a throwaway table,
once per candidate tile size. Each pass measured three things:

- **import time** — `raster2pgsql | psql`, including GiST index build
  and `VACUUM ANALYZE` (`-M`)
- **on-disk footprint** — row count (one row per tile) and total table
  size
- **point-lookup time** — one `ST_Value` at the start point of every
  edge in `routes_v1` (86,867 edges), which mimics the real access
  pattern of the future slope computation: thousands of scattered,
  point-wise reads.

| Tile    | Ground cover     | Import  | Tiles  | Footprint | Point-lookup |
|---------|------------------|---------|--------|-----------|--------------|
| 32×32   | 160 m × 160 m    | 10.5 s  | 38,121 | 14 MB     | 2446 ms      |
| 64×64   | 320 m × 320 m    | 5.1 s   | 9,639  | 9.5 MB    | **2018 ms**  |
| 100×100 | 500 m × 500 m    | 4.3 s   | 3,994  | 9.0 MB    | 2409 ms      |
| 256×256 | 1280 m × 1280 m  | 2.6 s   | 642    | 8.1 MB    | 5096 ms      |

These are single-run figures on a small raster, so they carry different
confidence levels (section 3).

**The one measured fact that drives everything:** import time *falls* as
tiles grow, but the 256×256 point-lookup *rises* sharply — more than
double the others. Import and lookup pull in opposite directions. For
this project, lookup is what the slope computation will actually do, so
lookup is the axis that decides.

---

## 2. The mechanism that explains it (theory, attributed)

The measured behaviour is consistent with a well-documented PostgreSQL
storage mechanism. This section attributes that mechanism to its source;
it is **not** something this benchmark observed directly.

PostgreSQL stores data in fixed **8 KB pages**, and a value too large for
a page is moved to a side-table by a subsystem called **TOAST** (The
Oversized-Attribute Storage Technique). Crunchy Data's PostGIS raster
tutorial applies this directly to Int16 DEM tiles — the same data type
and loader as ours: at 32×32, a 2-byte Int16 tile takes 2048 bytes, small
enough to fit in the database page size, so the data is not pushed to a
TOAST side-table. The same source describes the general raster access
pattern our lookup relies on: first find the relevant tiles via the
spatial index, then read values from those tiles — using the functional
GiST index on `st_convexhull(rast)`.

Applied to our four tile sizes, in Int16 (2 bytes/pixel):

| Tile    | Tile data size | vs 8 KB page          |
|---------|----------------|-----------------------|
| 32×32   | 2 KB           | fits comfortably      |
| 64×64   | 8 KB           | ≈ one page            |
| 100×100 | ~20 KB         | over → TOAST likely   |
| 256×256 | ~128 KB        | far over → TOASTed    |

The theory predicts that a point-wise read — which must load and
deserialise the *whole tile* containing the pixel, just to read one
value — is cheap when the tile fits a page and expensive when the tile is
TOASTed. That prediction matches the measured 256×256 slowdown.

**Why this stays "theory" and never becomes "observed".** Crunchy Data's
dedicated TOAST article is explicit that the mechanism is invisible at
query-inspection time: it happens transparently, and `EXPLAIN` plans do
not show whether a value was TOASTed. So no amount of `EXPLAIN` on the
256×256 table could have *shown* us TOAST at work. The honest claim is
therefore: the measured slowdown is **consistent with** the page/TOAST
mechanism, not proof of it. We matched an observation to a documented
cause; we did not witness the cause.

---

## 3. Confidence — what's robust, what's noise

Honesty about a single-run benchmark on a small, cache-friendly raster:

- **Robust:** the monotonic *fall* in import time as tiles grow (fewer
  rows to insert); the monotonic *fall* in footprint as tiles grow (less
  per-row overhead); the sharp *rise* in 256×256's lookup. These are
  structural effects, visible regardless of cache state.
- **Noise:** the differences *among* 32 / 64 / 100 on point-lookup
  (2018 vs 2409 vs 2446 ms, ~20% spread). On a raster this small,
  everything lands in cache almost immediately, so these gaps sit within
  run-to-run variance and should not be over-read.

This matters for how the choice is justified: not "64×64 beat 100×100 by
400 ms" (fragile, within noise), but "64×64 sits at the page boundary and
ties-or-wins on every axis, while 256×256 clearly decouples" (robust, and
consistent with the documented mechanism).

---

## 4. The decision — `64x64` (inference)

This is the author's conclusion, drawn from the measured figures meeting
the attributed theory. It is not a value recommended by any source — the
sources explain the *mechanism*; the *choice* is ours, for this raster.

**`64x64` wins the point-lookup, is near-minimal on footprint, imports
quickly, and sits exactly at the page boundary.** A 64×64 Int16 tile is
64 × 64 × 2 = 8192 bytes ≈ one 8 KB page — the largest tile that still
fits a page, per the mechanism in section 2. It therefore captures the
lookup advantage of page-fitting tiles without the extra rows (and larger
import/footprint) of going smaller to 32×32. The measured lookup (fastest
of the four) and the theory (fits a page, avoids TOAST) point to the same
tile — which is the strongest position to choose from: measurement and
mechanism agree.

256×256 is the instructive counter-case: fastest to import (fewest rows),
but slowest to look up, consistent with each single-pixel read pulling a
~128 KB tile through the TOAST path. Since the pipeline's real work is
point-wise lookup, import speed is the wrong axis to optimise for here.

**On "finer" tiling — a precision worth keeping.** 64×64 is also
geographically finer (320 m tiles vs 1.28 km for 256×256). But a finer
tile grain does **not** improve altitude precision — that is fixed by the
5 m pixel, regardless of tiling. What it buys is a read granularity better
matched to point-wise access: a smaller candidate tile per index probe
means less data loaded per pixel read. The geographic angle (smaller
tiles) and the storage angle (fits a page) happen to converge on the same
choice, but they are different things and shouldn't be conflated.

---

## 5. Dimensioning principle — for any raster, not just this one

The sample here was deliberately tiny. The reusable takeaway is not the
number `64`; it is **how to reason about tile size for a raster at a
different scale.**

Three independent variables govern the tile count:

1. **ground extent** (how much territory)
2. **pixel resolution** (how fine — 5 m here, but could be 1 m or 30 m)
3. **tile size** (the `-t` value)

They combine as:

```
tiles ≈ ( extent / resolution / tile_side )²
```

The load-bearing insight: **it is not the extent in kilometres that caps
fine tiling — it is the total pixel count**, which is extent *and*
resolution together. A 30 km raster at 5 m and a 30 km raster at 1 m have
the same extent but a 25× difference in pixels, so the same tile size
yields 25× more tiles (= rows) for the second.

This turns "match the tiling to the working scale" into something
precise:

- what **limits** fine tiling is the **row budget** (pixels ÷ tile =
  rows): too many rows bloats the index, the import, and the raster
  catalogue.
- what **pushes toward** fine tiling is the **access pattern**:
  point-wise reads favour small tiles that fit a page; zonal/area reads
  favour larger tiles that cover a feature in one row.
- **extent alone says nothing.** Compute pixels (extent ÷ resolution),
  then rows (pixels ÷ tile), then let the access pattern set the
  direction.

A counter-intuitive corollary: "small territory" does not automatically
mean "can tile finely". A 1 km site at 10 cm resolution (a drone survey)
has more pixels — and thus a tighter row budget — than a 30 km area at
5 m. The unit that matters is never the kilometre; it is the pixel.

**Practical consequence:** the `64x64` chosen here is correct for *this*
raster at *this* scale with *this* access pattern. A raster at a
materially different scale warrants re-measuring rather than reusing
`64x64` by habit — the right `-t` is a function of all three variables,
not a constant.

---

## 6. Sources

- **Postgres Raster Query Basics**, Crunchy Data —
  https://www.crunchydata.com/blog/postgres-raster-query-basics
  The Int16-tile / page-size / TOAST relationship on the exact case
  (DEM, `raster2pgsql`, `st_convexhull` GiST index), and the two-step
  raster access pattern (find tiles via index, then read).
- **Postgres TOAST: The Greatest Thing Since Sliced Bread?**, Crunchy
  Data —
  https://www.crunchydata.com/blog/postgres-toast-the-greatest-thing-since-sliced-bread
  The general page/TOAST mechanism, and the key methodological point that
  TOAST is invisible to `EXPLAIN` — which is why this document treats it
  as inferred theory, not observed fact.

---

## 7. Cross-references

- [`raster_tile_size_benchmark.sh`](./raster_tile_size_benchmark.sh) —
  the one-shot benchmark script
- `raster_tile_size_benchmark_raw.txt` — raw captured output
- `import_dem.sh` — the production import that uses `-t 64x64`
  (forthcoming)
