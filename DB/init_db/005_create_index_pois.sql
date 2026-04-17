-- 005_create_index_pois.sql
-- Purpose: Spatial index on pois (required for ST_DWithin)

CREATE INDEX IF NOT EXISTS pois_geom_idx
    ON public.pois USING gist (geom);