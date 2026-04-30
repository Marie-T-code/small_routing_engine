# Data quality

This document explains the **data quality choices** that shape the
project — what trade-offs were made, why, what the current limits are,
and where they could go next.

For the operational pipeline (which tools, in what order), see
[`pipeline.md`](./pipeline.md). For the resulting database structures,
see [`data_model.md`](./data_model.md).

---

## 1. Thesis

**A good routing engine cannot be built on raw OSM data alone.** Two
data-quality conditions matter most, and both must be addressed during
the preprocessing stage rather than at runtime:

1. **Cost and reverse_cost columns must be fully populated** with
   meaningful weights. A graph with sparse or arbitrary costs produces
   routes that are technically valid but practically irrelevant.
2. **The graph's connectivity must be intentional.** Whether the
   strategy is "single connected component only" (the prototype's
   choice, see section 2) or "multiple components reconciled through
   data fusion" (the long-term direction, see section 7), the choice
   must be deliberate and the data must support it.

The current prototype satisfies condition 1 with a simple choice
(`cost = reverse_cost = length_m`, distance minimisation) and
satisfies condition 2 by selecting only the largest connected
component of the OSM-derived graph. Both choices are starting points,
not endpoints — their evolution is tracked throughout the project's
roadmap.

---

## 2. Single connected component — a deliberate constraint

The routing engine operates on the **largest connected component** of
the cleaned road network — currently around 76,000 edges for the
Nevers area. Smaller, disconnected components (parks, private paths,
disconnected cycleways) are dropped during the QGIS preparation stage.

**Why this constraint exists — isolating variables.** Routing engines
that handle multiple components (OSRM does this, for example) have
strategies to fall back when no path exists between two points: pick
the largest component, route within it, ignore the rest. These
strategies are valuable, but they introduce a **second source of
complexity** on top of the routing algorithm itself.

The prototype takes the opposite approach: **make the data a
controlled variable**, so that any failure or anomaly observed at
runtime can be attributed to the algorithm and the code, not to the
data's topology. If the algorithm misbehaves on a single, fully
connected graph, the bug is in the algorithm. If a route is wrong,
the cost function is the suspect. Eliminating data-topology variance
is a research habit — the same principle that asks experimental
controls to vary one thing at a time.

**What it costs.** Edges that are valid bicycle routes in real life
but appear as isolated components in OSM (a park path that doesn't
quite touch the road network, a private alley used as a shortcut, a
disconnected cycleway segment along a canal) are dropped. The user
cannot route through them.

**What would lift the constraint.** Not naive component merging by
geometric proximity, but **principled component reintegration based
on data fusion** — see section 7.

---

## 3. Cost columns — what's used today, what isn't, what could be

### 3.1 Current cost model

The current cost configuration is the simplest possible:

```sql
cost         = length_m
reverse_cost = length_m
```

This means Dijkstra-family algorithms minimise distance, and the graph
is symmetric (an edge has the same weight in both directions). This
choice was made for two reasons:

- **It guarantees full population.** Every edge has a `length_m`
  computed from its geometry, so every edge has a valid cost. No
  null, no sentinel, no fallback logic.
- **It matches the prototype's question.** The prototype is
  designed to answer "how fast can pgRouting algorithms run on a
  fully-populated cost column?" — not "what is the optimal route for
  a cyclist?". Realistic cost weighting comes later.

### 3.2 What's kept but not used yet

The OSM tags imported alongside each edge (`bicycle`, `cycleway`,
`highway`, `lit`, `maxspeed`, `name`, `oneway`, `surface`) are
**preserved in the database but not currently consumed by the cost
function**. They are kept because they will eventually feed
multi-criteria cost weighting:

- `surface` distinguishes asphalt from gravel — relevant for road
  bikes
- `lit` indicates lighting presence — relevant for evening / night
  routing
- `cycleway` distinguishes dedicated cycle facilities from shared roads
- `highway` differentiates a residential street from a primary road —
  relevant for safety-aware cyclists

### 3.3 The completeness challenge

**OSM tags are unevenly populated.** Some columns (`highway`, `name`)
are nearly always present. Others (`surface`, `lit`, `maxspeed`) are
filled in for only a fraction of edges — sometimes 10% or less in a
given territory. This raises a methodological question that is **not
yet answered** in the project:

> Is a sparsely-populated tag usable as a cost input at all? If only
> 10% of edges declare their surface, does pondering by surface
> meaningfully improve routing, or does it just add noise?

The honest answer requires measurement on the actual graph — a
defaults-vs-confidence-weighting comparison that the prototype is
not yet equipped to run. This investigation is sequenced **after**
the planned component-reintegration work, because reintegration will
likely change the completeness picture (newly-included paths and
parks may have different tag-population rates than the main road
network).

---

## 4. Two datasets, two quality philosophies

The routes and POIs datasets follow **opposite trade-offs** on
incomplete data, and this is intentional.

**Routes — permissive schema, defer judgement.** The routes table
keeps all OSM-sourced columns even when they are sparsely populated.
The reasoning: even a 10%-filled column may turn out to carry
useful signal once the graph is enriched, and dropping the column
upstream forecloses that future. The cost of keeping it is a few
mostly-NULL columns in the table, which is cheap.

**POIs — strict filtering, demand completeness.** The POIs table
drops every point that lacks an `amenity` tag. The reasoning: a
POI without an amenity tag carries no semantic content for the user
("there's a thing here, we don't know what kind") and would clutter
the API response with unusable features. Better to refuse the point
than to keep it as dead weight.

