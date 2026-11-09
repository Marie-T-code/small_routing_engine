
From file : /SQL/YY_data_exploration/steep_slope_small_edges.sql

# Steep slope exploration on the graph (work done in QGis)



## where are the most steep slopes, by edge size ? (query 1)


|length_m_grades|	total_edges	|steep_edges	|steep_rate_in_class_pct	|share_of_steep_pct
|---|---|---|---|---|
|1: 0-5 m	| 10118	|580 |	5.7	|44.6|
|2: 5-10 m	| 14087	|321 |	2.3	|24.7|
|3: 10-20 m	| 19730	|197 |	1	|15.1|
|4: 20-40 m	| 19915	|154 |	0.8 |	11.8|
|5: 40+ m   | 23017 |49	 |  0.2 |	3.8|

Small edges are the more prone to have steep edges. So the work focused on them. 

## so small edges are the most at risk of being aberrant, so what slope for these small edges ? (query 4)

|slopes_grades	|number_edges
|---|---|
|1: 15-20 %	|457
|2: 20-28 %	|79
|3: 28+ %	|44

Theory :
H1 — direct reading of integer pixels would give integer Δz: refuted (query 3, Δz continuous). 
H2 — bilinear interpolation between metre-rounded pixels creates ramps that short edges read as 15–28% slopes: consistent with query 4 (92% of steep small edges ≤ 28%), mechanism not verified on project data.

For V1 I took the biggest single component of connected roads from OSM multilinestring data. I didn't take into account the very few cases out of 86,867 edges where the "highway" tag was filled by values unsuitable for cycling. Clearly non-cyclable values (motorway, motorway_link, raceway, proposed, steps) account for 2,274 edges (2.6%), few in number, but enough to produce wrong routes, and slopes unsuited for cyclists. I did consider it a "future V2" problem.

For highway tags per edges : see query 7. 

## looking up 28+% slopes small edge cases where the "highway" tag is filled (query 5)

|highway	|small_edge_cases
|---|---|
|footway	|15
living_street	|1
|motorway	|1
|path	|2
|primary	|3
|secondary	|1
|service	|2
|steps	|12
|tertiary	|2
|tertiary_link	|1
|unclassified	|4

## Last check : 28%+ slope on drivable roads : why ?

I did look up "primary" "secondary" and "tertiary" 6 cases where the slope is aberrant for a drivable road. 


3 of them are located near a [railway bridge](../img/Qgis_exploration/3_edges_railway_bridge.png)
2 of them are located on one bank of the ["Pont de Loire" bridge](../img/Qgis_exploration/2_edges_Bridge_PdLoire.png) and one on one bank of the ["Pont de Crezancy" bridge](../img/Qgis_exploration/1_edge_bridge_PdCrezancy.png)


## Leads 

1. I need to get back to SQL first then Qgis, and using GRASS, check how much the current single component would be broken if the tags in "highway" that are unsuitable for cycling are filtered and where. For V1 I plan on documenting the findings, and from there either
 - adjust costs and snapping by filtering unsuitable highway tags 
 - or document the limits of the dataset and work on it in a later version


2. steep slopes : 
- using urban planning rules (max slope on roads and therefore cyclist paths on roads) I plan on filtering the highway tags primary, secondary, and tertiary : any road showing in this dataset slopes above 7% (current work hypothesis, needs research) should not be accounted for and may not be accurate. This would eliminate bridges problems, at the cost of rendering parts of the route costs non slope-based. A fallback to default costs and reverse-cost seems therefore needed. 
- any path (highway="path") showing high slope could accept up to 16% slope (current work hypothesis), above this threshold, considering the relatively flat land I am working on, I don't trust the data completely. 

3. small edges steep slopes : 
From this exploration, small edges seem the most at risk of inaccurate (aberrant) slopes. After considering the idea of  limiting the influence on costs of small length edges, I want to try if limiting a fixed accepted percentage would solve this problem. From the finding, eliminating 7% slopes (work hypothesis) would eliminate all 580 cases. This seems a simple solution, and its cost (number of edges that lose their elevation) need to be investigated. From future findings I could then consider limiting the slope's impact on cost for smaller edges

4. I need however to check medium and long edges, and check if I find the same problems in the 15% + slopes. 