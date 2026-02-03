-- 002_create_tables_routes_v1.sql
-- Purpose: Create the edges table used for pgRouting

CREATE TABLE public.routes_v1 (
    fid SERIAL PRIMARY KEY, -- Edge unique id (note: pgRouting algorithms expect an "id" column in the edges SQL, so use "fid AS id")
    osm_id character varying,
    bicycle character varying,
    cycleway character varying,
    highway character varying,
    lit character varying,
    maxspeed character varying,
    name character varying,
    oneway character varying,
    surface character varying,
    comp integer,
    length_m double precision,
    geom geometry(LineString, 2154), -- Lambert-93 (metric SRID)

    -- Routing costs (required by pgr_dijkstra / pgr_bdDijkstra)
    -- source/target are filled by pgr_createTopology
    cost double precision,
    reverse_cost double precision,
    source bigint,
    target bigint
);
