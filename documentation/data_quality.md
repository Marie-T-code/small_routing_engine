
# data necessary and following quality

## data pre-processing

Most of the data preprocessing was done in QGIS. The missing but necessary preprocessing steps I should have done in QGIS can be found in /SQL/04_graph/01_pre_processing 

1. import 

Import GeoJSON file from OSM Turbo of the road network polyline (Nevers + 15 km). This step is difficult on old hardware. In the future, testing QuickOSM plugin or download.geofabrik.de will be considered.

2. Work in QGIS : 

- reprojection in EPSG:2154
- PolyLineString exploded in LineStrings
- individual lines snapped with a 1 meter tolerance
- connectivity analysis using GRASS (v.net.components)
- join comp (cat vs fid) on the enriched snap layer
- identification of the main component (76k edges)
- exporting this single component to a layer
- attribute table cleaning : 
  - keeping only osm_id, highway, name, oneway, bicycle, cycleway, surface, lit, maxspeed, comp,
  - removal of all other column
  - adding longueur_m = length($geometry)
- export roads_main (comp=1) as a working basis for the prototype

## used dataset

download the used dataset here : (mettre le lien)

## routing engine limits 

This routing engine is designed to work on a SINGLE connected component. The cost and reverse_cost columns lets the user choose their edges weight. In order to make it simpler for users, the 01_pre_processing/03_costs_config.sql is the dedicated file to costs tweaking. In this case only the length_m (length in meters of an edge) data was chosen. This guarantees a prototype that can answer this question : ** How fast can run the PGR routing algorithms on a ully populated cost column ?**. 
After data consideration, and working on the hypothesis that data quality affects pgRouting algorithm performance, my conclusion is that : 
 - ** for a good routing engine, data quality (cost and reverse_cost columns in particular) and component merging should be done during the data cleaning preprocess.**

I am considering working on a way to automate data cleaning and components unifications for the bike users engine case in the future. 

As for costs, I intend to study the limits of pure OSM data use, and recommend that users think about local data availability first. Some very useful columns in the OSM original GEOjson file were kept to experiment on 10% or less filled columns and evaluate their impact on the routing engine.


## Graph quality status
- Single connected component kept intentionally
- `pgr_analyzeGraph`:
  - isolated segments: 0
  - invalid nodes: 0
  - potential gaps: 5
- The 5 residual suspicious points are known OSM leftovers and do not break routing
- Graph considered valid for prototype and function testing

## others

the files "biblio" (bibliography) and "interviews_use_case_for_users_to_do are remnants of the first project this routing engine was born from. The bibliography contains a scientific article about the different use cases of bikes in French cities. The interviews contains an semi-structured interview grid I was planning to conduct with bike users in Nevers. 
This would have helped to understand in a more granular way how to construct the costs file, and would have helped make a routing engine tailored for Nevers bike users. 
** Basically : if the data isn't there, there are always ways to create it ** 