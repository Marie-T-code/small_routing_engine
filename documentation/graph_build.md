# How to build a graph using pgRouting

## necessary table columns

In order for the pgr_CreateTopology() function to work, the adges table must contain : 
- **id** (or fid from Qgis) 
- **source** 
- **target**
- **geom**
- a **topology tolerance** must be defined (or : how precisely nodes are placed on edges). This tolerance is recorded in a variable in this prototype. Recommandation would be : always work in a precise projection and avoid degrees (like in commonly used web CRS (EPSG:4326)) because the less precise your projection is, the most funky your graph will be.


--- 


## how pgr_CreateTopology() works

This function fills the "source" and "target" columns of the edges (lines) table. 
In order to do this it will 
- create a new table for nodes, their id, geometry and topology tolerance
- create indexes for your nodes(pgr_vertices_name_of_your_LineString_table.sql) table (so you don't have to pre-implement them in your init_db, you still have to index your edges (linestring) table as this function only fills the source and target columns in this one)
- then fill every edge's "source" and "target" with the corresponding node IDs

This connects all lines. After that, you can run routing algorithms on the graph you just made. 

> pgr_CreateTopology() can break indepotence : the function does not run to create the vertice table if 'source' and 'target' in the edges table are filed. If you want to use the vertice table, before running pgr_CreateTopology() make sure the source and target columns of the edges table are empty.