**Why the asymmetry.** The two datasets serve different functions.
A routing graph is a **substrate** — completeness of structure
matters, completeness of attributes is opportunistic. A POI
collection is a **catalogue** — every entry must carry meaning
because the user reads it directly.

This kind of context-dependent quality decision is part of what
makes data preprocessing a domain skill, not a pure technical task.

---

## 5. Lessons from the field

### 5.1 Overpass Turbo reaches its limits early

The routes pipeline initially used **Overpass Turbo** to extract OSM
data for Nevers + 15 km. This worked, but the extraction was already
straining a 5-year-old laptop, and the resulting GeoJSON file
struggled to load into QGIS.

The lesson is not that Overpass Turbo is bad — it's an excellent
exploration tool — but that **for any extraction beyond a few
kilometers radius, a more efficient toolchain is needed**.

### 5.2 Visualise before filtering

The POIs pipeline learned from the routes experience and used
`osmium-tool` instead of Overpass Turbo. But it also adopted a
different methodological approach: **import everything first, filter
visually in QGIS, then re-export**.

The reasoning is that an `osmium tags-filter` applied at extraction
time assumes that the filter is correct — and the only way to verify
that is to look at the data afterwards. By importing all layers
into a temporary PostGIS database and exploring them in QGIS, the
filtering decisions are made on **observed** data rather than
**assumed** data. Edge cases (unexpected tag values, layers worth
knowing about) surface naturally.

This is a small habit but it changes the failure mode: from "I
filtered out useful data without knowing" to "I saw the data and
chose what to keep".

---

## 6. Graph quality status

The current graph passes the standard pgRouting validation:

| Metric              | Result                                  |
|---------------------|-----------------------------------------|
| Connected components| 1 (largest component kept intentionally)|
| Isolated segments   | 0                                       |
| Invalid nodes       | 0                                       |
| Potential gaps      | 5                                       |

The 5 residual suspicious points are known OSM artefacts (typically
near administrative boundary edges) and do not break routing. The
graph is considered valid for the prototype's purpose: function
testing and performance characterisation.

For more on the validation framework itself (what
`pgr_analyzeGraph` checks, where the project's guardrails fit in),
see [`architecture.md`](./architecture.md) section 5 and section 6.

---

## 7. Where to go from here

### 7.1 Component reintegration through data fusion

Once the algorithm and cost function are validated on the
single-component graph, the next step is to bring back the dropped
components — but not by naive geometric proximity. Real-world
reintegration requires **business rules informed by additional data
sources**:

- **Cadastral data** to identify property limits and public/private
  status
- **Building footprints** to distinguish open spaces from built
  structures
- **Public-access status** for ambiguous spaces (a customer parking
  lot is functionally public; a private alley is not)
- **OSM's secondary linestring layer** (cycleways along canals,
  off-road cycle paths) that the current pipeline does not yet
  exploit

The goal is to derive reintegration rules — either explicitly scripted
or learned from a model — that decide which components to merge,
through which bridging edges, with which cost weights. This is data
fusion across multiple sources, not topology repair from a single
source.

This is exploratory work and remains in the project's Later phase.

### 7.2 Multi-criteria cost weighting

After reintegration, the actual contribution of each OSM tag to route
quality can be evaluated empirically — measure first, then weight.

### 7.3 External data integration

Where OSM is incomplete, the answer is not always "live with it".
See section 8 for a complementary perspective.

---

## 8. On building data, not just consuming it

A perspective worth naming explicitly, because it sometimes gets
overlooked.

The most common mental model when working with data is **consumption**:
you query an API, you parse a file, you ingest a dataset. Finding it,
filtering it, displaying it. This works well — until the data simply
doesn't exist for the question you're trying to answer.

When that happens, two reactions are common: scope the feature down
("we'll do it when we have the data"), or substitute proxies ("the
closest tag we can find"). Both can be reasonable, but they're not
the only options.

There's a third option that gets less attention: **producing the
missing data**. A municipality can run user-testing sessions with
cyclists. A cycling association can structure ground-truth route
reporting. A research lab can lead a participatory mapping campaign.
Data does not have to come from a centralised authority — it can be
co-produced with the people who will use the resulting tool.

This project's roots reflect that orientation. The repository
includes (or once included) preliminary work that is not used in the
current code:

- A **bibliography** drawn from academic literature on cycling use
  cases in French cities. Among other things, this literature
  documents that cyclists fall into **multiple distinct profiles**
  (commuter, leisure, sport, child-companion, etc.), each with
  different cost preferences. This is direct input for future
  multi-profile routing — a single "best route for a cyclist"
  doesn't actually exist; what exists is a best route per profile.
- A **semi-structured interview grid** designed for cyclists in
  Nevers — a tool for collecting the kind of nuanced cost
  information no OSM tag captures (perceived safety, detour
  tolerance, comfort preferences).

These materials predate the current technical prototype and were
never integrated into it. They are kept here because they document
a stance: **if the data isn't there, there are always ways to create
it.** It takes more time, but it is not impossible — and it is
sometimes the only path to a tool that genuinely serves its users.

---

## 9. Cross-references

- [`pipeline.md`](./pipeline.md) — how data flows from OSM to the
  database, step by step
- [`data_model.md`](./data_model.md) — table schemas, column types,
  storage details
- [`architecture.md`](./architecture.md) — SQL build pipeline,
  guardrails, runtime function chain
- [`graph_build.md`](./graph_build.md) — how `pgr_createTopology()`
  builds the routable graph