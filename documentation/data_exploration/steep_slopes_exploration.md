# EDGES x SLOPES EXPLORATION NOTES

## INTRODUCTION

Raster was implemented in the pipeline. [SQL/04_graph/01_pre_processing/02a_slope_pct.sql](../../SQL/04_graph/01_pre_processing/02a_slope_pct.sql) implemented z_start and z_end then calculated each edge's slope. The summary : `summary : null cells, steep edges, min, max and absolute average slopes (with and without flat data)` revealed what seemed to be aberrant slopes. 
Considering that the raster data was imported in INT16 on 5m raster cells, I supposed that these very steep slopes could be the result of steps from one pixel reading to the other. 
Therefore, I decided to investigate these slopes in order to avoid the most aberrant and inaccurate slopes in my cost configuration. 



## METHODOLOGY : 

the goal was to : 

1. identify steep slopes by edge size
2. identify the share of steep edges percentage by length against all steep edges 
3. recalculate, from the slope, the elevation difference between the end and start point of an edge. 

query used : 

```SQL
-- (query 3) Δz = |slope_pct| × length_m ÷ 100 request

SELECT
ROUND((abs(slope_pct) * length_m/100)::numeric, 2) as dz_m,
COUNT(*) AS number_edges
FROM public.routes_v1
WHERE  length_m < 5
AND ABS(slope_pct) > 15
GROUP BY dz_m
ORDER BY dz_m;
```

4. identify the highway tag associated to steep edges
5. The choice was made to conduct a non exhaustive exploration based on edge location. This was motivated by a time constraint I wanted to keep for V1. 

from these inputs I planned on find a way to eliminate aberrant slopes by crossing : length of edges, slope percentage, and type of highway tag. 
I looked them up in a non exhaustive way, but inspected cases (combinations of edge length, slope and highway types, both "car drivable" and "cyclist drivable") were low enough for a Qgis inspection (less than a hundred cases). 

example of query I used : 
```SQL
SELECT fid, geom, length_m, slope_pct, highway
FROM public.routes_v1
WHERE  length_m > 20
AND ABS(slope_pct) >15
AND ABS(slope_pct) <20
AND highway IN ('primary', 'secondary', 'tertiary', 'cycleway','path', 'unclassified');
```

These queries were created as layers in Qgis in order to identofy thresholds above which slope should not be taken into account. All "abandonned" queries represent queries that were not investigated either because I couldn't find a clear pattern/cause for these slopes or because the slope I had identified as threshold (example : 15%) was below another query type

| Length | Slope | p/s/t | p/s/t + unclassified + cycleway + path | cycleway + pedestrian + path |
|---|---|---|---|---|
| < 5 m | 15–20% | X | | X |
| < 5 m | 20–28% | X || |
| < 5 m | > 28% | X | ||
| 5–10 m | 15–20% | | X | |
| 5–10 m | 20–28% | | | |
| 5–10 m | > 28% | | X | |
| 10–20 m | 15–20% | | X | |
| 10–20 m | 20–28% | | X | |
| 10–20 m | > 28% | | X ||
| > 20 m | 15–20% | | X | |
| > 20 m | > 20% | | X | |

p/s/t = `primary`, `secondary`, `tertiary`.

Non explored queries : if queries returned an edge count too big, data that after exploration couldn't lead to a meaningful conclusion, or establish a threshold above which slope wouldn't be reliable, then the exploration stopped. 

Example :

| Length | Slope | p/s/t | p/s/t + unclassified + cycleway + path | cycleway + pedestrian + path |
|---|---|---|---|---|
| < 5 m | 15–20% | X | | X |
| < 5 m | 20–28% | X || |
| < 5 m | > 28% | X | ||

Consider slopes between 15% on very small edges. Above 28% slope results encouraged me to look for a smaller slope percentage. At 15-20% I realized I could have to separate slope percentage cost between p/s/t and others more cyclism oriented highway tags. This, coupled with the knowledge from former queries revealing the more moderate the slope on 0-5 meters edges, the more the edges count grew, inbvestigation stopped at the 15-20% slope for less than 5 meters edges on drivable and cyclable highway tags. 


Query exploitation : 

In Each query, I would find potentially aberrant slopes and take a screenshot. 
Screenshots showing relationshipe between constructions (bridges and tunnels) show only one red line : the problematic edge. 

[pont de la Loire (Loire Bridge) example](../img/Qgis_exploration/2_edges_Bridge_PdLoire.png)

