-- Index spatiaux et attributaires pour routes_v1
CREATE INDEX IF NOT EXISTS routes_v1_geom_idx
  ON public.routes_v1 USING gist(geom);

CREATE INDEX IF NOT EXISTS routes_v1_source_idx
  ON public.routes_v1 (source);

CREATE INDEX IF NOT EXISTS routes_v1_target_idx
  ON public.routes_v1 (target);

-- note : pkey est un index créé automatiquement depuis la création de la table fid as primary key. Les autres indexes de la table vertices seront créé automatiquement par pgr_createTopology