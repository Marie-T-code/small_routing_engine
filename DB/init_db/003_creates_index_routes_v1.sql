-- 03_creates_indexes
-- creates indexes for routes_v1 (only table requiring indexes for now)

-- Spatial and attribute indexes for routes_v1
-- Spatial index on edge geometries (required for spatial queries and snapping)
CREATE INDEX IF NOT EXISTS routes_v1_geom_idx
  ON public.routes_v1 USING gist (geom);

-- Index on source vertex id (used by pgRouting algorithms)
CREATE INDEX IF NOT EXISTS routes_v1_source_idx
  ON public.routes_v1 (source);

-- Index on target vertex id (used by pgRouting algorithms)
CREATE INDEX IF NOT EXISTS routes_v1_target_idx
  ON public.routes_v1 (target);

-- Note:
-- The primary key (fid) automatically creates a B-tree index.
-- Indexes on the vertices table (routes_v1_vertices_pgr) are automatically
-- created by pgr_createTopology.