For those which didn't show necessarily a clear cause for the aberrant slopes, each screenshot would contain:

- in green the qery resulted lines
- in red the routes_v1 graph
- a straight Qgis ruler tool illustration of the path travelled in meters

[Eurovelo 6 road : Loire à vélo kilometer 0](../img/Qgis_exploration/Loire_a_velo_km_0.png)

11 examples were thusly identified. 

For each example I would then compare
- the lonely segment and its weird slope
- the stretch or road or path it was taken from

evaluating the whole slope of a segment of 3 or more edges against the individual edge's slope and confronting it to where on the map this segment was allowed me to draw general rules : general thresholds above which slope shouldn't be taken into account in costs. Tradeoffs are listed in [results](#results)

## RESULTS & EXPLANATIONS

### steep slopes (> 15%) by edges size as the consequence of the raster input in INT16 : 

|length_m_grades|	total_edges	|steep_edges	|steep_rate_in_class_pct	|share_of_steep_pct
|---|---|---|---|---|
|1: 0-5 m	| 10118	|580 |	5.7	|44.6|
|2: 5-10 m	| 14087	|321 |	2.3	|24.7|
|3: 10-20 m	| 19730	|197 |	1	|15.1|
|4: 20-40 m	| 19915	|154 |	0.8 |	11.8|
|5: 40+ m   | 23017 |49	 |  0.2 |	3.8|

The table above shows that the smaller the edge the biggest the edges with steep slopes count. 

Keeping the data constraints (raster in int16) the second step was reproducing the elevation difference between z_start and z_end from the slope calculated in the dedicated script : 
- H1 can we identify integers plateaus ? 
- If not:  H2(see the "rue Claude Tilier" case) could slope calculation in bilinear interpolation explain the amount of steep slopes in small edges ?

Query 3 returned 116 distinct Δz values, all non-integer (0.19 to 3.84 m, 580 edges): elevations are not read as raw integer pixels. The integer steps still exist in the raster, but bilinear reads blend them (see H2). The shape of the distribution was not explored further. 92% of the 580 queried edges (535) returned Δz ≤ 1 m. 

H2 illustration appeared during the examination of small edges and steep slopes query (edges under 5 meters, slope above 15%, pedstrian): 


#### Rue Claude Tillier (`way/168522947`, pedestrian): slope amplified

[**Geographical location**](../../documentation/img/Qgis_exploration/pedestrian_small_edge.png)
 : old city center street in Nevers

| fid | length_m | z_start → z_end | Δz (m) | slope_pct |
|---|---|---|---|---|
| 19803 | 4.14 | 184 → 184 | 0.00 | 0.0 |
| 19804 | 1.53 | 184 → 184 | 0.00 | 0.0 |
| 19805 | 2.45 | 184 → 184.13 | +0.13 | 5.3 |
| **19806** | **3.20** | **184.13 → 184.66** | **+0.53** | **16.5** |
| 19807 | 19.61 | 184.66 → 186 | +1.34 | 6.8 |
| 19808 | 7.10 | 186 → 186 | 0.00 | 0.0 |
| **Total** | **38.03** | **184 → 186** | **+2.00** | **5.3** |

Integer plateaux (184, 186) with a ramp in between: the metre-rounding steps are visible directly.
The short edge 19806 reads about three times the slope of the way. 


Explanation : if a small edge reads z_start on one pixel (example 182m) and z_end on another pixel (ex 183m) then even with bilinear calculation the slope calculated from these number will be abnormally steep. Instead of talking of plateaus of slopes values not representing reality, I considered the existence of "ramps" disturbing the real slopes readings. 

### Qgis observations

See [methodology](#methodology-) for SQL query type.

#### no matter the edge length, engineering structures break slope

A recuring pattern was observed : 
Slopes tend to be very steep just before and just after an engineering structure: bridge above water, levees, canal lock, bridge and tunnel above/below train tracks.

**explanation** : the raster MNT gives altitude for the ground level at a location.
Ground level is NOT edge level in a road based routing graph. 

Example : [the Pont de la Loire bridge](../img/Qgis_exploration/2_edges_Bridge_PdLoire.png), interestingly cyclaways AND roads, of any length, had extreme slopes on both entries of this bridge. 

#### small edges steep slope show too many potential causes

1. As seen above, the slope can be highly exagerated even with bilinear calculation

2. slope can be quite accurate as shown 

 fid 19756 [here](../img/Qgis_exploration/cycleway_small_edge.png), way/166868881 (cycleway), 4,10 m and 17,6 % slope. Slightly exagerated but really there according to my multi-edges slope calculations (not included)

 3. slope can be completely invented
fid 21289 [here](../img/Qgis_exploration/sentier_du_ver_vert.png), on way/184509022 (path) : 4,95 m and 17,8 % slope. 
From fid fid 21286 to 21290 the real slope was about 0.1% according to my multi-edges slope calculations (not included)

4. roundabouts contain steep slopes

As seen [here](../img/Qgis_exploration/roundabouts.png) roundabouts are prone to contain steep slopes, I suppose this is mostly due to the high number of small edges contained in a roundabout. 

#### 5 to 10 meters edges: steep slopes mainly caused by engineering structures misreading

Most cases found show engineering structure influences on slope inaccuracy. 
As shown [here](../img/Qgis_exploration/Loire_a_velo_km_0.png) I inspected the "Kilometer 0" of the Loire à vélo cyclaway. As a renowned European cyclepath an edge of 15,3% seems highly improbable. 

Edge under study: fid 24593, 7.25 m, read slope −15.3% (Δz 1.11 m).

| fid | length_m | z_start → z_end | slope_pct |
|---|---|---|---|
| 24591 | 37.56 | 174 → 172.26 | −4.6 |
| 24592 | 7.58 | 172.26 → 171.80 | −6.1 |
| **24593** | **7.25** | **171.80 → 170.69** | **−15.3** |
| 24594 | 24.49 | 170.69 → 170 | −2.8 |
| **Total** | **76.88** | **174 → 170** | **−5.2** |

A real 4 m descent from the car park to the path. Edge 24593 reads about three times the average slope of the way.
With Δz = 1.11 m, amplification cannot be separated from a locally steeper stretch of bank. Whether the car park sits on a levee was not verified.

Other edges 5 to 20m long with steep slopes were following this pattern : near an engineering structure. 

#### 10 to 20 meters edges: engineering structures influence still strong on roads but less present on paths

For 10 to 20 meters edges I had to differenciate the roads (primary, secondary, tertiary) and the paths. 
15% slope roads query returned only one tertiary road with a steep slope (maybe exagerated) for 6 engineering structures proximity. 

15% slope paths query returned 23 paths amongst which 4 were in proximity to engineering structures. 

Above 20% all found edges were near engineering structures.

#### above 20 meters edges: engineering structures only on roads above 20%

Between 15 and 20%, examined edges all returned what seemed to be real relief. Above 20%, the 6 p/s/t edges were all near engineering structures. 
0 edge of this length had a slope above 28% in the filtered highway types. 
Paths returning 20-28% slopes seemed to be on real relief, granted with an exagerated slope. 


### Findings summary : 

### Findings: edge length × slope × highway type

Legend: p/s/t = `primary` / `secondary` / `tertiary`; "(observed)" = visual inspection in QGIS, no exact count; "—" = not explored.

| Length | 15–20% | 20–28% | > 28% |
|---|---|---|---|
| **< 5 m** | **457 edges.** p/s/t: junctions and roundabouts (observed). `cycleway` / `pedestrian` / `path`: 15 edges, 0 bridges, 1 roundabout; case studies Rue Claude Tillier (amplified), cycleway switchback (real), Sentier du Ver-Vert (invented) | **79 edges.** p/s/t: a few bridges, mostly roundabout arcs (observed) | **44 edges:** 15 `footway`, 12 `steps`, 4 `unclassified`, 3 `primary`, …; p/s/t: 6/6 engineering structures |
| **5–10 m** | **232 edges.** `path`: Loire à Vélo, fid 24593 (amplified) | **57 edges.** — | **32 edges:** 8 `footway`, 5 `steps`, 5 `track`, 5 `unclassified`, …; roads + `cycleway` + `path` (12 edges): engineering structures only (observed) |
| **10–20 m** | Roads: **7** (3 `primary`, 3 `tertiary`, 1 `secondary`): 6 structures + **1 real climb** (fid 38383). `path`: 23, at least 4 bridges | Roads: **9** (4 `secondary`, 3 `primary`, 2 `tertiary`): engineering structures | Roads: **8** (5 `unclassified`, 2 `tertiary`, 1 `secondary`): engineering structures |
| **> 20 m** | Roads + `cycleway` + `path`: 0 structures; Rue Sainte-Hélène (real) | **16 filtered edges:** 6 p/s/t (6/6 structures); 10 `path` / `cycleway` / `unclassified` (real relief) | **0 edges** in the filtered types |

Engineering structures = bridges, footbridges, lock gates, road/rail crossings: the DEM reads the ground or water below the structure.


## Finding slope thresholds

Constraints:
- no new data loading. 
- No complex slope calculation


I needed thresholds, therefore, from my exploration results I came up with the following rules (and written down costs of these rules)


When the slope is ignored, the edge falls back to its length-based cost.

| Edge length | Roads (p/s/t) | Cyclable paths |
|---|---|---|
| Under 5 m | ignored | ignored |
| 5–10 m | kept up to 15% | all slopes kept |
| 10–20 m | kept up to 15% | all slopes kept |
| Above 20 m | kept up to 20% | all slopes kept |

p/s/t = `primary` / `secondary` / `tertiary`.

Other highway tags (`track`, `unclassified`, `service`, …) keep their slope on edges of 5 m and more.
Under 5 m, the slope is ignored for all highway types.


### Exceptions and trade-offs

| Grid cell | Case | Effect |
|---|---|---|
| Under 5 m, all types | 10,118 edges | all slopes ignored, real ones included (Rue Claude Tillier: 0.66 m of the 2 m climb lost) |
| Under 5 m, all types | fid 19756 (cycleway switchback, 4.10 m, 17.6%) | real slope lost |
| Roads, 10–20 m | fid 38383 (`tertiary`, way 290652400, 10.96 m, 16.0%) | real slope lost: 1.75 m |
| Roads, 5–10 m | fid 38379 (same road, 6.36 m, 20.8%) | real slope lost: 1.33 m; together 3.1 m of a 14.3 m climb (~20%) |
| Other tags (`unclassified`) | fid 3842 (Rue Sainte-Hélène, `unclassified`, 33.6 m, 18.2%) | real slope kept (would be lost under a length-independent road rule) |
| Other tags (`unclassified`), 10–20 m | 5 edges above 28% at engineering structures | false slopes kept |
| Cyclable paths | paths at structures (≥ 4/23 at 10–20 m; Écluse Ronde des Lorrains) | false slopes kept |

### Known limits

- Below 15%, rounding artefacts persist but cannot be detected from the slope value (e.g. 0% edges on a rising street, Rue Claude Tillier).
- Near bridges and tunnels, kept slopes can be wrong (the DEM reads the ground or water below the structure).
- Types without a dedicated rule (`footway`, `track`, `service`, …) keep their slope on edges ≥ 5 m.
- Not explored: 5–10 m at 20–28%; 32 of the 48 edges > 20 m above 20% (types outside the filter).
- Roads 5–10 m kept up to 15%: between 15 and 28% this is an extension, not an inspected result.
- Boundary values (e.g. exactly 15.0%) are assumed negligible in double precision.

## CONCLUSION : V2 will better check its data

I see two major problems in V1 that I spotted after this exploration and one of them has nothing to do with slopes. 

1. I focused on having for V1 a small raster file. I underestimated the cost changing a Float32 in an Int16 for one. 
Also : 5 meters pixels are okay for a V1 but less so for a V2. 
Basically data quality AND understanding it in details is what I lacked for V1. 

2. HOwever, as for engineering structures, slopes poses a neat problem : OSM has a dedicated tag for them. Bridges, tunnels and so on can be ignored in calculating slope based costs. 
This implies however never having elevation that isn't interpolated from a segment of edges encapsulating engineering structures. 
Another solution would be to investigate other elevation models like LIDAR or MNE to extract elevation from them. 

All of this is very much in the "over-engineering pitfalls I'll try not to fall into" trap. 

3. UNRELATED TO SLOPE
- Some slope were very accurate. On steps. I ralized with this investigation that my graph composed of a unique component included highway tags unsuitable for cycling (`motorway`, `steps`, `raceway`, `proposed`). 
V1 is therefore less a "bycicle routing engine" than a prototype on "how to build" a bicycle routing engine. 

- knowledge of OSM tags is biting me back : roundabouts are not handled as oneway in this routing engine, their edges can be travelled in both directions. Because when I downloaded the OSM multilinestring source material I treated it as raw material. It isn't. I didn't understand the following logic : oneway roads will have indication (oneway section), helping thusly creating bi directional costs. 
Roundabout have their own tag (`junction=roundabout`), which implies oneway. The "oneway" section of the roundabout I checked was therefore empty. 






