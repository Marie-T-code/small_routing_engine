CREATE TABLE public.routes_v1 (
    fid SERIAL PRIMARY KEY, --creation de la clef primaire. ATENTION : lors de create_topology se rappeler qu'il ne reconaitra pas fid, utiliser fid AS id
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
    geom geometry(LineString, 2154), --lambert93
    cost double precision,  -- cost, reverse_cost,source, target sont indispensable à create topology. 
    reverse_cost double precision,
    source bigint,
    target bigint
);