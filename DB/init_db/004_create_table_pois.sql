-- 004_create_table_pois.sql
-- Purpose: Create the POIs table for the simple_poi_search service

CREATE TABLE public.pois (
    fid BIGSERIAL PRIMARY KEY,
    osm_id character varying,
    amenity character varying,
    name character varying,
    category character varying(20),
    geom geometry(Point, 2154)
);